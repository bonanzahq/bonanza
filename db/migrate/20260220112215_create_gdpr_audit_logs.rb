# ABOUTME: Creates the gdpr_audit_logs table for persistent GDPR action tracking.
# ABOUTME: Stores polymorphic target and performer with JSONB metadata.

class CreateGdprAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :gdpr_audit_logs do |t|
      t.string :action, null: false
      t.references :target, polymorphic: true, null: false
      t.references :performed_by, polymorphic: true
      t.jsonb :metadata, default: {}, null: false
      t.datetime :created_at, null: false
    end

    add_index :gdpr_audit_logs, :action
  end
end
