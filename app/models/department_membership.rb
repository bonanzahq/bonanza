class DepartmentMembership < ApplicationRecord
	belongs_to :department
	belongs_to :user

	enum :role, { guest: 0, member: 1, leader: 2, hidden: 3, deleted: 99 }

	scope :workable, -> { where.not(role: [0, 99]) }

	# validates_uniqueness_of :user_id, :scope => [:department_id]
end