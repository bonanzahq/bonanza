# ABOUTME: Adds a conditional unique index on borrowers.student_id.
# ABOUTME: Only enforces uniqueness where student_id is not null (employees have nil).

class AddUniqueIndexToBorrowersStudentId < ActiveRecord::Migration[8.0]
  def change
    add_index :borrowers, :student_id,
      unique: true,
      where: "student_id IS NOT NULL",
      name: "index_borrowers_unique_student_id"
  end
end
