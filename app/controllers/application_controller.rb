class ApplicationController < ActionController::Base
  include ErrorHandling

  before_action :configure_permitted_parameters, if: :devise_controller?
  # check_authorization unless: :devise_controller?

  rescue_from CanCan::AccessDenied do |exception|
    store_location_for(:user, request.fullpath)
    if current_user.nil?
      redirect_to new_user_session_path, :alert => "Du musst angemeldet sein, um fortfahren zu können."
    elsif current_user.member? || current_user.leader? || current_user.admin?
      redirect_to root_path, :alert => "Zugang verweigert. Du hast leider nicht die notwendige Berechtigung."
    else
      redirect_to public_home_page_path, :alert => "Zugang verweigert. Dein Konto muss erst noch freigeschaltet werden."
    end
  end

  before_action :set_current_user
  after_action :unset_current_user

	def after_sign_in_path_for(resource)
    stored_location_for(:user) || lending_path
  end

  def after_sign_out_path_for(resource)
    root_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [:temp_role])
    devise_parameter_sanitizer.permit(:accept_invitation, keys: [:firstname, :lastname, :email])
    devise_parameter_sanitizer.permit(:sign_up) { |u| u.permit({ departments: [] }, :firstname, :lastname, :email, :password, :password_confirmation, :current_department) }
  end

  def authenticate_inviter!
    return current_user if !current_user.nil? && (current_user.leader? || current_user.admin?)
    redirect_to root_url, :alert => "Zugang verweigert. Du hast leider nicht die notwendige Berechtigung."
  end

  private

    def set_current_user
      User.current_user = current_user unless current_user.nil?
    end

    def unset_current_user
      User.current_user = nil
    end

    def append_info_to_payload(payload)
      super
      payload[:request_id] = request.request_id
      payload[:user_id] = current_user&.id
    end

    def current_lending
      Lending.find(session[:lending_id])
      rescue ActiveRecord::RecordNotFound
        lending = Lending.create(user_id: current_user.id, department_id: current_user.current_department.id)
        session[:lending_id] = lending.id
        lending
    end

end
