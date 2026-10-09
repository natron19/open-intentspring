class GuidedScript < ApplicationRecord
  belongs_to :intention
  has_one :user, through: :intention

  STATUSES = %w[pending completed failed].freeze

  # The forms a making prompt may suggest: production IntentSpring's Offering kinds, less guided audio itself.
  FORMS = %w[poem song photograph letter recipe drawing short_film reading].freeze

  # Spoken pace the template writes to, and how far a script may drift from it before the parser rejects it.
  WORDS_PER_MINUTE = 130
  LENGTH_TOLERANCE = 0.25

  validates :status, inclusion: { in: STATUSES }

  # The word counts a script of this many minutes must fall within: 130 words a minute, plus or minus 25%.
  def self.word_range(minutes)
    target = WORDS_PER_MINUTE * minutes
    (target * (1 - LENGTH_TOLERANCE)).ceil..(target * (1 + LENGTH_TOLERANCE)).floor
  end

  # Spoken words only: anything in square brackets is a direction, not something to read aloud.
  def self.count_words(texts)
    Array(texts).join(" ").gsub(/\[[^\]]*\]/, " ").scan(/[[:alnum:]][[:alnum:]'’-]*/).size
  end

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The intention was edited after this script was written.
  def stale?
    generated_at.present? && intention.updated_at > generated_at
  end

  def form_label
    making_prompt["form"].to_s.tr("_", " ")
  end

  def total_pause_seconds
    segments.sum { |s| s["pause_seconds"].to_i }
  end

  def to_markdown
    lines = []
    lines << "# #{title}"
    lines << ""
    lines << "_#{Intention.length_label(length_minutes)}, #{intention.tone}. Generated #{generated_at&.strftime('%Y-%m-%d') || 'unknown'} " \
             "by #{ENV.fetch('APP_NAME', 'IntentSpring Demo')}. AI-generated: a script for you to read aloud or record yourself. " \
             "It is not therapy or medical advice. Change anything that does not sound like you._"
    lines << ""
    lines << "> #{intention.sentence}"
    lines << ""
    segments.each do |segment|
      lines << segment["text"]
      lines << ""
      lines << "_[pause, #{segment['pause_seconds']} seconds]_" if segment["pause_seconds"].to_i.positive?
      lines << "" if segment["pause_seconds"].to_i.positive?
    end
    lines << "## Something to make afterwards"
    lines << ""
    lines << "- **Form:** #{form_label}"
    lines << "- **Constraint:** #{making_prompt['constraint']}"
    lines << ""
    lines << making_prompt["invitation"].to_s
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = title.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "guided-script"
    "#{slug}-guided-script.md"
  end
end
