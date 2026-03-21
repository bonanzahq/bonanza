class LineItem < ApplicationRecord
  belongs_to :item
  belongs_to :lending

  has_many :item_histories, dependent: :nullify

  has_and_belongs_to_many :accessories

  validates :quantity, numericality: { only_integer: true }

  def take_back(params)
    begin
      ActiveRecord::Base.transaction do
        raise "Menge wurde nicht angegeben." unless params[:quantity].present?
        raise "Menge muss eine Zahl sein." unless params[:quantity].match(/^\d+$/)
        params[:quantity] = params[:quantity].to_i
        
        raise "Menge muss positiv sein." if params[:quantity] < 0
        raise "Menge ist größere als geliehene Menge." unless params[:quantity] <= self.quantity
        
        raise "Artikel mit Seriennummer sind einzigartig. Es können nicht mehrere davon zurückgegeben werden." if item.uid.present? && params[:quantity] != 1
        # raise "Für Artikel mit Seriennummer muss der Zustand angegeben werden." if item.uid.present? && params[:condition].nil?

        item.quantity += params[:quantity]
        # item.condition = params[:condition] if params[:condition].present?
        # item.comment = params[:comment] if params[:comment].present?
        item.current_line_item = self
        item.status = "returned"
        item.save!

        touch(:returned_at)
      end
    rescue => e
      logger.error("Error on taking back line_item with id #{id}: #{e.message}")
      self.errors.add(:base, "#{e.message}")
      return false
    end
  end

  def decrease_item_quantity
    item.quantity -= self.quantity
  end

  def apply_line_item_data_to_item(type, condition = nil, note = nil)
    item.condition = condition unless condition.nil?
    item.note = note
    item.current_line_item = self
    logger.debug("current line_item.item.id #{item.id}")
    logger.debug("item.quantity #{item.quantity}")
    logger.debug("line_item.quantity #{quantity}")
    item.status="lent" if type == "lent" && item.quantity == 0
    item.returned! if type == "returned"
  end

end
