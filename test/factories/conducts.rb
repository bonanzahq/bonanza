# ABOUTME: FactoryBot factory for Conduct model.
# ABOUTME: Warnings and bans for borrowers, scoped to a department and lending.

FactoryBot.define do
  factory :conduct do
    association :borrower
    association :department
    association :user
    association :lending
    reason { "Leihfrist überschritten" }
    kind { :warned }
    permanent { true }

    trait :banned do
      kind { :banned }
    end

    trait :with_duration do
      permanent { false }
      duration { 14 }
    end

    trait :automatic do
      user { nil }
      permanent { false }
      duration { nil }
    end

    trait :expired do
      permanent { false }
      duration { 1 }
      created_at { 2.days.ago }
    end
  end
end
