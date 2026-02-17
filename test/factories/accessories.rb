# ABOUTME: FactoryBot factory for Accessory model.
# ABOUTME: Equipment accessories belonging to a ParentItem.

FactoryBot.define do
  factory :accessory do
    sequence(:name) { |n| "Accessory #{n}" }
    association :parent_item
  end
end
