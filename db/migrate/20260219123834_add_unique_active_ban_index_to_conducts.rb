# ABOUTME: Migration to enforce one active ban per borrower per department at the database level.
# ABOUTME: Adds a partial unique index covering only banned conducts (kind = 1).

class AddUniqueActiveBanIndexToConducts < ActiveRecord::Migration[8.1]
  def change
    add_index :conducts, [:borrower_id, :department_id],
      unique: true,
      where: "kind = 1",
      name: "index_conducts_unique_active_ban_per_department"
  end
end
