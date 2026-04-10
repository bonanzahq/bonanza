# ABOUTME: Adds foreign key constraints to line_items table.
# ABOUTME: Prevents orphaned line items by enforcing referential integrity.

class AddForeignKeysToLineItems < ActiveRecord::Migration[8.1]
  def up
    # Clean up orphaned line items before adding constraints.
    # These reference items or lendings that no longer exist.
    orphaned_by_item = execute(<<~SQL).cmd_tuples
      DELETE FROM line_items
      WHERE item_id IS NOT NULL
        AND item_id NOT IN (SELECT id FROM items)
    SQL

    orphaned_by_lending = execute(<<~SQL).cmd_tuples
      DELETE FROM line_items
      WHERE lending_id IS NOT NULL
        AND lending_id NOT IN (SELECT id FROM lendings)
    SQL

    if orphaned_by_item > 0 || orphaned_by_lending > 0
      say "Cleaned up #{orphaned_by_item} line items with missing items, #{orphaned_by_lending} with missing lendings"
    end

    add_foreign_key :line_items, :items
    add_foreign_key :line_items, :lendings
  end

  def down
    remove_foreign_key :line_items, :items
    remove_foreign_key :line_items, :lendings
  end
end
