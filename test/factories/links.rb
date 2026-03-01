# ABOUTME: FactoryBot factory for Link model.
# ABOUTME: External URLs attached to a ParentItem.

FactoryBot.define do
  factory :link do
    sequence(:url) { |n| "https://example.com/link-#{n}" }
    title { "Example Link" }
    association :parent_item
  end
end
