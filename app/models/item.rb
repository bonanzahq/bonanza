class Item < ApplicationRecord
	belongs_to :parent_item

	has_many :item_histories, -> { order(created_at: :desc) } , :dependent => :destroy
  has_many :line_items
  has_many :lendings, :through => :line_items

	enum :condition, { flawless: 0, flawed: 1, broken: 2 }
  enum :status, { available: 0, lent: 1, returned: 2, unavailable: 3, deleted: 4 }

  validates :quantity, numericality: { only_integer: true }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  validate :item_cannot_be_changed_if_lent

  after_save :create_history_record 
  after_commit :reindex_parent_item, on: [:create, :update, :destroy]

  alias_method :orig_destroy, :destroy

  def user_adjusted_quantity(lending)
    if line_item = lending.line_items.find_by(item_id: id)
      quantity - line_item.quantity
    else
      quantity
    end
  end

  def latest_item_history
    @latest_item_history ||= item_histories.last
  end

  def current_line_item=(line_item)
    @current_line_item = line_item
  end

  def destroy
    if item_histories.count > 1
      return_value = deleted!
      logger.debug("soft deleted item!")
    else 
      # destroy item!
      return_value = orig_destroy
    end
    begin
      parent_item.reindex
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
      Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
    end

    return_value
  end

  def resurrect
    if deleted?
      available!
      begin
        parent_item.reindex
      rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
        Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
      end
      logger.debug("item resurrected!")
    else
      errors.add(:base, "Fehler. Nur bereits gelöschte Artikel können wiederhergestellt werden.")
    end
  end

  private

    def item_cannot_be_changed_if_lent
      return unless status == "lent" && !status_changed?

      protected_changes = changed - %w[note status]
      if protected_changes.any?
        errors.add(:base, "Artikel ist ausgeliehen und kann deswegen nicht geändert werden.")
      end
    end

    def create_history_record
      logger.debug "trying to create history_record"
      logger.debug "by user #{User.current_user.fullname unless User.current_user.nil?}"
      logger.debug "#{saved_changes.keys}"
      logger.debug "current_line_item: #{@current_line_item.id}" if @current_line_item

      # observed_attributes = %w(id comment status condition) # id changes if item is created
      # unless (changed & observed_attributes).empty? # did any of the observed_attributes change?
      #   item_history = item_histories.new
      #   item_history.user = User.current_user unless User.current_user.nil?
      #   item_history.condition = condition if changed.include?('condition') || status_was == "returned" || status == "lent"       
      #   item_history.comment = comment if changed.include?('comment')
      #   item_history.status = status
      #   item_history.line_item = @current_line_item if @current_line_item && ( status == "lent" || status == "returned") # changed include line_itm_id

      #   if changed.include?('quantity')
      #     item_history.quantity = quantity
      #     item_history.quantity = @current_line_item.quantity if @current_line_item && status == "lent"
      #   end

      #   item_history.save

      #   logger.debug("saved history for item #{id}")
      # end

      item_history = item_histories.new

      if saved_change_to_id?
        item_history.created!
        item_history.user = User.current_user
        item_history.quantity = quantity
        item_history.note = note if saved_change_to_note?
      end

      if saved_change_to_note?
        item_history.user = User.current_user
        item_history.note = note.blank? ? nil : note
      end

      item_history.condition = condition if saved_change_to_condition? || status_was == "returned" || status == "lent"
      item_history.user = User.current_user if saved_change_to_condition? 

      if saved_change_to_status && status != "available"
        item_history.user = User.current_user
        
        item_history.status = status
        item_history.line_item = @current_line_item if @current_line_item && ( status == "lent" || status == "returned") # changed include line_itm_id

        if saved_change_to_quantity
          item_history.quantity = quantity
          item_history.quantity = @current_line_item.quantity if @current_line_item && status == "lent"
        end

      end

      if status == "returned"
        logger.debug("returned? #{id} #{status}")
        reload
        available!
        logger.debug("made available again #{id} #{status}")
      end

      if item_history.status.present? || item_history.note.present? || saved_change_to_condition?
        item_history.save
        logger.debug("saved history for item #{id}")
      end
    end

    def reindex_parent_item
      begin
        parent_item.reindex unless parent_item.nil?
      rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
        Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
      end
    end

end
