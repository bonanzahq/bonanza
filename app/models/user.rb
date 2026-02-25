class User < ApplicationRecord
  include GdprAuditable

  has_many :department_memberships, :dependent => :destroy
  has_many :departments, -> { distinct }, :through => :department_memberships

  belongs_to :current_department, class_name: 'Department', optional: true

  accepts_nested_attributes_for :department_memberships

  validates :department_memberships, presence: true
  validates_presence_of :password_confirmation, :if => :password
  validates :password, :password_strength => true, :if => :password

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :recoverable, :rememberable, :validatable, :confirmable

  before_validation :ensure_current_department
  # before_create :create_memberships_in_all_departments

  validates :firstname, :lastname, presence: true
  # validates :email, :email => {:ban_disposable_email => true, :mx_with_fallback => true, :message => "ist ungültig."}
  validates :email, uniqueness: true
  # validates_inclusion_of :department_id, :in => :allowed_department_ids, unless: "User.current_user.nil?"
  # validates_inclusion_of :role, :in => :allowed_roles, unless: -> { User.current_user.nil? }

  before_destroy :prevent_unsafe_deletion
  validate :protect_last_admin_flag

  attr_accessor :temp_role

  def fullname
    firstname + " " + lastname
  end

  def current_role
    department_memberships.find_by(department: current_department).role
  end

  def current_role=(role)
    membership = department_memberships.find_or_initialize_by(department: current_department)
    membership.role = role
    membership.save! if membership.persisted?
  end

  def is_guest_everywhere?
    department_memberships.where.not(role: ["guest", "deleted"]).empty?
  end

  def guest?
    current_role == 'guest'
  end

  def member?
    current_role == 'member'
  end

  def leader?
    current_role == 'leader'
  end

  def admin?
    admin
  end

  def role_in(department)
    department_memberships.where(department: department).first.role
  end

  def anonymize!(performed_by: nil)
    transaction do
      department_memberships.update_all(role: :deleted)
      update_columns(
        firstname: "Ehemaliger",
        lastname: "Mitarbeiter",
        email: "former-#{id}-#{SecureRandom.hex(4)}@anonymized.local",
        encrypted_password: ""
      )
      log_gdpr_event("anonymize", performed_by: performed_by)
    end
  end

  def anonymized?
    email&.end_with?("@anonymized.local")
  end

  def self.current_user
    Thread.current[:user]
  end
  
  def self.current_user=(user)
    Thread.current[:user] = user
  end

  private
    def ensure_current_department
      if current_department.nil?
          self.current_department = departments.first
      end
    end

    # def create_memberships_in_all_departments
    #   self.departments |= Department.all
    # end

    def allowed_department_ids
      Department.pluck(:id) 
    end
    
    # def allowed_roles
    #   User.roles.keys.map{ |k|
    #     if User.roles[k] <= User.current_user[:role] || User.current_user.admin?
    #       k
    #     else
    #       nil
    #     end
    #   }.compact
    # end

    def prevent_unsafe_deletion
      if User.current_user == self
        errors.add(:base, "Das eigene Konto kann nicht gelöscht werden.")
        throw(:abort)
      end

      if admin? && User.where(admin: true).where.not(id: id).empty?
        errors.add(:base, "Der letzte Admin kann nicht gelöscht werden.")
        throw(:abort)
      end
    end

    def protect_last_admin_flag
      if admin_changed? && !admin
        if User.where(admin: true).where.not(id: id).empty?
          errors.add(:admin, "kann nicht entfernt werden, da kein anderer Admin existiert.")
        end
      end
    end

end
