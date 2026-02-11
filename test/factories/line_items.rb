# ABOUTME: FactoryBot factory for LineItem model.
# ABOUTME: Join between Lending and Item with quantity tracking.

FactoryBot.define do
  factory :line_item do
    association :item
    association :lending
    quantity { 1 }
  end
end
