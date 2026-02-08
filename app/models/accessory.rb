class Accessory < ApplicationRecord
  belongs_to :parent_item
  has_and_belongs_to_many :line_items
end
