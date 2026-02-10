class UsersController < ApplicationController
  load_and_authorize_resource
  skip_load_resource :only => :index

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
      if @user.update(user_params)
        
        if @user.current_department_previously_changed?
          current_lending.destroy
        end

        if @user == current_user
          bypass_sign_in @user
        end

        format.html { redirect_to verwaltung_verleihende_path, notice: "Verleihende Person wurde erfolgreich aktualisiert." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, notice: "User was successfully destroyed." }
    end
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
      if params[:user][:password].blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end
      # params.require(:user).permit(:email, :password, :password_confirmation, :remember_me)
      params.require(:user).permit(:firstname, :lastname, :email, :admin, :password, :password_confirmation, :current_department_id, department_memberships_attributes: [:id, :role, :department_id])
    end
end
