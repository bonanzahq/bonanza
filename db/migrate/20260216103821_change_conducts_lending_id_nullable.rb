# ABOUTME: Makes conducts.lending_id nullable to allow conducts without a lending.
# ABOUTME: The model already has belongs_to :lending, optional: true.

class ChangeConductsLendingIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :conducts, :lending_id, true
  end
end
