# ABOUTME: FactoryBot factory for User model.
# ABOUTME: Handles department membership setup required by User validations.

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "platypus-umbrella-cactus" }
    password_confirmation { "platypus-umbrella-cactus" }
    firstname { Faker::Name.first_name }
    lastname { Faker::Name.last_name }

    transient do
      role { :member }
      department { nil }
    end

    after(:build) do |user, evaluator|
      if user.department_memberships.empty?
        dept = evaluator.department || create(:department)
        user.department_memberships.build(department: dept, role: evaluator.role)
        user.current_department = dept
      end
    end

    trait :admin do
      admin { true }
    end

    trait :leader do
      role { :leader }
    end

    trait :guest do
      role { :guest }
    end
  end
end
