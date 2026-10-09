require "rails_helper"

RSpec.describe "db/seeds.rb" do
  # The seeds print progress lines; keep them out of the spec output.
  def load_seeds
    original, $stdout = $stdout, StringIO.new
    Rails.application.load_seed
  ensure
    $stdout = original
  end

  before { load_seeds }

  it "seeds the app template, the base templates, and no placeholder" do
    expect(AiTemplate.pluck(:name)).to contain_exactly("health_ping", "eval_judge_v1", "intentspring_script_v1")
  end

  it "seeds a template that takes only the sentence, the length and the tone" do
    template = AiTemplate.find_by!(name: "intentspring_script_v1")
    expect(template.variable_names).to contain_exactly("sentence", "length_minutes", "tone")
    expect(template.max_output_tokens).to eq(8192)
    expect(template.model).to eq("gemini-2.5-flash")
  end

  it "seeds one fictional intention with a completed script that passes the app's own rules" do
    intention = User.find_by!(email: "demo@example.com").intentions.sole
    script    = intention.guided_scripts.sole

    expect(script.status).to eq("completed")
    expect(GuidedScript.word_range(script.length_minutes)).to cover(script.word_count)
    expect(script.word_count).to eq(GuidedScript.count_words(script.segments.map { |s| s["text"] }))
    expect(GuidedScript::FORMS).to include(script.making_prompt["form"])
    text = [ script.title, *script.segments.map { |s| s["text"] }, *script.making_prompt.values ].join("\n")
    expect(BannedPhraseCheck.found_in(text, intention.sentence)).to eq([])
    expect(JSON.parse(script.gemini_raw).keys).to eq(%w[title length_minutes segments making_prompt])
  end

  it "can run twice without duplicating the example" do
    expect { load_seeds }.not_to change { [ Intention.count, GuidedScript.count, AiTemplate.count ] }
  end
end
