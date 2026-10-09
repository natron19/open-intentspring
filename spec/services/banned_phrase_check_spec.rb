require "rails_helper"

RSpec.describe BannedPhraseCheck do
  def found(output, input = "")
    described_class.found_in(output, input)
  end

  it "passes a clean script" do
    expect(found("Sit however you are sitting. You wrote: mornings, again. Nothing needs to be different yet.")).to eq([])
  end

  {
    "therapy"          => "Think of this drawing as a kind of art therapy.",
    "healing"          => "Let this time help you heal.",
    "self-improvement" => "This is not about self-improvement, or is it?",
    "diagnosis"        => "Whatever your diagnosis, you can sit here.",
    "disorder"         => "An anxiety disorder does not decide this morning.",
    "symptom"          => "Notice each symptom as it comes.",
    "medication"       => "Take your medication first.",
    "clinical"         => "This is a clinically tested routine.",
    "progress"         => "You have made real progress this month.",
    "streak"           => "Keep your streak going.",
    "consistency"      => "Consistency is what matters most.",
    "missed days"      => "Do not worry about the missed days."
  }.each do |rule, text|
    it "finds #{rule} language" do
      expect(found(text)).to eq([ rule ])
    end
  end

  it "matches whole words only" do
    expect(found("Take a healthy breath. The heel of your hand rests on the table. A therapist-free afternoon? No: a theme.")).to eq([ "therapy" ])
    expect(found("Take a healthy breath. The heel of your hand rests on the table.")).to eq([])
  end

  it "allows a word the person wrote in their own sentence" do
    expect(found("You wrote: letting my knee heal before the spring race.", "Letting my knee heal before the spring race.")).to eq([])
    expect(found("You wrote: letting my knee heal. This is therapy.", "Letting my knee heal before the spring race.")).to eq([ "therapy" ])
  end

  describe "music and sound cues" do
    it "finds a bracketed or parenthesised cue" do
      expect(found("Breathe. [soft piano music begins] Breathe again.")).to eq([ "music cue" ])
      expect(found("Breathe. (a bell rings) Breathe again.")).to eq([ "music cue" ])
      expect(found("Sit. [sound of rain] Sit.")).to eq([ "music cue" ])
    end

    it "finds music that begins, fades or plays in the background" do
      expect(found("Let the music fade as you open your eyes. Gentle music under your breath.")).to eq([ "music cue" ])
      expect(found("Here the music begins.")).to eq([ "music cue" ])
    end

    it "lets a script about practising an instrument say so in plain speech" do
      expect(found("You wrote: practising cello scales slowly. Rest the bow on the strings. The piano can wait.")).to eq([])
    end

    it "is checked even when the sentence mentions music" do
      expect(found("[cello music plays softly]", "Practising cello music slowly")).to eq([ "music cue" ])
    end
  end

  it "reports every rule broken, music cue last" do
    expect(found("Your progress is healing you. [music fades]")).to eq([ "healing", "progress", "music cue" ])
  end
end
