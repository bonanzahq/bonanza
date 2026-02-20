# ABOUTME: Adds soft-delete fields for conducts and updates the unique ban index.
# ABOUTME: Lifted conducts retain history while allowing new bans for the same borrower.

class AddLiftedFieldsToConducts < ActiveRecord::Migration[8.1]
  def change
    add_column :conducts, :lifted_at, :datetime
    add_column :conducts, :lifted_by_id, :bigint
    add_foreign_key :conducts, :users, column: :lifted_by_id

    remove_index :conducts, name: "index_conducts_unique_active_ban_per_department"
    add_index :conducts, [:borrower_id, :department_id],
      unique: true,
      where: "kind = 1 AND lifted_at IS NULL",
      name: "index_conducts_unique_active_ban_per_department"
  end
end
