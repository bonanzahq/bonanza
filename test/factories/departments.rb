# ABOUTME: FactoryBot factory for Department model.
# ABOUTME: Provides defaults and traits for staffed/hidden departments.

FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "Werkstatt #{n}" }
    room { "Raum 101" }
    staffed { true }
    staffed_at { 1.day.ago }
    genus { :female }
    hidden { false }
    default_lending_duration { 14 }
  end
end
