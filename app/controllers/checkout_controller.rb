class CheckoutController < ApplicationController
  before_action :authenticate_user!
  
  before_action :set_department
  before_action :set_lending

  authorize_resource :class => false

  before_action :ensure_line_items
  before_action :ensure_department_is_staffed
  before_action :ensure_lending_not_completed
  before_action :ensure_checkout_flow_started, except: [:select_borrower]
  before_action :ensure_valid_state, except: [:select_borrower]
  before_action :ensure_state_access_allowed, except: [:select_borrower]

  def index
    redirect_to lending_path unless @lending.has_line_items?

    if params[:state] == "borrower"
      @borrowers = Borrower.search_people(params[:b], nil, nil, true, 1)
    end
  end

  def select_borrower
    unless @lending.state.in?(%w[borrower confirmation])
      redirect_to checkout_state_path(@lending.state) and return
    end

    if params[:lending] && params[:lending][:borrower_id]
      attrs = { borrower_id: params[:lending][:borrower_id] }
      attrs[:state] = :borrower if @lending.confirmation?
      unless @lending.update(attrs)
        redirect_to checkout_state_path(@lending.state), alert: @lending.errors.full_messages.join(", ") and return
      end
    end
    redirect_to checkout_state_path("borrower")
  end

  def update
    logger.debug("return early??")
    redirect_to checkout_state_path(@lending.state), alert: "Fehler! Du müsst eine ausleihende Person angeben." and return unless params[:lending]

    logger.debug("return early NOOOO")

    if @lending.update_from_checkout_params(checkout_params, current_user, params[:lending][:accessories])

      if @lending.completed?
        session[:lending_id] = nil

        flash[:printable_agreement] = lending_agreement_path(@lending.id, @lending.token)
        flash[:notice] = "Die Ausleihe wurde erfolgreich angelegt!"

        redirect_to completion_route
      else

        logger.debug("lending not completed. redirecting to last page")

        redirect_to checkout_state_path(@lending.state)
      end
    else
      @borrowers = [@lending.borrower] unless @lending.borrower.nil?

      flash.now[:alert] = "Die Ausleihe konnte nicht fertiggestellt werden. #{@lending.errors.messages.values.join(", ")}"
      render :index
      
      # TODO: redirect to appropriate state and show reason
    end
  end

  private
    def set_department
      @department = current_user.current_department
    end

    def set_lending
      @lending = current_lending
    end

    def ensure_line_items
      unless @lending.has_line_items?
        @lending.cart!
        redirect_to lending_path
      end
    end

    def ensure_checkout_flow_started
      if @lending.cart? || !params[:state] || params[:state] == 'cart'
        @lending.borrower!
        redirect_to checkout_state_path('borrower')
      end
    end

    def ensure_valid_state
      if (params[:state] && !@lending.has_checkout_step?(params[:state]))
        redirect_to lending_path
      end
    end

    def ensure_state_access_allowed
      redirect_to checkout_state_path(@lending.state), alert: 'Nicht so schnell. Du darfst keine Schritte überspringen.' unless @lending.can_go_to_state?(params[:state])
      @lending.state = params[:state] # TODO: save?
    end

    def ensure_lending_not_completed
      redirect_to lending_path if @lending.completed?
    end

    def ensure_department_is_staffed
      redirect_to lending_path, alert: "Werkstatt muss besetzt sein, um Artikel zu verleihen." unless current_user.current_department.staffed
    end

    def completion_route
      lending_path
    end

    def checkout_params
      return false unless params[:lending]
      
      cleaned_params = params

      if params[:lending] && params[:lending][:borrower_attributes]
        if params[:lending][:borrower_id]
          cleaned_params[:lending][:borrower_attributes].each do |k, v|
            cleaned_params[:lending][:borrower_attributes] = v if v["id"] == params[:lending][:borrower_id]
          end
        else
          cleaned_params[:lending].delete(:borrower_attributes)
        end
      end

      return false if params[:lending].empty?
      
      cleaned_params.require(:lending).permit(:borrower_id, :note, :duration, :line_items_attributes => [:id, :quantity, :accessory_ids => []], :borrower_attributes => [:id, :id_checked, :insurance_checked])
    end

end
