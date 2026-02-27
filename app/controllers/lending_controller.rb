class LendingController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_department, except: [:show]

  def index
    authorize! :read, Lending
    page_num = params[:page].nil? ? 1 : params[:page]

    @dept_id = params[:dept].nil? ? current_user.current_department.id : params[:dept]

    logger.debug("Searching for ...")
    @parent_items = ParentItem.search_items(params[:q], @dept_id, params[:status], params[:condition], page = page_num)

    logger.debug("Found items: #{@parent_items.count}")

    @lending = current_lending
    @previous_lendings = @department.lendings.where(returned_at: nil).where.not({lent_at: nil}).last(5).reverse

    @lendings_count = @department.lendings.where(returned_at: nil).where.not(lent_at: nil).count

    respond_to do |format|
      format.turbo_stream if params[:page]
      format.html
    end
  end

  def show
    @lending = Lending.find(params[:id])

    if @lending.token != params[:token]
      redirect_to lending_path, alert: "Diese Ausleihe existiert nicht." and return # TODO: redirect to generic 404 Page!
    end

    if user_signed_in?
      render 'show'
    else
      render 'show_public'
    end
  end

  def populate
    @lending = current_lending
    authorize! :manage, @lending

    @line_item = @lending.populate(params[:item_id], params[:quantity])

    respond_to do |format|
      if @line_item && @line_item.save
        format.turbo_stream { flash.now[:notice] = "#{@line_item.item.parent_item.name} erfolgreich in den Ausleihkorb gelegt." }
        format.html { redirect_to lending_path(:page => params[:page])}
      else
        format.turbo_stream { flash.now[:error] = "#{@lending.errors.messages.values.join(", ")}" }
        format.html { redirect_to lending_path, alert: @lending.errors.messages.values.join(", ") }
      end
    end
  end

  def show_printable_agreement
    @lending = Lending.find(params[:id])
    authorize! :read, @lending
    @borrower = @lending.borrower

    if @lending.token != params[:token]
      redirect_to lending_path, alert: "Diese Ausleihe existiert nicht." and return
    end

    render 'printable_agreement', layout: 'print'
  end

  def remove_line_item
    @lending = current_lending
    authorize! :update, @lending

    @line_item = @lending.line_items.find(params[:line_item_id]).destroy

    # find_by(item_id: item.id)

    respond_to do |format|
      if @line_item

        if @lending.has_line_items?
          format.turbo_stream { flash.now[:notice] = "#{@line_item.item.parent_item.name} aus dem Ausleihkorb entfernt." }
        else
          @lending = current_lending
          session[:lending_id] = nil
          
          format.turbo_stream { redirect_to lending_path }
          # format.html { redirect_to lending_path }
        end
      else 
        format.turbo_stream { flash.now[:error] = "Konnte #{@line_item.item.parent_item.name} nicht aus dem Ausleihkorb entfernen." }
        format.html { redirect_to lending_path, alert: "Konnte #{@line_item.item.parent_item.name} nicht aus dem Ausleihkorb entfernen." }
      end
    end
  end

  def update
    @lending = current_lending
    authorize! :update, @lending

    previous_items = @lending.items.clone.to_a

    respond_to do |format|
      if @lending.update_cart(lending_params)
        
        @lending.items.reload
        @removed_items = previous_items - @lending.items.to_a

        flash[:notice] = "Ausleihe erfolgreich aktualisiert."
        format.turbo_stream { flash.now[:notice] = "Ausleihe erfolgreich aktualisiert" }
        format.html { redirect_to lending_path(:page => params[:page])}
      else
        format.html { render :edit }
      end
    end
  end

  def empty
    @lending = current_lending
    authorize! :manage, @lending
    session[:lending_id] = nil
    
    @lending.destroy unless @lending.completed?

    redirect_to lending_path, status: :see_other
  end

  def destroy
    @lending = @department.lendings.find(params[:id])
    authorize! :destroy, @lending

    if @lending.user.current_department == current_user.current_department && @lending.eradicate
     flash[:notice] = "Ausleihe wurde erfolgreich gelöscht. Status und Anzahl aller Artikel wurde zurückgesetzt."
    else
      flash[:alert] = "Ausleihe konnte nicht gelöscht werden."
    end

    redirect_to lending_path, status: :see_other
  end

  def change_duration
    @lending = Lending.find(params[:id])
    old_duration = @lending.duration
    @lending.duration = lending_params[:duration].to_i if lending_params[:duration].present?
    @lending.notification_counter = 0
    authorize! :change_duration, @lending

    respond_to do |format|
      if @lending.save
        LendingMailer.duration_change_notification_email(@lending, old_duration).deliver_later(queue: :default)
        flash[:notice] = "Ausleihfrist erfolgreich geändert."
        format.html { redirect_to token_lending_path(@lending, token: @lending.token)}
      else
        format.html { redirect_to token_lending_path(@lending, token: @lending.token), alert: @lending.errors.full_messages.join(", ") }
      end
    end
  end

  private

    def set_department
      @department = current_user.current_department
    end

    def lending_params
      params.require(:lending).permit(:note, :state, :duration, :line_items_attributes => [:id, :quantity, :_destroy])
    end

end
