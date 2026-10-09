require "rails_helper"

RSpec.describe "GuidedScripts", type: :request do
  let(:user)      { create(:user) }
  let(:other)     { create(:user) }
  # One minute: the script must be 98-162 spoken words.
  let(:intention) { create(:intention, user: user, length_minutes: 1, tone: "quiet") }

  # A passage of exactly `words` words, none of them banned.
  def passage(words)
    base = %w[Sit however you are sitting and let your hands rest on the table while the morning stays quiet around you]
    Array.new(words) { |i| base[i % base.size] }.join(" ") + "."
  end

  # A valid one-minute result: four passages of 30 words (120 in all).
  def script_result(words_per_segment: 30, segments: 4, minutes: 1)
    {
      "title"          => "The long way, by the river",
      "length_minutes" => minutes,
      "segments"       => Array.new(segments) { |i| { "text" => passage(words_per_segment), "pause_seconds" => i == segments - 1 ? 0 : 8 } },
      "making_prompt"  => {
        "form"       => "photograph",
        "constraint" => "One photograph of the water, taken without stopping.",
        "invitation" => "On the way home, take one picture of the river as you pass it."
      }
    }
  end

  let(:valid_result) { script_result }

  def write_script
    post intention_guided_scripts_path(intention)
  end

  describe "POST /intentions/:intention_id/scripts" do
    context "when not signed in" do
      it "redirects to sign in" do
        write_script
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
      end

      it "calls GeminiService with the template and only the sentence, length and tone" do
        expect(GeminiService).to receive(:generate).with(
          template:  "intentspring_script_v1",
          variables: { sentence: intention.sentence, length_minutes: "1", tone: "quiet" }
        ).and_return(valid_result.to_json)
        write_script
      end

      it "creates a completed script with the parsed fields, the word count and the raw response" do
        expect { write_script }.to change(GuidedScript, :count).by(1)
        script = GuidedScript.last
        expect(script.status).to eq("completed")
        expect(script.gemini_raw).to eq(valid_result.to_json)
        expect(script.title).to eq("The long way, by the river")
        expect(script.length_minutes).to eq(1)
        expect(script.segments.size).to eq(4)
        expect(script.segments.first.keys).to eq(%w[text pause_seconds])
        expect(script.making_prompt["form"]).to eq("photograph")
        expect(script.word_count).to eq(120)
        expect(script.generated_at).to be_present
      end

      it "redirects to the result page" do
        write_script
        expect(response).to redirect_to(intention_guided_script_path(intention, GuidedScript.last))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{valid_result.to_json}\n```")
        write_script
        expect(GuidedScript.last.status).to eq("completed")
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      {
        "is not JSON"                       => ->(_) { "this is not json at all" },
        "is a JSON array"                   => ->(_) { "[1, 2]" },
        "has no title"                      => ->(r) { r.merge("title" => " ").to_json },
        "has a title over 80 characters"    => ->(r) { r.merge("title" => "a" * 81).to_json },
        "has the wrong length_minutes"      => ->(r) { r.merge("length_minutes" => 3).to_json },
        "has length_minutes as a string"    => ->(r) { r.merge("length_minutes" => "1").to_json },
        "has two segments"                  => ->(_) { script_result(segments: 2, words_per_segment: 60).to_json },
        "has 41 segments"                   => ->(_) { script_result(segments: 41, words_per_segment: 3).to_json },
        "has a segment without text"        => ->(r) { r.merge("segments" => r["segments"] + [ { "pause_seconds" => 4 } ]).to_json },
        "has a 90-second pause"             => ->(r) { r.merge("segments" => r["segments"].map { |s| s.merge("pause_seconds" => 90) }).to_json },
        "has a pause written as a string"   => ->(r) { r.merge("segments" => r["segments"].map { |s| s.merge("pause_seconds" => "8") }).to_json },
        "has no making_prompt"              => ->(r) { r.except("making_prompt").to_json },
        "suggests a form outside the list"  => ->(r) { r.merge("making_prompt" => r["making_prompt"].merge("form" => "sculpture")).to_json },
        "has no invitation"                 => ->(r) { r.merge("making_prompt" => r["making_prompt"].except("invitation")).to_json },
        "has an invitation over 400 chars"  => ->(r) { r.merge("making_prompt" => r["making_prompt"].merge("invitation" => "a" * 401)).to_json }
      }.each do |description, build|
        it "marks the script failed and keeps the raw text when the response #{description}" do
          text = instance_exec(valid_result, &build)
          gemini_returns(text)

          expect { write_script }.to change(GuidedScript, :count).by(1)
          script = GuidedScript.last
          expect(script.status).to eq("failed")
          expect(script.gemini_raw).to eq(text)
          expect(script.failure_reason).to be_present
          expect(response).to redirect_to(intention_guided_script_path(intention, script))
        end
      end
    end

    # Hard rule 1, enforced in code: 130 spoken words a minute, plus or minus 25% (98-162 for one minute).
    context "word count" do
      before { sign_in_as(user) }

      it "fails a script that is too short and says why" do
        gemini_returns(script_result(words_per_segment: 10).to_json)
        write_script
        script = GuidedScript.last
        expect(script.status).to eq("failed")
        expect(script.failure_reason).to eq("The script was 40 words; a 1 minute script needs 98-162 (about 130 a minute)")

        follow_redirect!
        expect(response.body).to include("could not be used", "The script was 40 words", "Retry")
        expect(response.body).not_to include("Download .md")
      end

      it "fails a script that is too long" do
        gemini_returns(script_result(words_per_segment: 41).to_json)
        write_script
        expect(GuidedScript.last.failure_reason).to start_with("The script was 164 words")
      end

      it "accepts both ends of the range" do
        shortest = valid_result.merge("segments" => [ 40, 40, 18 ].map { |n| { "text" => passage(n), "pause_seconds" => 5 } })
        gemini_returns(shortest.to_json)
        write_script
        expect(GuidedScript.order(:created_at).last).to have_attributes(status: "completed", word_count: 98)

        gemini_returns(script_result(segments: 3, words_per_segment: 54).to_json)
        write_script
        expect(GuidedScript.order(:created_at).last).to have_attributes(status: "completed", word_count: 162)
      end

      it "measures against the intention's own length" do
        intention.update!(length_minutes: 3)
        gemini_returns(script_result(minutes: 3, segments: 10, words_per_segment: 39).to_json)
        write_script
        expect(GuidedScript.last).to have_attributes(status: "completed", word_count: 390)
      end
    end

    # Hard rule 2, enforced in code: no therapy, healing, diagnosis or progress language, and no music cues.
    context "banned phrases (BannedPhraseCheck)" do
      before { sign_in_as(user) }

      def with_last_segment(text)
        result = valid_result
        result["segments"][-1] = { "text" => "#{passage(30 - text.split.size)} #{text}", "pause_seconds" => 0 }
        result
      end

      it "fails a script that frames itself as healing and says why" do
        gemini_returns(with_last_segment("This will help you heal.").to_json)
        write_script
        script = GuidedScript.last
        expect(script.status).to eq("failed")
        expect(script.failure_reason).to include("never shows (healing)")

        follow_redirect!
        expect(response.body).to include("never shows (healing)", "help you heal")
        expect(response.body).not_to include("Download .md")
      end

      it "fails a script that assesses progress" do
        gemini_returns(with_last_segment("You have made such progress.").to_json)
        write_script
        expect(GuidedScript.last.failure_reason).to include("progress")
      end

      it "fails a script with a music cue" do
        gemini_returns(with_last_segment("[soft piano music begins]").to_json)
        write_script
        expect(GuidedScript.last.failure_reason).to include("music cue")
      end

      it "fails a making prompt that frames the art as therapy" do
        result = valid_result
        result["making_prompt"]["invitation"] = "Draw the river as a little art therapy for yourself."
        gemini_returns(result.to_json)
        write_script
        expect(GuidedScript.last.failure_reason).to include("therapy")
      end

      it "completes when the banned word is the person's own" do
        intention.update!(sentence: "Letting my knee heal before the spring race.")
        gemini_returns(with_last_segment("You wrote: letting my knee heal.").to_json)
        write_script
        expect(GuidedScript.last.status).to eq("completed")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::CrisisError         => "988",
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no script" do
          gemini_raises(error_class)
          expect { write_script }.not_to change(GuidedScript, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message)
        end
      end
    end

    # The real pipeline: config/ai_guards.yml crisis terms, AiGatekeeper, GeminiService. Nothing is stubbed except
    # the HTTP layer, which must never be reached for a crisis sentence.
    context "when the sentence suggests a crisis" do
      before do
        create(:ai_template, name: "intentspring_script_v1",
                             user_prompt_template: "<sentence>\n{{sentence}}\n</sentence>\nLength in minutes: {{length_minutes}}\nTone: {{tone}}")
        sign_in_as(user)
      end

      it "shows 988 resources, makes no AI call, logs the block, and creates no script" do
        intention.update!(sentence: "Honestly I want to end my life and I don't know who to talk to.")
        expect(Faraday).not_to receive(:new)

        expect { write_script }.not_to change(GuidedScript, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("988", "Suicide &amp; Crisis Lifeline")
        expect(LlmRequest.where(user: user).pluck(:status)).to eq([ "gatekeeper_blocked" ])
      end

      it "lets a figure of speech through to the model (benign look-alike)" do
        intention.update!(sentence: "Getting back to my thesis every morning, even though this deadline is killing me.")
        allow_any_instance_of(GeminiService).to receive(:call_gemini).and_return([ valid_result.to_json, 100, 400 ])

        write_script
        expect(GuidedScript.last.status).to eq("completed")
        expect(LlmRequest.where(user: user).pluck(:status)).to eq([ "success" ])
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the intention, calls no AI, and creates no script" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { write_script }.not_to change(GuidedScript, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th script within a minute" do
        sign_in_as(user)
        gemini_returns(valid_result.to_json)
        10.times { write_script }
        expect(response).to have_http_status(:redirect)
        write_script
        expect(response).to have_http_status(:too_many_requests)
        expect(GuidedScript.count).to eq(10)
      end
    end
  end

  describe "GET /intentions/:intention_id/scripts (the error page's Try again)" do
    it "redirects to the intention" do
      sign_in_as(user)
      get intention_guided_scripts_path(intention)
      expect(response).to redirect_to(intention_path(intention))
    end
  end

  describe "GET /intentions/:intention_id/scripts/:id" do
    context "for a completed script" do
      let(:script) { create(:guided_script, :completed, intention: intention, generated_at: 1.minute.from_now) }

      it "shows the sentence, every passage and pause, the making prompt, the actions, and the disclaimer" do
        sign_in_as(user)
        get intention_guided_script_path(intention, script)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          script.title, intention.sentence, script.segments.first["text"], "[pause, 8 seconds]", "[pause, 12 seconds]",
          "Something to make afterwards", "One photograph of the water", script.making_prompt["invitation"],
          "Download .md", "Show raw response", "Write another", "AI-generated.", "not therapy or medical advice"
        )
        expect(response.body).not_to include("[pause, 0 seconds]", "Your intention has changed")
      end
    end

    context "for a failed script" do
      it "shows the reason, Retry, and the raw response, with no download" do
        script = create(:guided_script, :failed, intention: intention)
        sign_in_as(user)
        get intention_guided_script_path(intention, script)
        expect(response.body).to include("could not be used", script.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the intention changed after the script" do
      script = create(:guided_script, :completed, intention: intention, generated_at: 1.hour.ago)
      intention.update!(tone: "warm")
      sign_in_as(user)
      get intention_guided_script_path(intention, script)
      expect(response.body).to include("Your intention has changed since this script was written")
    end

    it "does not show another user's script" do
      script = create(:guided_script, :completed, intention: intention)
      sign_in_as(other)
      get intention_guided_script_path(intention, script)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a script under a different intention of the same user" do
      script = create(:guided_script, :completed, intention: intention)
      sign_in_as(user)
      get intention_guided_script_path(create(:intention, user: user), script)
      expect(response).to redirect_to(root_path)
    end
  end
end
