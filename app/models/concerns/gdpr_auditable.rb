# ABOUTME: Logs GDPR-relevant actions (anonymization, export, deletion) as structured JSON.
# ABOUTME: Include in models that handle personal data. Creates persistent GdprAuditLog records.

module GdprAuditable
  extend ActiveSupport::Concern

  included do
    has_many :gdpr_audit_logs, as: :target
  end

  def log_gdpr_event(action, performed_by: nil, metadata: {})
    GdprAuditLog.create!(
      action: action,
      target: self,
      performed_by: performed_by,
      metadata: metadata
    )

    Rails.logger.info({
      gdpr_audit: true,
      action: action,
      model: self.class.name,
      record_id: id,
      performed_by: performed_by&.id,
      timestamp: Time.current.iso8601
    }.merge(metadata).to_json)
  end
end
