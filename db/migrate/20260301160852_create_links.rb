class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.string :url, null: false
      t.string :title
      t.references :parent_item, null: false, foreign_key: true

      t.timestamps
    end
  end
end
