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
  end
end
