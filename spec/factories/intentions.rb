FactoryBot.define do
  factory :intention do
    association :user
    sentence       { "Walking to work the long way, by the river, without my phone in my hand." }
    length_minutes { 1 }
    tone           { "quiet" }
  end
end
