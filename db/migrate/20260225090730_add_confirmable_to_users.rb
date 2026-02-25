# ABOUTME: Adds Devise confirmable columns to users table.
# ABOUTME: Backfills confirmed_at for all existing users so they aren't locked out.
class AddConfirmableToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :confirmation_token, :string
    add_index :users, :confirmation_token, unique: true
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    # Backfill all existing users as confirmed so they can still sign in.
    # Users are created via invitation, not self-registration, so they are
    # already trusted. Without this, all existing users would be locked out.
    reversible do |dir|
      dir.up { execute "UPDATE users SET confirmed_at = NOW()" }
    end
  end
end
