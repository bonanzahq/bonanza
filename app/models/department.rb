class Department < ApplicationRecord
	acts_as_tagger
	
	has_many :department_memberships, :dependent => :destroy
	validates :name, uniqueness: true
	has_many :users, -> { distinct }, :through => :department_memberships
	has_many :parent_items

  has_many :lendings

  enum :genus, { female: 0, male: 1, neuter: 2 }

	before_create :create_memberships_for_all_users

	def self.get_all_visible_ids
		self.where(hidden: false).pluck(:id)
	end

	def staffed=(val)
    val = ActiveModel::Type::Boolean.new.cast(val)
    if val
      if self[:staffed] != true
        self[:staffed] = true
        self[:staffed_at] = DateTime.now
      end
    elsif val == false
      self[:staffed] = false
    end
  end

  def genderize(key)
    "#{key}_#{self.genus}"
  end

	private
		def create_memberships_for_all_users
			self.users |= User.all
		end
end
