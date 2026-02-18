# ABOUTME: Conduct model - warnings and bans for borrowers, scoped to a department.
# ABOUTME: Includes expiration logic, warning escalation, and automatic conduct cleanup.

class Conduct < ApplicationRecord
  belongs_to :borrower
  belongs_to :department
  belongs_to :lending, optional: true
  belongs_to :user, optional: true

  enum :kind, { warned: 0, banned: 1 }

  validates :reason, presence: { message: "Es muss ein Grund angegeben werden." }
  validates :borrower_id, presence: { message: "Es muss eine ausleihende Person angegeben werden." }
  validates :department, presence: { message: "Es muss eine Werkstatt angeben werden" }
  validates :duration, numericality: { only_integer: true, allow_nil: true, message: "Es muss eine Anzahl an Tagen angegeben werden." }

  validate do
    user_added_duration_or_perma?
  end

  after_commit :reindex_borrower, on: [:create, :update, :destroy]
  after_create_commit :notify_and_escalate

  # Destroys conducts whose duration has elapsed and stale automatic conducts.
  # Returns the destroyed records so callers can act on them (e.g. send emails).
  def self.remove_expired
    expired_with_duration = where(permanent: false)
      .where.not(duration: nil)
      .where("created_at + (duration * INTERVAL '1 day') < ?", Time.current)

    stale_automatic = where(permanent: false, duration: nil, user_id: nil)
      .where("created_at < ?", 60.days.ago)

    removed = []
    (expired_with_duration.to_a + stale_automatic.to_a).uniq.each do |conduct|
      conduct.destroy
      removed << conduct
    end
    removed
  end

  # Creates an automatic ban when a borrower accumulates 2 or more warnings
  # in a department and has no existing ban. Returns nil if escalation is not needed.
  def self.check_warning_escalation(borrower, department)
    warning_count = where(borrower: borrower, department: department, kind: :warned).count
    return nil unless warning_count >= 2
    return nil if where(borrower: borrower, department: department, kind: :banned).exists?

    create!(
      borrower: borrower,
      department: department,
      kind: :banned,
      reason: "Automatische Sperre nach #{warning_count} Verwarnungen",
      permanent: false,
      duration: 30,
      user_id: nil
    )
  end

  def expired?
    return false if permanent?
    return false if duration.nil?
    created_at + duration.days < Time.current
  end

  def days_remaining
    return nil if permanent?
    return nil if duration.nil?
    remaining = ((created_at + duration.days - Time.current) / 1.day).ceil
    [remaining, 0].max
  end

  def expiration_date
    return nil if permanent?
    return nil if duration.nil?
    (created_at + duration.days).to_date
  end

  def automatic?
    user_id.nil?
  end

  private
    def notify_and_escalate
      if banned? && automatic?
        BorrowerMailer.auto_ban_notification_email(self).deliver_later(queue: :critical)
      end

      if warned?
        Conduct.check_warning_escalation(borrower, department)
      end
    end

    def user_added_duration_or_perma?
      if user && permanent == false && duration.to_i <= 0
        errors.add(:permanent, "Die Sperre muss dauerhaft sein oder es muss eine Dauer angeben werden.")
        false
      end
    end

    def reindex_borrower
      borrower.reindex
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
      Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
    end
end
