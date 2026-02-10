class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[ show edit update destroy staff unstaff ]
  before_action :authenticate_user!, except: [:index]

  authorize_resource

  # GET /departments or /departments.json
  def index
    @departments = Department.all.order(:name).includes(:users)
  end

  # GET /departments/1 or /departments/1.json
  def show
  end

  # GET /departments/new
  def new
    @department = Department.new
  end

  # GET /departments/1/edit
  def edit
  end

  # POST /departments
  def create
    @department = Department.new(department_params)

    respond_to do |format|
      if @department.save
        format.html { redirect_to departments_url, notice: "#{@department.name} was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /departments/1
  def update
    respond_to do |format|
      if @department.update(department_params)
        format.html { redirect_to borrowers_path, notice: "#{@department.name} was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /departments/1
  def destroy
    @department.destroy

    respond_to do |format|
      format.html { redirect_to departments_url, notice: "Department was successfully destroyed." }
    end
  end

  def unstaff
    authorize! :unstaff, @department
    @department.staffed = false

    respond_to do |format|
      if @department.save
        format.html { redirect_to borrowers_path, notice: '#{@department} ist jetzt geschlossen. Rückgaben sind pausiert.' }
      else
        format.html { redirect_to borrowers_path, error: '#{@department} konnte nicht geschlossen werden.' }
      end
      
    end
  end

  def staff
    authorize! :staff, @department
    @department.staffed = true

    respond_to do |format|
      if @department.save
        format.html { redirect_to borrowers_path, notice: '#{@department} ist wieder besetzt.' }
      else
        format.html { redirect_to borrowers_path, error: '#{@department} konnte nicht auf besetzt gesetzt werden.' }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_department
      @department = Department.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def department_params
      params.require(:department).permit(:name, :genus, :room, :note, :time, :default_lending_duration, :staffed, :hidden)
    end
end
