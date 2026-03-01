class UsersController < ApplicationController
  load_and_authorize_resource
  skip_load_resource :only => :index
  skip_load_and_authorize_resource :only => :switch_department

  before_action :authenticate_user!

  # GET /users
  def index
    @departments = Department.includes(:department_memberships, :users).all.sort_by(&:name)
    @admins = User.where(admin: true)
  end

  # GET /users/1
  def show
  end

  # GET /users/new
  def new
    @user = User.new

    Department.all.each do |dept|
      @user.department_memberships.build(department: dept)
    end
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to users_url, notice: "Verleihende Person wurde angelegt." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1
  def update
    respond_to do |format|
      if @user == current_user && params.dig(:user, :password).present?
        current_password = params[:user].delete(:current_password)
        unless @user.valid_password?(current_password.to_s)
          @user.errors.add(:current_password, :invalid)
          format.html { render :edit, status: :unprocessable_entity }
          next
        end
      end

      if @user.update(user_params)
        
        if @user.current_department_previously_changed? && session[:lending_id]
          Lending.find_by(id: session[:lending_id])&.destroy
          session.delete(:lending_id)
        end

        if @user == current_user
          bypass_sign_in @user
          if @user.saved_change_to_encrypted_password?
            session.delete(:weak_password)
          end
        end

        notice = if @user.pending_reconfirmation?
                   "Daten aktualisiert. Bitte bestätige die neue E-Mail-Adresse über den Link in der Bestätigungs-E-Mail."
                 else
                   "Verleihende Person wurde erfolgreich aktualisiert."
                 end

        format.html { redirect_to verwaltung_verleihende_path, notice: notice }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  def destroy
    if @user.destroy
      respond_to do |format|
        format.html { redirect_to users_url, notice: "Benutzer wurde gelöscht." }
      end
    else
      respond_to do |format|
        format.html { redirect_to users_url, alert: @user.errors.full_messages.to_sentence }
      end
    end
  end

  def switch_department
    department_id = params[:department_id].to_i
    unless current_user.switchable_departments.exists?(id: department_id)
      redirect_back fallback_location: root_path, alert: "Ungültige Werkstatt."
      return
    end

    current_user.update!(current_department_id: department_id)
    if session[:lending_id]
      Lending.find_by(id: session[:lending_id])&.destroy
      session.delete(:lending_id)
    end
    redirect_to root_path, notice: "Werkstatt gewechselt."
  end

  def send_password_reset
    @user.send_reset_password_instructions
    redirect_to edit_user_path(@user), notice: "Passwort-Reset E-Mail wurde gesendet."
  end

  def self.current_user
    Thread.current[:user]
  end
  
  def self.current_user=(user)
    Thread.current[:user] = user
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params[:user]&.delete(:current_password)
      permitted = [:firstname, :lastname, :email, :current_department_id,
                   department_memberships_attributes: [:id, :role, :department_id]]
      permitted.unshift(:admin) if current_user.admin?

      if @user == current_user
        if params[:user] && params[:user][:password].present?
          permitted << :password << :password_confirmation
        else
          params[:user]&.delete(:password)
          params[:user]&.delete(:password_confirmation)
        end
      else
        params[:user]&.delete(:password)
        params[:user]&.delete(:password_confirmation)
      end

      # If user params exist after deletion, permit them. Otherwise return empty params.
      if params[:user].present?
        params.require(:user).permit(*permitted)
      else
        ActionController::Parameters.new.permit!
      end
    end
end
