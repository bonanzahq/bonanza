class ReturnsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department

  def index
    authorize! :read, Lending

    # @todays_returns = Lending.where(returned_at: nil).where.not(lent_at: nil).where(department: @department).where("DATE(lent_at + duration * interval '1 day') = CURRENT_DATE").order("DATE(lent_at + duration * interval '1 day') ASC")

    pending_returns = Lending.where(returned_at: nil).where.not(lent_at: nil).where(department: @department).where("DATE(lent_at + duration * interval '1 day') >= CURRENT_DATE").order(Arel.sql "DATE(lent_at + duration * interval '1 day') ASC")
    @grouped_pending_returns = pending_returns.group_by{ |lending| lending.lent_at.to_date + lending.duration }
    
    @overdue_returns = Lending.where(returned_at: nil).where.not(lent_at: nil).where(department: @department).where("DATE(lent_at + duration * interval '1 day') < CURRENT_DATE").order(Arel.sql "DATE(lent_at + duration * interval '1 day') ASC")

    @returns_count = pending_returns.count + @overdue_returns.count
    @pending_returns_count = pending_returns.count
    @overdue_returns_count = @overdue_returns.count

  end

  def take_back
    if params[:line_item_id].present?
      @line_item = LineItem.find(params[:line_item_id])
    end

    authorize! :take_back, @line_item

    respond_to do |format|
      if @line_item.take_back(params)
        @line_item.lending.all_items_returned?

        index

        # flash[:notice] = "#{@line_item.item.parent_item.name} zurückgebucht."
        format.html { redirect_to return_path, notice: "zurückgegeben." }
        format.turbo_stream { flash.now[:notice] = "Artikel zurückgenommen!" }
      else

        if @line_item.errors.any?
          flash[:alert] = @line_item.errors.full_messages.join(" ")
        else
          flash[:alert] = "Konnte Artikel nicht zurückgenommen werden."
        end

        format.html { redirect_to return_path }
      end
    end
  end

  private

    def set_department
      @department = current_user.current_department
    end
end
