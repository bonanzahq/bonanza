class Lending < ApplicationRecord
  belongs_to :user
  belongs_to :department
  belongs_to :borrower, optional: true

  has_many :line_items, :dependent => :destroy
  has_many :items, :through => :line_items
  # has_many :conducts, :dependent => :destroy

  enum :state, { cart: 0, borrower: 1, confirmation: 2, completed: 3 }

  accepts_nested_attributes_for :line_items, :allow_destroy => true
  accepts_nested_attributes_for :borrower

  validates :duration, numericality: { only_integer: true }, allow_blank: true
  
  validate do
    borrower_has_accepted_tos?
    ensure_new_return_date_is_in_the_future
  end

  before_create :create_token

  scope :unfinished, -> { where(lent_at: nil) }

  def populate(item_id, quantity = 1)
    quantity = quantity.to_i # if quantity is letters, then quantity will be 0

    return errors.add(:base, "Die Werkstatt ist vorübergehend geschlossen. Es können deshalb keine Artikel verleihen werden.") && false unless User.current_user.current_department.staffed
    return errors.add(:item, "Es muss eine auszuleihende Menge angegeben werden." ) && false if quantity == 0 

    begin
      item = Item.find(item_id)
    rescue ActiveRecord::RecordNotFound
      return errors.add(:item, "Artikel existiert nicht.")
    end

    return errors.add(:item, "Artikel ist nicht verfügbar") && false unless item.available?

    current_item = line_items.find_by(item_id: item.id)

    return errors.add(:item, "Es können keine Artikel aus anderen Werkstätten verliehen werden." ) && false if item.parent_item.department_id != User.current_user.current_department_id

    if current_item
      return errors.add(:line_item_quantity, "Es sind nicht genügend Exemplare vorhanden." ) && false if current_item.quantity + quantity > item.quantity
      current_item.quantity += quantity  
    else
      return errors.add(:line_item_quantity, "Es sind nicht genügend Exemplare vorhanden." ) && false if quantity > item.quantity
      current_item = line_items.build(item: item, quantity: quantity)
    end

    current_item
  end

  def update_cart(params)
    if update(params)
      self.line_items.each do |line_item|
        line_item.destroy if line_item.quantity < 1
      end

      true
    else
      false
    end
  end

  def update_from_checkout_params(params, current_user, accessories = nil)
    return false unless params
    
    if self.update(params) && self.confirmation?
      return finalize!(params, accessories)
    else
      return false unless self.valid?
      advance
    end
  end

  def eradicate
    begin
      ActiveRecord::Base.transaction do
        raise ActiveRecord::RecordInvalid unless self.returned_at.nil?
        
        line_items.each do |line_item|
          item = line_item.item
          item.quantity += line_item.quantity
          item.available!
          # line_item.item_histories.destroy_all
          line_item.destroy
        end

        destroy
      end
    rescue => e
      logger.error("Error removing lending with id #{self.id}: #{e.message}")
      return false
    end
  end

  def all_items_returned?
    unless line_items.where(returned_at: nil).any?
      # conducts.delete_all
      touch(:returned_at)
    end
  end

  def has_line_items?
    line_items.any?
  end

  def has_checkout_step?(step)
    step.present? && Lending.states.has_key?(step)
  end

  # only allow previous and current states
  def can_go_to_state?(state)
    return false unless has_checkout_step?(state)
    checkout_step_index(state) <= checkout_step_index(self.state)
  end

  def advance
    self.state = checkout_step_index(self.state) + 1
    return false if self.confirmation? and self.borrower.nil?
    self.save
  end

  def is_overdue?
    return false if lent_at.nil? or duration.nil?

    (lent_at.to_date + duration.days) < Date.today
  end

  # cronjob will invoke this everyday at 11:30pm
  def self.remove_abandoned_carts
    Lending.unfinished.where('created_at < ?', 2.days.ago).each do |model|
      model.destroy
    end
  end

  # cronjob will invoke this everyday at 7:00pm to notify lenders of overdue lendings
  def self.notify_lender_of_overdue_lending
    # logger.info("notifying lenders of overdue lendings")
    # lendings = Lending.where(returned_at: nil).where("notification_counter < 2").where("DATE(#{PortableQuery.date_add('DATE(lent_at)', 'duration')}) <= #{PortableQuery.today}")

    # lendings.each do |lending|
    #   logger.debug("lending #{lending.id}")
    #   if lending.department.staffed
    #     logger.debug("department is staffed")
    #     # werkstatt ist besetzt?
    #     logger.debug("Date.today: #{Date.today}")
    #     logger.debug("lent at: #{lending.lent_at.to_date}")
    #     logger.debug("duration: #{lending.duration}")
    #     logger.debug("rechnung: #{(Date.today - lending.lent_at.to_date - lending.duration).to_i}")
    #     if ((Date.today - lending.lent_at.to_date - lending.duration).to_i % 7 == 0)
    #       logger.debug("first")
    #       # notifications werde alle sieben tage ab dem Rückgabedatum verschickt
    #       if lending.lent_at.to_date < lending.department.staffed_at.to_date
    #         logger.debug("lending was before closed department")
    #         logger.debug("deparment was closed: #{lending.department.staffed_at.to_date}")
    #         # ausleihen, die vor der krankheit getätigt wurde

    #         if( (Date.today-lending.department.staffed_at.to_date).to_i >= 6)
    #           # notifications werden 7 tage nach dem die werkstatt wieder geöffnet hat, verschickt
    #           send_overdue_notification_mail(lending)
    #         else
    #           # do nothing e.g. wait
    #         end
    #       else
    #         # ausleihen die im normalen ablauf getätigt wurden
    #         send_overdue_notification_mail(lending)
    #       end

    #     elsif ((Date.today - lending.lent_at.to_date - lending.duration).to_i % 7 == 6 )
    #       logger.debug("second")
    #       # notifications werde alle sieben tage ab einem Tag vor dem Rückgabedatum verschickt

    #       if (lending.lent_at.to_date < lending.department.staffed_at.to_date)
    #         if ((Date.today-lending.department.staffed_at.to_date).to_i >= 5 )
    #           # upcoming return notifications werden 6 tage nach dem die werkstatt wieder geöffnet hat, verschickt
    #           begin
    #             LendingMailer.upcoming_overdue_return_notification_email(lending).deliver_now
    #           rescue Exception => e
    #             # TODO log exception
    #           end
    #           logger.info("sent upcoming_overdue_return_notification_email")
    #         else
    #           # do nothing e.g. wait

    #         end
    #       else
    #         # Ausleihen die im normalen Ablauf getätigt wurden
    #         begin
    #           LendingMailer.upcoming_overdue_return_notification_email(lending).deliver_now
    #         rescue Exception => e
    #           # TODO log exception
    #         end
    #         logger.info("sent upcoming_overdue_return_notification_email")
    #       end
    #     else
    #       logger.debug("nothin applied")
    #     end

    #   end
    # end
    # logger.info("finished notifying lenders of overdue lendings")
  end

  # cronjob will invoke this everyday at 6:00pm OK
  def self.notify_lender_of_upcoming_return
    # logger.info("notifying lenders of upcoming lendings")
    # upcoming_returns = Lending.where(returned_at: nil).where("DATE(#{PortableQuery.date_add('DATE(lent_at)', 'duration')}) = #{PortableQuery.date_add(PortableQuery.today, '1')}")

    # upcoming_returns.each do |lending|
    #   if lending.department.staffed
    #     # send kind notification mail of upcoming return if department is staffed
    #     begin
    #       LendingMailer.upcoming_return_notification_email(lending).deliver_now
    #     rescue Exception => e
    #       # TODO log exception
    #     end
    #   end
    # end
    # logger.info("finished notifying lenders of upcoming lendings")
  end

  # cronjob will invoke this everyday at 6:45pm OK
  def self.notify_lender_of_staffed_department
    # logger.info("notifying lenders of staffed department")
    # overdue_returns = Lending.where(returned_at: nil).where("DATE(#{PortableQuery.date_add('DATE(lent_at)', 'duration')}) < #{PortableQuery.today}")

    # overdue_returns.each do |lending|
    #   if lending.department.staffed_at.to_date == Date.today
    #     # send notification of staffed department to overdue lendings
    #     begin
    #       LendingMailer.department_staffed_again_notification_email(lending).deliver_now
    #     rescue Exception => e
    #       # TODO log exception
    #     end
    #   end
    # end
    # logger.info("finished notifying lenders of overdue lendings")
  end

  private
    def borrower_has_accepted_tos?
      return errors.add(:base, "Die Ausleihende Person hat die Registrierung nicht bestätigt.") && false if borrower && !borrower.tos_accepted
    end

    def ensure_new_return_date_is_in_the_future
      if lent_at != nil && duration_changed? && lent_at.to_date + duration.days < Date.today
        errors.add(:duration, "Die Ausleihfrist muss in der Zukunft enden.")
        false
      else
        true
      end
    end

    def checkout_step_index(step)
      Lending.states[step]
    end

    def finalize!(params, accessory_options)
      department = User.current_user.current_department

      if borrower.has_bans_here?
        return self.errors.add(:base, "Die ausleihende Person ist gesperrt.") && false 
      end

      begin
        ActiveRecord::Base.transaction do
          raise "Es sind keine Artikel vorhanden, um ausgeliehen zu werden." unless has_line_items?
          
          line_items.each do |line_item|
            raise "Artikel muss verfügbar sein, um ausgeliehen werden zu können." unless line_item.item.available? 
            line_item.decrease_item_quantity
            line_item.apply_line_item_data_to_item("lent")
            if !accessory_options.nil? && accessory_options["line_items"].keys.any?
              if accessory_options["line_items"].keys.include?(line_item.id.to_s)
                line_item.accessory_ids = accessory_options["line_items"][line_item.id.to_s]
              end
            end
            line_item.item.save!
            begin
              line_item.item.parent_item.reindex
            rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
              Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
            end
          end
          user = User.current_user

          completed!
          touch :lent_at
        end
      rescue => e
        logger.error("Fehler beim Finalisieren der Ausleihe: #{e.message}")
        return false
      end
      
    end

    def self.send_overdue_notification_mail(lending)

      # if lending.notification_counter == 0
      #   # first warning
      #   begin
      #     LendingMailer.overdue_notification_email(lending).deliver_now
      #     logger.info("sent overdue_notification_email")
      #     lending.increment(:notification_counter)

      #     # add conduct warned to lender
      #     conduct = Conduct.new
      #     conduct.reason = "Leihfrist überschritten"
      #     conduct.lender_id = lending.lender.id
      #     conduct.department_id = lending.department_id
      #     conduct.warned!
          
      #     lending.conducts << conduct
      #     lending.save
      #   rescue Exception => e
      #     logger.error("error on overdue_notification_email for lending id #{lending.id}")
      #   end
      
      # elsif lending.notification_counter == 1
      #   # second notification with ban

      #   begin
      #     LendingMailer.banned_notification_email(lending).deliver
      #     logger.info("sent banned_notification_email")
      #     lending.increment(:notification_counter)
          
      #     # add conduct banned to lender
      #     conduct = Conduct.new
      #     conduct.reason = "Leihfrist zum zweiten Mal überschritten"
      #     conduct.lender_id = lending.lender.id
      #     conduct.department_id = lending.department_id
      #     conduct.duration = 8
      #     conduct.banned!
          
      #     lending.conducts << conduct
          
      #     # lending.notification_counter = 0
      #     lending.save
      #   rescue Exception => e
      #     logger.error("error on banned_notification_email for lending id #{lending.id}")
      #   end

      # end
    end

    def create_token
      self.token ||= loop do
        # random_token = SecureRandom.random_number(36**6).to_s(36).rjust(6, "0") # token length for humans?
        random_token = SecureRandom.urlsafe_base64(64, false)
        break random_token unless self.class.exists?(token: random_token)
      end
    end

end
