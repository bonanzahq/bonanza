class Conduct < ApplicationRecord
  belongs_to :borrower
  belongs_to :department
  belongs_to :lending, optional: true
  belongs_to :user, optional: true

  enum kind: { warned: 0, banned: 1 }

  validates :reason, presence: { message: "Es muss ein Grund angegeben werden." }
  validates :borrower_id, presence: { message: "Es muss eine ausleihende Person angegeben werden." }
  validates :department, presence: { message: "Es muss eine Werkstatt angeben werden" }
  validates :duration, numericality: { only_integer: true, allow_nil: true, message: "Es muss eine Anzahl an Tagen angegeben werden." }

  validate do
    user_added_duration_or_perma?
  end

  after_commit :reindex_borrower, on: [:create, :update, :destroy]

  # this will be invoked by a cron job each day at 7:30pm. Needs rework!
  # def self.remove_old_automatic_conducts
  #   conducts = Conduct.where(permanent: false, duration: nil).where("DATE(created_at) = #{PortableQuery.date_add(PortableQuery.today, '-60')}").destroy_all
  #   conducts += Conduct.where.not(permanent: true, duration: nil).where("DATE(#{PortableQuery.date_add('DATE(created_at)', 'duration')}) = #{PortableQuery.today}").destroy_all
  #   conducts.each do |conduct|
  #     LenderMailer.ban_lifted_notification_email(conduct).deliver_now
  #   end
  # end

  private
    def user_added_duration_or_perma?
      logger.debug("\n \n CHECKING IF PERMANENT or DURATION \n \n")
      logger.debug("permanent: #{permanent.to_s} \n")
      logger.debug("duration: #{duration.to_s} \n")
      logger.debug("\n")

      if user && permanent == false && duration.to_i <= 0
        self.errors.add(:permanent, "Die Sperre muss dauerhaft sein oder es muss eine Dauer angeben werden.")
        return false
      end
    end

    def reindex_borrower
      borrower.reindex
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error
    end
end
