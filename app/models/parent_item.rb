class ParentItem < ApplicationRecord
  acts_as_taggable_on :tags
  has_many_attached :files

  belongs_to :department
  has_many :items, -> {order "id ASC"}, dependent: :destroy
  has_many :accessories, :dependent => :destroy
  has_many :links, dependent: :destroy

  accepts_nested_attributes_for :items, :allow_destroy => true
  accepts_nested_attributes_for :accessories, :reject_if => :reject_accessory, :allow_destroy => true
  accepts_nested_attributes_for :links, reject_if: :reject_link, allow_destroy: true

  validate :accessories_cannot_change_if_lent

  searchkick word_middle: [:name, :description, :tags], search_synonyms: "elastic_synonyms.txt"

  attr_accessor :new_files

  def search_data
    {
      name: name,
      description: description,
      uids: items.pluck(:uid),
      tags: all_tags_list,
      department: department.id,
      statuses: items.collect(&:status),
      conditions: items.collect(&:condition),
      lendings_count: items.joins(:line_items).count # to boost frequently lent items
    }
  end

  def self.search_items(query, dept, status = nil, condition = nil, page = 1 )
    page = 1 unless page

    query = "*" if query.blank?
    
    unless depts = dept.to_s.split(",")
      depts = dept
    end

    where = {department: depts}
    
    if status.blank?
      where.merge!({statuses: ["available", "lent"] })
    end

    if status.present? && status.kind_of?(Array)
      s = status.select{ |s| Item.statuses.key?(s)} 
      where.merge!({statuses: s }) unless s.nil? && s.count < 1
    end

    if condition.blank?
      where.merge!({conditions: ["flawless", "flawed", "broken"] })
    end

    if condition.present? && condition.kind_of?(Array)
      c = condition.select{ |c| Item.conditions.key?(c)} 
      where.merge!({conditions: c }) unless c.nil? && c.count < 1
    end

    begin
      results = self.search(query, where: where, load: true, page: page, per_page: 6, order: [{_score: :desc}, {lendings_count: :desc}, {name: :asc}], boost_by: [:lendings_count], misspellings: {edit_distance: 2}, aggs: { tags: { where: { department: depts}}}, fields: [{"name^20" => :word_middle}, {"description^10" => :word_middle}, "uids", {"tags^12" => :word_middle}])
      results.to_a # force lazy evaluation inside rescue
      results
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error, Searchkick::InvalidQueryError => e
      Rails.logger.warn("Elasticsearch unavailable or query error: #{e.message}")
      ParentItem.none.page(1).per(6)
    end
  end

  def attach_files
    return if new_files.blank?

    files.attach(new_files)
    self.new_files = []
  end

  def has_lent_items?
    items.exists?(status: :lent)
  end

  private

    # def are_items_still_fresh?
    #   freshness = true
    #   items.each do |item|
    #     freshness = false if item.item_histories.count > 2
    #   end

    #   errors.add(:base, "Artikelstamm und zugehörige Daten können nicht gelöscht werden, da Artikel schon ausgeliehen wurden.") unless freshness == true
    #   freshness # return false for a rollback
    # end

    def accessories_cannot_change_if_lent
      return unless has_lent_items?
      return unless accessories.any? { |a| a.new_record? || a.changed? || a.marked_for_destruction? }

      errors.add(:base, "Zubehör kann nicht geändert werden, solange Artikel verliehen sind.")
    end

    def reject_accessory(attributes)
      attributes[:name]&.strip!

      exists = attributes[:id].present?
      empty = attributes[:name].blank?
      attributes.merge!({:_destroy => 1}) if exists and empty
      return (!exists and empty)
    end

    def reject_link(attributes)
      attributes[:url]&.strip!
      attributes[:url].blank? && !attributes[:id].present?
    end

    def reject_item(attributes)
      exists = attributes['id'].present?
      empty = attributes['uid'].blank? && attributes['quantity'].blank?
      attributes.merge!({:_destroy => 1}) if exists and empty
      return (!exists and empty)
    end
end
