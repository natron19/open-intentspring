# Code check for IntentSpring's hard rules on a guided script: no therapy or healing framing, no diagnosis or
# clinical language, no assessment of progress or streaks, and no music or sound cues. The prompt forbids all of
# these; this check makes sure a script that slips through is never shown.
#
# A word the person wrote in their own sentence is allowed back (the script is told to return to their words),
# so "Letting my knee heal before the spring race" can be read back to them without the script being rejected.
#
#   BannedPhraseCheck.found_in(output_text, sentence) # => ["healing", "music cue"]
class BannedPhraseCheck
  RULES = {
    # Art is never framed as therapy or self-improvement.
    "therapy"          => /\btherap(?:y|ies|ist|ists|eutic|eutically)\b/i,
    "healing"          => /\bheal(?:s|ed|ing|er|ers)?\b/i,
    "self-improvement" => /\bself[- ]improvement\b/i,
    # No diagnosis, clinical or medication language.
    "diagnosis"        => /\bdiagnos(?:e|es|ed|is|ing|tic)\b/i,
    "disorder"         => /\bdisorders?\b/i,
    "symptom"          => /\bsymptoms?\b/i,
    "medication"       => /\bmedications?\b/i,
    "clinical"         => /\bclinical(?:ly)?\b/i,
    # Never assesses progress, consistency or streaks.
    "progress"         => /\bprogress\b/i,
    "streak"           => /\bstreaks?\b/i,
    "consistency"      => /\bconsisten(?:cy|t|tly)\b/i,
    "missed days"      => /\bmissed (?:a )?days?\b/i
  }.freeze

  # A music or sound cue: a bracketed or parenthesised direction that names music or a sound, or music that
  # "begins", "fades" and so on. A script about practising the piano may still say "piano" in plain speech.
  MUSIC_CUE = /
    [\[(][^\])]*\b(?:music|piano|chimes?|bells?|singing\s+bowl|sound|soundtrack|melody|drone|tone)\b[^\])]*[\])]
    | \bmusic\s+(?:begins|starts|plays|fades|swells|rises|ends|continues)\b
    | \b(?:soft|gentle|calm|ambient|background)\s+music\b
  /xi

  def self.found_in(output_text, input_text = "")
    new(output_text, input_text).found
  end

  def initialize(output_text, input_text = "")
    @output = output_text.to_s
    @input  = input_text.to_s
  end

  # Names of the rules the output breaks, in RULES order, with "music cue" last.
  def found
    hits = RULES.filter_map { |name, pattern| name if @output.match?(pattern) && !@input.match?(pattern) }
    hits << "music cue" if @output.match?(MUSIC_CUE)
    hits
  end
end
