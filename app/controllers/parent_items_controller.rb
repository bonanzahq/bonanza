class ParentItemsController < ApplicationController
  before_action :set_parent_item, only: %i[ show edit update destroy destroy_file ]

  before_action :authenticate_user!
  before_action :set_department

  authorize_resource

  # GET /parent_items or /parent_items.json
  def index
    @parent_items = ParentItem.all
  end

  # GET /parent_items/1 or /parent_items/1.json
  def show

    start_year = @parent_item.created_at.year
    current_year = Date.today.year

    @weekly_activity = Hash.new

    (start_year..current_year).each do |year|
      @weekly_activity[year] = get_weekly_lending_activity(Date.commercial(year, 1), Date.parse("31/12/#{year}"), @parent_item.id)
    end

    @weekly_activity = @weekly_activity.to_a.reverse.to_h

    @max_week = 0

    sum = 0

    @weekly_activity.each do |year, results|
      results.each_with_index do |week, index|
          @max_week = week["count"] if @max_week < week["count"]
      end
    end

  end

  # GET /parent_items/new
  def new
    @parent_item = ParentItem.new
    @parent_item.items.build
    @parent_item.accessories.build
  end

  # GET /parent_items/1/edit
  def edit
    @parent_item.accessories.build if @parent_item.accessories.size == 0
  end

  # POST /parent_items or /parent_items.json
  def create
    @parent_item = @department.parent_items.new(parent_item_params)

    @parent_item.attach_files

    respond_to do |format|
      if @parent_item.save
        @department.tag(@parent_item, :with => params[:parent_item][:all_tags_list], :on => :tags)
        format.html { redirect_to lending_path, notice: "Parent item was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /parent_items/1 or /parent_items/1.json
  def update
    department_changed = false
    requested_department_id = params.dig(:parent_item, :department_id).presence

    if requested_department_id && requested_department_id.to_i != @parent_item.department_id
      authorize! :move, @parent_item

      target_id = requested_department_id.to_i
      target_department = Department.joins(:department_memberships)
                            .where(department_memberships: { user: current_user })
                            .where.not(department_memberships: { role: :deleted })
                            .find_by(id: target_id)

      unless target_department
        return redirect_back fallback_location: edit_parent_item_path(@parent_item), alert: "Ziel-Werkstatt ist ungültig."
      end

      if @parent_item.has_lent_items?
        return redirect_back fallback_location: edit_parent_item_path(@parent_item), alert: "Artikel mit aktiven Ausleihen können nicht verschoben werden."
      end

      @parent_item.department = target_department
      department_changed = true
    end

    respond_to do |format|
      if @parent_item.update(parent_item_params)
        tagging_department = department_changed ? @parent_item.department : @department
        tagging_department.tag(@parent_item, :with => params[:parent_item][:all_tags_list], :on => :tags)

        @parent_item.attach_files

        @parent_item.reload

        begin
          @parent_item.reindex
        rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error
        end

        if department_changed
          format.html { redirect_to borrowers_path, notice: "Artikel wurde aktualisiert und verschoben." }
        else
          format.html { redirect_to parent_item_path, notice: "Parent item was successfully updated." }
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy_file
    @file = @parent_item.files.find(params[:file_id])
    @file.purge

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@file) }
    end
  end

  # DELETE /parent_items/1 or /parent_items/1.json
  def destroy
    @parent_item.destroy

    respond_to do |format|
      format.html { redirect_to borrowers_path, notice: "Parent item was successfully destroyed." }
    end
  end

  private

    def get_weekly_lending_activity(date_begin, date_end, parent_item_id)
      sql = ActiveRecord::Base.sanitize_sql_array([<<-SQL, date_begin, date_end, parent_item_id])
        SELECT week, count(custom_lendings)
        FROM (
            SELECT week
            FROM generate_series(?::date, ?::date, '1 week')
            AS week
          ) weeks
          LEFT JOIN ( 
            SELECT lent_at, "parent_items"."created_at" AS "parent_items_created_at", "lendings"."returned_at", "line_items"."returned_at" AS "line_items_returned_at" FROM lendings
            INNER JOIN "line_items" ON "line_items"."lending_id" = "lendings"."id"
            INNER JOIN "items" ON "items"."id" = "line_items"."item_id"
            INNER JOIN "parent_items" ON "parent_items"."id" = "items"."parent_item_id" 
            WHERE "parent_items"."id" = ?
          ) custom_lendings

          ON ( week <= lent_at::DATE AND lent_at::DATE < week + INTERVAL '1 week') OR
          ( lent_at::DATE < week AND week + INTERVAL '1 week' < COALESCE(returned_at, now())::DATE ) OR
          ( week <= COALESCE(returned_at, now())::DATE AND COALESCE(returned_at, now())::DATE < week + INTERVAL '1 week' )

          GROUP BY week
          ORDER BY week
        SQL
      ActiveRecord::Base.connection.execute(sql)
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_parent_item
      @parent_item = ParentItem.find(params[:id])
    end

    def set_department
      @department = current_user.current_department
    end

    # Only allow a list of trusted parameters through.
    def parent_item_params
      params.require(:parent_item).permit(:name, :description, :note, :price, new_files: [], items_attributes: [:id, :uid, :quantity, :condition, :storage_location, :note, :_destroy], :accessories_attributes => [:id, :name, :_destroy], links_attributes: [:id, :url, :title, :_destroy])
    end
end
