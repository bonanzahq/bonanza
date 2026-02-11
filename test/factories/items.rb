# ABOUTME: FactoryBot factory for Item model.
# ABOUTME: Individual equipment piece belonging to a ParentItem.

FactoryBot.define do
  factory :item do
    association :parent_item
    sequence(:uid) { |n| "UID-#{n.to_s.rjust(4, '0')}" }
    quantity { 1 }
    status { :available }
    condition { :flawless }

    trait :lent do
      status { :lent }
    end

    trait :broken do
      condition { :broken }
    end
  end
end
