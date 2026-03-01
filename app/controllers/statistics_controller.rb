class StatisticsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    authorize! :read, :statistics
    start_year = current_user.current_department.created_at.year
    current_year = Date.today.year

    @weekly_activity = Hash.new

    (start_year..current_year).each do |year|
      @weekly_activity[year] = get_weekly_lending_activity(Date.commercial(year, 1), Date.parse("31/12/#{year}"), current_user.current_department.id)


      # @weekly_activity[year].each do |entry|
      #   logger.debug(entry.inspect)
      # end
      
    end

    @weekly_activity = @weekly_activity.to_a.reverse.to_h

    @max_week = 0

    @weekly_activity.each do |year, results|
      results.each_with_index do |week, index|
          @max_week = week["count"] if @max_week < week["count"]
      end
    end

    @top_borrowers = Lending.joins(:borrower).where(department_id: current_user.current_department.id).where.not(lent_at: nil).group(:borrower).order('count_all DESC').limit(10).count
    @top_parent_items = Item.joins(:lendings, :parent_item).where.not(lendings:{ lent_at: nil, department_id: current_user.current_department.id}).group(:parent_item).order('count_all DESC').limit(10).count

  end

  private 

  def get_weekly_lending_activity(date_begin, date_end, department_id)
    return ActiveRecord::Base.connection.execute <<-SQL
      SELECT week, count(lendings) FROM (
        SELECT week
        FROM generate_series('#{date_begin}'::date, '#{date_end}'::date, '1 week')
        AS week
      ) weeks
      LEFT JOIN lendings 
      
      ON department_id = '#{department_id}' AND
        lent_at IS NOT NULL 
      AND (
        ( week <= lent_at::DATE AND lent_at::DATE < week + INTERVAL '1 week') OR
        ( lent_at::DATE < week AND week + INTERVAL '1 week' < COALESCE(returned_at, now())::DATE ) OR
        ( week <= COALESCE(returned_at, now())::DATE AND COALESCE(returned_at, now())::DATE < week + INTERVAL '1 week' )
      )

      GROUP BY week
      ORDER BY week
    SQL
  end


  # def get_weekly_lending_activity(date_begin, date_end, parent_item_id)
  #   return ActiveRecord::Base.connection.execute <<-SQL
  #     SELECT week, count(custom_lendings)
  #     FROM (
  #         SELECT week
  #         FROM generate_series('#{date_begin}'::date, '#{date_end}'::date, '1 week')
  #         AS week
  #       ) weeks
  #       LEFT JOIN ( 
  #         SELECT lent_at, "parent_items"."created_at" AS "parent_items_created_at", "lendings"."returned_at", "line_items"."returned_at" AS "line_items_returned_at" FROM lendings
  #         INNER JOIN "line_items" ON "line_items"."lending_id" = "lendings"."id"
  #         INNER JOIN "items" ON "items"."id" = "line_items"."item_id"
  #         INNER JOIN "parent_items" ON "parent_items"."id" = "items"."parent_item_id" 
  #         WHERE "parent_items"."id" = '#{parent_item_id}'
  #       ) custom_lendings

  #       ON ( week <= lent_at::DATE AND lent_at::DATE < week + INTERVAL '1 week') OR
  #       ( lent_at::DATE < week AND week + INTERVAL '1 week' < COALESCE(returned_at, now())::DATE ) OR
  #       ( week <= COALESCE(returned_at, now())::DATE AND COALESCE(returned_at, now())::DATE < week + INTERVAL '1 week' )

  #       GROUP BY week
  #       ORDER BY week
  #     SQL
  # end

end
