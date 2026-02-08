department = Department.create!(
  name: "Test Department",
  room: "LW 125",
  default_lending_duration: 14,
  staffed: true,
  staffed_at: Time.current,
  hidden: false,
  genus: "neuter",
  created_at: Time.current,
  updated_at: Time.current
)
user = User.create!(
  email: "admin@example.com", 
  password: "password", 
  password_confirmation: "password",
  current_department: department, 
  firstname: "Ad", 
  lastname: "Min", 
  admin: true, 
  department_memberships_attributes: [
    { role: "leader", department: department }
  ]
)
parent_item = ParentItem.create!(
  name: "Arduino Board", description: "", department: department, price: "", tag_list: nil
)
item = Item.create!(
  uid: "123123", quantity: 1, status: "available", note: "", storage_location: "", parent_item: parent_item, lending_counter: 0, condition: "flawless"
)
borrower = Borrower.create!(
  firstname: "Peter", lastname: "Parker", email: "test@example.com", phone: "012345678", borrower_type: "student", id_checked: true, insurance_checked: true, student_id: "123456789", email_token: nil, tos_accepted: true, tos_accepted_at: "2025-10-03 13:01:12"
)
lending = Lending.create!(
  borrower: borrower, lent_at: "2025-10-03 13:02:20", returned_at: "2025-10-03 13:02:42", note: "", state: "completed", token: "jCqBMA9Q-V1gyTSFScwQnpgx1JEYMHeUSrH7MhVKvXGZI_QLI3XAJiNZ3R37U0EpVFEy6SsV6mlWFVfNovL_Rg", user: user, department: department, duration: 14, notification_counter: nil
)
line_item = LineItem.create!(
  item: item, lending: lending, quantity: 1, returned_at: "2025-10-03 13:02:42"
)
LegalText.create!([
  {content: "Die aktuellen Ausleihbedingungen", kind: "tos", user: user},
  {content: "Die aktuellen Datenschutzbestimmungen", kind: "privacy", user: user},
  {content: "Das aktuelle Impressum", kind: "imprint", user: user}
])
ItemHistory.create!([
  {quantity: 1, note: nil, condition: "flawless", status: "lent", item: item, user: user, line_item: line_item},
  {quantity: 1, note: nil, condition: "flawless", status: "returned", item: item, user: user, line_item: line_item},
])
Accessory.create!([
  {name: "USB-Kabel", parent_item: parent_item}
])
ParentItem.reindex
Borrower.reindex
