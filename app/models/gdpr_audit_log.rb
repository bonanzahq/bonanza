# ABOUTME: Persistent record of GDPR-relevant actions (anonymize, export, deletion).
# ABOUTME: Polymorphic target (Borrower/User) and optional performer (User).

class GdprAuditLog < ApplicationRecord
  ACTIONS = %w[anonymize export deletion_requested deletion_completed].freeze

  belongs_to :target, polymorphic: true
  belongs_to :performed_by, polymorphic: true, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :for_action, ->(action) { where(action: action) }
  scope :for_target, ->(target) { where(target: target) }
end
