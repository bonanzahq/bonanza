class ItemHistory < ApplicationRecord
  belongs_to :item
  belongs_to :user, optional: true
  belongs_to :line_item, optional: true

  enum condition: { flawless: 0, flawed: 1, broken: 2 }
  enum status: { available: 0, lent: 1, returned: 2, unavailable: 3, deleted: 4, created: 5 }

end
