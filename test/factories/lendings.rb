# ABOUTME: FactoryBot factory for Lending model.
# ABOUTME: Equipment lending with state machine (cart -> borrower -> confirmation -> completed).

FactoryBot.define do
  factory :lending do
    association :user
    association :department
    state { :cart }

    trait :with_borrower do
      borrower { association :borrower, :with_tos }
      state { :borrower }
    end

    trait :completed do
      borrower { association :borrower, :with_tos }
      state { :completed }
      lent_at { Time.current }
      duration { 14 }
    end
  end
end
