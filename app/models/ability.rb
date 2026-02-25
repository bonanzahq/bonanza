# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities

    user ||= User.new # guest user (not logged in)

    can :read, Department

    return unless user.present?

    return unless user.current_department

    if user.admin?
      can :manage, :all
      
    elsif user.leader?
      can :update, User, :id => user.id
      can :update, User do |u| 
        u.current_department.id == user.current_department.id && !u.admin?
      end
      can :send_password_reset, User do |u|
        u.current_department.id == user.current_department.id && !u.admin? && u.id != user.id
      end
      can :manage, Borrower
      can :update, Department, :id => user.current_department.id
      can :unstaff, Department, :id => user.current_department.id
      can :staff, Department, :id => user.current_department.id
      can :manage, ParentItem, :department_id => user.current_department.id
      can :manage, Lending, :department_id => user.current_department.id
      can [:edit, :update], :checkout
      can :take_back, LineItem, :item => { :parent_item => { :department => user.current_department } }
      can :read, :all
    elsif user.member?
      can :update, Department, :id => user.current_department.id
      can :unstaff, Department, :id => user.current_department.id
      can :staff, Department, :id => user.current_department.id
      can :update, User, :id => user.id
      can :read, User
      can :manage, Borrower
      can :manage, ParentItem, :department_id => user.current_department.id
      can :manage, Lending, :department_id => user.current_department.id
      can [:edit, :update], :checkout
      can :take_back, LineItem, :item => { :parent_item => { :department => user.current_department } }
      can :read, :all
    elsif user.guest?
      can :read, Department
      can :update, User, :id => user.id
      can :read, Borrower
      can :read, Lending
      can :read, ParentItem
    end
  end
end
