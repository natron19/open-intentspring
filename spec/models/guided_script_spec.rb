require "rails_helper"

RSpec.describe GuidedScript, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:guided_script)).to be_valid
    end

    it "requires an intention" do
      expect(build(:guided_script, intention: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      GuidedScript::STATUSES.each { |s| expect(build(:guided_script, status: s)).to be_valid }
      expect(build(:guided_script, status: "unknown")).not_to be_valid
    end
  end

  describe "constants" do
    it "lists the statuses, forms and pace" do
      expect(GuidedScript::STATUSES).to eq(%w[pending completed failed])
      expect(GuidedScript::FORMS).to eq(%w[poem song photograph letter recipe drawing short_film reading])
      expect(GuidedScript::WORDS_PER_MINUTE).to eq(130)
      expect(GuidedScript::LENGTH_TOLERANCE).to eq(0.25)
    end
  end

  describe "associations and defaults" do
    it "has a user through its intention" do
      script = create(:guided_script)
      expect(script.user).to eq(script.intention.user)
    end

    it "starts pending with no segments and an empty making prompt" do
      script = GuidedScript.create!(intention: create(:intention))
      expect(script.status).to eq("pending")
      expect(script.segments).to eq([])
      expect(script.making_prompt).to eq({})
    end
  end

  describe ".word_range" do
    it "is 130 words a minute, plus or minus 25%" do
      expect(GuidedScript.word_range(1)).to eq(98..162)
      expect(GuidedScript.word_range(3)).to eq(293..487)
      expect(GuidedScript.word_range(5)).to eq(488..812)
      expect(GuidedScript.word_range(10)).to eq(975..1625)
    end
  end

  describe ".count_words" do
    it "counts spoken words across passages, including contractions and hyphenated words" do
      expect(GuidedScript.count_words([ "Sit however you're sitting.", "A well-worn chair, again." ])).to eq(8)
    end

    it "does not count bracketed directions or stray punctuation" do
      expect(GuidedScript.count_words([ "Breathe in. [pause, three breaths] Breathe out - slowly." ])).to eq(5)
    end
  end

  describe "#stale?" do
    it "is true when the intention changed after the script" do
      script = create(:guided_script, :completed, generated_at: 1.hour.ago)
      script.intention.update!(tone: "warm")
      expect(script.stale?).to be(true)
    end

    it "is false for a script written after the last edit" do
      script = create(:guided_script, :completed, generated_at: 1.minute.from_now)
      expect(script.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    let(:script) { create(:guided_script, :completed) }

    it "has the title, the disclaimer, the sentence, every passage and its pause, and the making prompt" do
      md = script.to_markdown
      expect(md).to start_with("# The long way, by the river\n")
      expect(md).to include("AI-generated", "It is not therapy or medical advice", "> #{script.intention.sentence}")
      expect(md).to include(script.segments.first["text"], "_[pause, 8 seconds]_", "_[pause, 12 seconds]_")
      expect(md).not_to include("[pause, 0 seconds]")
      expect(md).to include("## Something to make afterwards", "**Form:** photograph", script.making_prompt["invitation"])
    end

    it "names the file after the title" do
      expect(script.markdown_filename).to eq("the-long-way-by-the-river-guided-script.md")
    end
  end

  it "adds up the pauses" do
    expect(build(:guided_script, :completed).total_pause_seconds).to eq(20)
  end
end
