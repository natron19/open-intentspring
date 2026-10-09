require "rails_helper"

RSpec.describe Intention, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:intention)).to be_valid
    end

    it "requires a user" do
      expect(build(:intention, user: nil)).not_to be_valid
    end

    it "requires a sentence of 3 to 240 characters" do
      expect(build(:intention, sentence: "")).not_to be_valid
      expect(build(:intention, sentence: "Hi")).not_to be_valid
      expect(build(:intention, sentence: "Rest")).to be_valid
      expect(build(:intention, sentence: "a" * 240)).to be_valid
      expect(build(:intention, sentence: "a" * 241)).not_to be_valid
    end

    it "accepts only the four lengths" do
      Intention::LENGTHS.each { |m| expect(build(:intention, length_minutes: m)).to be_valid }
      [ 0, 2, 7, 15, nil ].each { |m| expect(build(:intention, length_minutes: m)).not_to be_valid }
    end

    it "accepts only the three tones" do
      Intention::TONES.each { |t| expect(build(:intention, tone: t)).to be_valid }
      expect(build(:intention, tone: "cheerful")).not_to be_valid
    end
  end

  describe "constants" do
    it "lists the lengths and tones" do
      expect(Intention::LENGTHS).to eq([ 1, 3, 5, 10 ])
      expect(Intention::TONES).to eq(%w[quiet plain warm])
      expect(Intention::TONE_LABELS.keys).to eq(Intention::TONES)
    end
  end

  describe "associations" do
    it "belongs to a user, who owns it" do
      intention = create(:intention)
      expect(intention.user.intentions).to include(intention)
    end

    it "destroys its scripts" do
      intention = create(:intention)
      create(:guided_script, :completed, intention: intention)
      expect { intention.destroy }.to change(GuidedScript, :count).by(-1)
    end

    it "finds the latest script" do
      intention = create(:intention)
      create(:guided_script, :completed, intention: intention, generated_at: 2.hours.ago)
      newest = create(:guided_script, :completed, intention: intention, generated_at: 1.minute.ago)
      expect(intention.latest_guided_script).to eq(newest)
    end
  end

  describe "#ai_variables" do
    it "sends only the sentence, the length and the tone" do
      intention = build(:intention, sentence: "Rest.", length_minutes: 10, tone: "warm")
      expect(intention.ai_variables).to eq(sentence: "Rest.", length_minutes: "10", tone: "warm")
    end

    it "never includes anything about the person" do
      user = create(:user, name: "Wren Halloway", email: "wren@example.com")
      values = build(:intention, user: user).ai_variables.values.join(" ")
      expect(values).not_to include("Wren", "Halloway", "wren@example.com")
    end
  end

  describe "labels" do
    it "says minute or minutes" do
      expect(build(:intention, length_minutes: 1).length_label).to eq("1 minute")
      expect(build(:intention, length_minutes: 5).length_label).to eq("5 minutes")
    end

    it "describes the tone" do
      expect(build(:intention, tone: "quiet").tone_label).to start_with("Quiet")
    end
  end
end
