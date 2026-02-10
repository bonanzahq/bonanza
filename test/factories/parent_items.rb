# ABOUTME: FactoryBot factory for ParentItem model.
# ABOUTME: Equipment type that groups individual items.

FactoryBot.define do
  factory :parent_item do
    sequence(:name) { |n| "Equipment #{n}" }
    description { "A piece of equipment" }
    association :department
  end
end
