class Intention < ApplicationRecord
  belongs_to :user
  has_many :guided_scripts, dependent: :destroy
  has_one :latest_guided_script,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "GuidedScript"

  LENGTHS = [ 1, 3, 5, 10 ].freeze
  TONES   = %w[quiet plain warm].freeze

  TONE_LABELS = {
    "quiet" => "Quiet: spare and slow, with long pauses",
    "plain" => "Plain: direct, everyday words",
    "warm"  => "Warm: gentle, spoken to you"
  }.freeze

  validates :sentence,       presence: true, length: { in: 3..240 }
  validates :length_minutes, presence: true, inclusion: { in: LENGTHS }
  validates :tone,           presence: true, inclusion: { in: TONES }

  def self.length_label(minutes)
    minutes == 1 ? "1 minute" : "#{minutes} minutes"
  end

  def length_label
    self.class.length_label(length_minutes)
  end

  def tone_label
    TONE_LABELS.fetch(tone, tone.to_s.humanize)
  end

  # Variables for the intentspring_script_v1 template. Only the one sentence, the length and the tone are sent:
  # nothing about the person, and no other intention.
  def ai_variables
    {
      sentence:       sentence,
      length_minutes: length_minutes.to_s,
      tone:           tone
    }
  end
end
