class BorrowersController < ApplicationController
  before_action :set_borrower, only: %i[ show edit update destroy add_conduct remove_conduct export_data request_deletion ]

  before_action :authenticate_user!, except: [:confirm_email, :self_register, :self_create, :email_confirmation_pending]
  # skip_authorize_resource only: [:confirm_email, :self_create]

  # GET /borrowers or /borrowers.json
  def index
    authorize! :read, Borrower
    @borrowers = Borrower.order(:firstname, :lastname).limit(10)

    page_num = params[:page].nil? ? 1 : params[:page]

    @borrowers = Borrower.search_people(params[:q], params[:lending_status], params[:conducts], params[:borrower_type], page = page_num)

    respond_to do |format|
      format.turbo_stream if params[:page]
      format.html
    end

  end

  # GET /borrowers/1 or /borrowers/1.json
  def show
    authorize! :read, Borrower
    @conduct = Conduct.new

    returned_line_items = @borrower.line_items.where.not(returned_at: nil).includes(:accessories, :item_histories)
    lent_line_item_lendings = @borrower.lendings.where.not(lent_at: nil).includes(line_items: [:item_histories, :accessories])
    @elements = (returned_line_items + lent_line_item_lendings).group_by do |element|
      if element.class.name.demodulize == "Lending"
        element.lent_at.to_date
      elsif element.class.name.demodulize == "LineItem"
        element.returned_at.to_date
      end
    end.sort.reverse
  end

  # GET /borrowers/new
  def new
    authorize! :create, Borrower
    @borrower = Borrower.new
  end

  # GET /borrowers/1/edit
  def edit
    authorize! :update, Borrower
  end

  def add_conduct
    authorize! :update, Borrower
    @conduct = Conduct.new(conduct_params)
    @conduct.borrower = @borrower
    @conduct.user = current_user
    @conduct.department = current_user.current_department
    @conduct.kind = "banned"

    respond_to do |format|
      if @conduct.save
        BorrowerMailer.with(borrower: @borrower)
          .ban_notification_email(@conduct)
          .deliver_later(queue: :critical)
        format.html { redirect_to @borrower, notice: "Die ausleihende Person wurde gesperrt." }
      else
        format.html { redirect_to @borrower, alert: "Die ausleihende Person konnte nicht gesperrt werden. #{@conduct.errors.messages.values.join(" ")}" }
      end
    end
  end

  def remove_conduct
    authorize! :update, Borrower
    respond_to do |format|
      begin
        @conduct = @borrower.conducts.find(params[:conducts_id])
        if @conduct.department == current_user.current_department
          BorrowerMailer.with(borrower: @borrower)
            .ban_lifted_notification_email(
              department_name: @conduct.department.name,
              department_genderize_in_the: @conduct.department.genderize("in_the"),
              department_genderize_of_the: @conduct.department.genderize("of_the"),
              user_fullname: current_user.fullname,
              user_email: current_user.email
            )
            .deliver_later(queue: :default)
          @conduct.lift!(current_user)
          format.html { redirect_to @borrower, notice: 'Sperre/Verwarnung wurde aufgehoben.' }
        else
          format.html { redirect_to @borrower, alert: 'Sperre/Verwarnung konnte nicht entfernt werden.' }
        end
      rescue ActiveRecord::RecordNotFound
        format.html { redirect_to @borrower, alert: 'Sperre/Verwarnung konnte nicht entfernt werden.' }
      end
    end
  end

  # GET /accept_tos/:token
  def confirm_email
    borrower = Borrower.find_by(:email_token => params[:token]) if params[:token].present?

    respond_to do |format|      
      if borrower
        borrower.email_token = nil
        borrower.save(context: :self)
        format.html { render 'confirmation_success' }
      else
        format.html { redirect_to root_url, alert: "Fehler beim Bestätigen der Registrierung." }
      end
    end
  end

  def send_confirm_email_email
    @borrower = Borrower.find_by(:email_token => params[:token]) if params[:token].present?

    respond_to do |format|
      if @borrower.nil?
        format.html { redirect_to borrowers_url, alert: "Fehler mit Token" }
      elsif @borrower.send_confirmation_pending_email == false
        format.html { redirect_to borrowers_url, alert: "Die E-Mail zum Bestätigen der Ausleihbedingungen konnte nicht versandt werden." }
      else
        format.turbo_stream { flash.now[:notice] = "Eine E-Mail zum Bestätigen deiner Registrierung wurde versandt." }
        format.html { redirect_to @borrower, notice: "Eine E-Mail zum Bestätigen deiner Registrierung wurde versandt." }
      end
    end
  end

  def self_register
    @borrower = Borrower.new
    @tos = LegalText.current_tos
  end

  def email_confirmation_pending
  end

  # POST /borrowers
  def create
    authorize! :create, Borrower
    @borrower = Borrower.new(borrower_params)

    respond_to do |format|
      if @borrower.save
        BorrowerMailer.with(borrower: @borrower)
          .account_created_email(department_name: current_user.current_department.name)
          .deliver_later
        format.html { redirect_to borrower_url(@borrower), notice: "Die ausleihende Person wurde angelegt." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def self_create
    @borrower = Borrower.new(self_borrower_params)

    respond_to do |format|
      if @borrower.save(context: :self)
        if @borrower.send_confirmation_pending_email == false
          format.html { redirect_to borrower_email_pending_url(), alert: @borrower.errors.full_messages.join(", ") }
        else
          format.html { redirect_to borrower_email_pending_url() }
        end
      else
        @tos = LegalText.current_tos
        format.html { render :self_register, status: :unprocessable_entity, alert: "Bei der Registrierung ist etwas schiefgelaufen." }
      end
    end
  end

  # PATCH/PUT /borrowers/1
  def update
    authorize! :update, Borrower
    respond_to do |format|
      if @borrower.update(borrower_params)
        format.html { redirect_to borrower_url(@borrower), notice: "Daten zur ausleihenden Person wurden aktualisiert." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /borrowers/1 or /borrowers/1.json
  def destroy
    authorize! :destroy, Borrower
    @borrower.destroy

    respond_to do |format|
      format.html { redirect_to borrowers_url, notice: "Die ausleihende Person wurde gelöscht." }
    end
  end

  def export_data
    authorize! :read, Borrower
    @borrower.log_gdpr_event("export", performed_by: current_user)
    send_data(
      @borrower.export_personal_data.to_json,
      filename: "borrower-data-#{@borrower.id}-#{Date.current}.json",
      type: "application/json"
    )
  end

  def request_deletion
    authorize! :destroy, Borrower
    result = @borrower.request_deletion!(performed_by: current_user)

    case result
    when :anonymized
      redirect_to borrowers_url, notice: "Die personenbezogenen Daten wurden anonymisiert."
    when :deleted
      redirect_to borrowers_url, notice: "Der Datensatz wurde vollständig gelöscht."
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to @borrower, alert: "Löschung nicht möglich: #{e.message}"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_borrower
      @borrower = Borrower.find(params[:id])
    end

    def conduct_params
      params.require(:conduct).permit(:reason, :duration, :permanent)
    end

    # Only allow a list of trusted parameters through.
    def borrower_params
      params.require(:borrower).permit(:firstname, :lastname, :email, :phone, :borrower_type, :id_checked, :insurance_checked, :student_id, :tos_token, :tos_accepted, :tos_accepted_at)
    end

    def self_borrower_params
      params.require(:borrower).permit(:firstname, :lastname, :email, :phone, :borrower_type, :student_id, :tos_accepted)
    end
end
