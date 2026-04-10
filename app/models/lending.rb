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
  scope :with_orphaned_items, -> { joins(:line_items).merge(LineItem.orphaned).distinct }

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

  # Closes a lending regardless of item state. Handles orphaned line items
  # (where the referenced item no longer exists) and returns valid items.
  def force_close!(user, reason)
    raise RuntimeError, "Lending is already returned" if returned_at.present?
    raise ArgumentError, "Reason is required" if reason.blank?

    ActiveRecord::Base.transaction do
      line_items.each do |li|
        next if li.returned_at.present?

        item = Item.find_by(id: li.item_id)
        if item
          item.quantity += li.quantity
          item.status = :available
          item.save!(validate: false)
        end

        li.update_column(:returned_at, Time.current)
      end

      timestamp = Time.current.strftime("%Y-%m-%d %H:%M")
      close_note = "[Force-closed by #{user.email} at #{timestamp}] #{reason}"
      new_note = note.present? ? "#{note}\n#{close_note}" : close_note
      update_columns(returned_at: Time.current, note: new_note)
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

  # cronjob will invoke this everyday at 7:00pm to notify borrowers of overdue lendings
  def self.notify_borrowers_of_overdue_lending
    overdue = where(returned_at: nil)
      .where.not(lent_at: nil, duration: nil)
      .where("lent_at + (duration * INTERVAL '1 day') < ?", Date.current)

    overdue.find_each do |lending|
      next unless lending.department.staffed
      LendingMailer.overdue_notification_email(lending).deliver_later(queue: :default)
    end
  end

  # cronjob will invoke this everyday at 6:00pm to notify borrowers of upcoming returns
  def self.notify_borrowers_of_upcoming_return
    upcoming = where(returned_at: nil)
      .where.not(lent_at: nil, duration: nil)
      .where("DATE(lent_at + (duration * INTERVAL '1 day')) = ?", 1.day.from_now.to_date)

    upcoming.find_each do |lending|
      next unless lending.department.staffed
      LendingMailer.upcoming_return_notification_email(lending).deliver_later(queue: :default)
    end
  end

  # cronjob will invoke this everyday at 6:45pm to notify overdue borrowers when department reopens
  def self.notify_borrowers_of_staffed_department
    overdue = where(returned_at: nil)
      .where.not(lent_at: nil, duration: nil)
      .where("lent_at + (duration * INTERVAL '1 day') < ?", Date.current)

    overdue.find_each do |lending|
      next unless lending.department.staffed_at&.to_date == Date.current
      LendingMailer.department_staffed_again_notification_email(lending).deliver_later(queue: :default)
    end
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
          LendingMailer.confirmation_email(self).deliver_later(queue: :critical)
        end
      rescue => e
        logger.error("Fehler beim Finalisieren der Ausleihe: #{e.message}")
        return false
      end
      
    end

    def create_token
      self.token ||= loop do
        # random_token = SecureRandom.random_number(36**6).to_s(36).rjust(6, "0") # token length for humans?
        random_token = SecureRandom.urlsafe_base64(64, false)
        break random_token unless self.class.exists?(token: random_token)
      end
    end

end
