class GuidedScriptsController < ApplicationController
  TEMPLATE = "intentspring_script_v1".freeze

  before_action :set_intention

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" button is a GET to the current path; send it back to the intention.
  def index
    redirect_to intention_path(@intention)
  end

  def show
    @guided_script = @intention.guided_scripts.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @intention.ai_variables)

    @guided_script = @intention.guided_scripts.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_script!(raw)
    @guided_script.update!(result.merge(status: "completed"))
    redirect_to intention_guided_script_path(@intention, @guided_script)

  rescue ParseError => e
    @guided_script.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to intention_guided_script_path(@intention, @guided_script)

  # The sentence matched a crisis term (config/ai_guards.yml). AiGatekeeper raised before any call to Gemini,
  # so nothing was sent; show crisis resources instead. Must come before GatekeeperError, its parent class.
  rescue GeminiService::CrisisError
    render "shared/ai_error_page", locals: { error_type: :crisis }, status: :unprocessable_entity

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_intention
    @intention = current_user.intentions.find(params[:intention_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the intentspring_script_v1 JSON and returns the GuidedScript attributes.
  # Hard rules enforced here, not trusted to the model: the script's spoken length is within 25% of 130 words a
  # minute, and it never uses therapy, healing, diagnosis or progress language, or a music cue (BannedPhraseCheck).
  def parse_script!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    title = parsed["title"]
    fail_parse.("title is missing") unless title.is_a?(String) && title.strip.present?
    fail_parse.("title is longer than 80 characters") if title.strip.length > 80

    minutes = parsed["length_minutes"]
    unless minutes.is_a?(Integer) && minutes == @intention.length_minutes
      fail_parse.("length_minutes was #{minutes.inspect}, expected #{@intention.length_minutes}")
    end

    segments = parsed["segments"]
    fail_parse.("Expected 3-40 segments") unless segments.is_a?(Array) && segments.size.between?(3, 40)
    unless segments.all? { |s| valid_segment?(s) }
      fail_parse.("Every segment needs text and a whole-number pause_seconds from 0 to 60")
    end
    segments = segments.map { |s| { "text" => s["text"].strip, "pause_seconds" => s["pause_seconds"] } }

    making = parsed["making_prompt"]
    fail_parse.("making_prompt must be an object") unless making.is_a?(Hash)
    unless GuidedScript::FORMS.include?(making["form"])
      fail_parse.("making_prompt.form must be one of #{GuidedScript::FORMS.join(', ')}")
    end
    constraint = making["constraint"]
    invitation = making["invitation"]
    fail_parse.("making_prompt.constraint must be 1-200 characters") unless text_within?(constraint, 200)
    fail_parse.("making_prompt.invitation must be 1-400 characters") unless text_within?(invitation, 400)
    making = { "form" => making["form"], "constraint" => constraint.strip, "invitation" => invitation.strip }

    word_count = GuidedScript.count_words(segments.map { |s| s["text"] })
    range      = GuidedScript.word_range(minutes)
    unless range.cover?(word_count)
      fail_parse.("The script was #{word_count} words; a #{Intention.length_label(minutes)} script needs " \
                  "#{range.min}-#{range.max} (about #{GuidedScript::WORDS_PER_MINUTE} a minute)")
    end

    output_text = [ title, *segments.map { |s| s["text"] }, constraint, invitation ].join("\n")
    banned = BannedPhraseCheck.found_in(output_text, @intention.sentence)
    if banned.any?
      fail_parse.("The script used language this app never shows (#{banned.join(', ')}), so it was not shown")
    end

    {
      title:          title.strip,
      length_minutes: minutes,
      segments:       segments,
      making_prompt:  making,
      word_count:     word_count
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  def valid_segment?(segment)
    segment.is_a?(Hash) &&
      segment["text"].is_a?(String) && segment["text"].strip.present? &&
      segment["pause_seconds"].is_a?(Integer) && segment["pause_seconds"].between?(0, 60)
  end

  def text_within?(value, max)
    value.is_a?(String) && value.strip.present? && value.strip.length <= max
  end
end
