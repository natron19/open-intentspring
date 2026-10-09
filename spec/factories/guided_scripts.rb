FactoryBot.define do
  factory :guided_script do
    association :intention
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status         { "completed" }
      generated_at   { Time.current }
      gemini_raw     { "{}" }
      title          { "The long way, by the river" }
      length_minutes { 1 }
      word_count     { 120 }
      segments do
        [
          { "text" => "Let your feet find the path by the river. You wrote: the long way.", "pause_seconds" => 8 },
          { "text" => "Your hands are empty. Let them stay that way for a while.", "pause_seconds" => 12 },
          { "text" => "The long way, by the river. Walk on when you are ready.", "pause_seconds" => 0 }
        ]
      end
      making_prompt do
        {
          "form"       => "photograph",
          "constraint" => "One photograph of the water, taken without stopping.",
          "invitation" => "On the way home, take one picture of the river as you pass it."
        }
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
