class AutocompleteController < ApplicationController
  before_action :authenticate_user!
  skip_authorization_check

  def items
    if params[:dept_id].present?      

      render json: ParentItem.where(department: params[:dept_id]).pluck(:name)
        
    else
      render json: current_user.current_department.parent_items.pluck(:name)
    end
  end

  def borrowers
    render json: Borrower.where("borrower_type <> ?", Borrower.borrower_types[:deleted]).map(&:fullname)
  end
end
