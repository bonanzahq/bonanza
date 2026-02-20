# ABOUTME: Logs GDPR-relevant actions (anonymization, export, deletion) as structured JSON.
# ABOUTME: Include in models that handle personal data.

module GdprAuditable
  extend ActiveSupport::Concern

  private

  def log_gdpr_event(action, details = {})
    Rails.logger.info({
      gdpr_audit: true,
      action: action,
      model: self.class.name,
      record_id: id,
      timestamp: Time.current.iso8601
    }.merge(details).to_json)
  end
end
