# ABOUTME: FactoryBot factory for Borrower model.
# ABOUTME: Defaults to student type with required validation fields set.

FactoryBot.define do
  factory :borrower do
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }
    sequence(:email) { |n| "borrower#{n}@example.com" }
    phone { Faker::PhoneNumber.phone_number }
    borrower_type { :student }
    insurance_checked { true }
    id_checked { true }
    sequence(:student_id) { |n| "s#{n.to_s.rjust(5, '0')}" }
    tos_accepted { false }

    trait :employee do
      borrower_type { :employee }
      id_checked { false }
      insurance_checked { false }
      student_id { nil }
    end

    trait :with_tos do
      tos_accepted { true }
    end
  end
end
