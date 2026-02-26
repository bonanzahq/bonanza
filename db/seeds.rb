# ABOUTME: Seed data for development and test environments.
# ABOUTME: Creates sample users, items, borrowers, and lendings for local development.

return if Rails.env.production?

Searchkick.disable_callbacks

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
  password: "platypus-umbrella-cactus", 
  password_confirmation: "platypus-umbrella-cactus",
  current_department: department, 
  firstname: "Ad", 
  lastname: "Min", 
  admin: true,
  confirmed_at: Time.current,
  department_memberships_attributes: [
    { role: "leader", department: department }
  ]
)
User.create!(
  email: "hidden@example.com",
  password: "platypus-umbrella-cactus",
  password_confirmation: "platypus-umbrella-cactus",
  current_department: department,
  firstname: "Hidden",
  lastname: "User",
  admin: false,
  department_memberships_attributes: [
    { role: "hidden", department: department }
  ]
)

User.current_user = user

role_user_data = [
  { email: "leader@example.com", firstname: "Lea", lastname: "Leader", role: "leader" },
  { email: "member@example.com", firstname: "Max", lastname: "Member", role: "member" },
  { email: "guest@example.com",  firstname: "Gabi", lastname: "Guest",  role: "guest"   },
  { email: "hidden@example.com", firstname: "Hanna", lastname: "Hidden", role: "hidden" },
]

role_user_data.each do |data|
  User.create!(
    email: data[:email],
    password: "platypus-umbrella-cactus",
    password_confirmation: "platypus-umbrella-cactus",
    current_department: department,
    firstname: data[:firstname],
    lastname: data[:lastname],
    admin: false,
    confirmed_at: Time.current,
    department_memberships_attributes: [
      { role: data[:role], department: department }
    ]
  )
end

# --- Unique item (single) ---

arduino = ParentItem.create!(
  name: "Arduino Board", description: "Microcontroller-Board für Prototyping", department: department, price: "25", tag_list: "elektronik, prototyping"
)
arduino_item = Item.create!(
  uid: "ARD-001", quantity: 1, status: "available", note: "", storage_location: "Schrank A1", parent_item: arduino, lending_counter: 0, condition: "flawless"
)
Accessory.create!(name: "USB-Kabel", parent_item: arduino)

# --- Group items (multiple unique items per parent) ---

camera = ParentItem.create!(
  name: "Sony A7 III", description: "Vollformat-Systemkamera", department: department, price: "2000", tag_list: "kamera, foto, video"
)
Item.create!(uid: "CAM-001", quantity: 1, status: "available", note: "", storage_location: "Tresor 1", parent_item: camera, lending_counter: 0, condition: "flawless")
Item.create!(uid: "CAM-002", quantity: 1, status: "available", note: "", storage_location: "Tresor 1", parent_item: camera, lending_counter: 0, condition: "flawless")
Item.create!(uid: "CAM-003", quantity: 1, status: "available", note: "Leichter Kratzer am Display", storage_location: "Tresor 1", parent_item: camera, lending_counter: 0, condition: "flawed")
Accessory.create!([
  {name: "Objektivdeckel", parent_item: camera},
  {name: "Akku NP-FZ100", parent_item: camera},
  {name: "Ladegerät", parent_item: camera},
  {name: "Tragegurt", parent_item: camera}
])

microphone = ParentItem.create!(
  name: "Sennheiser MKE 600", description: "Richtmikrofon für Filmproduktion", department: department, price: "330", tag_list: "audio, mikrofon, film"
)
Item.create!(uid: "MIC-001", quantity: 1, status: "available", note: "", storage_location: "Schrank B2", parent_item: microphone, lending_counter: 0, condition: "flawless")
Item.create!(uid: "MIC-002", quantity: 1, status: "available", note: "", storage_location: "Schrank B2", parent_item: microphone, lending_counter: 0, condition: "flawless")
Accessory.create!([
  {name: "Windschutz", parent_item: microphone},
  {name: "XLR-Kabel 3m", parent_item: microphone}
])

tripod = ParentItem.create!(
  name: "Manfrotto 504X Stativ", description: "Videostativ mit Fluidkopf", department: department, price: "450", tag_list: "stativ, video, foto"
)
Item.create!(uid: "TRI-001", quantity: 1, status: "available", note: "", storage_location: "Lager 1", parent_item: tripod, lending_counter: 0, condition: "flawless")
Item.create!(uid: "TRI-002", quantity: 1, status: "available", note: "", storage_location: "Lager 1", parent_item: tripod, lending_counter: 0, condition: "flawless")
Item.create!(uid: "TRI-003", quantity: 1, status: "unavailable", note: "Bein klemmt", storage_location: "Werkstatt", parent_item: tripod, lending_counter: 0, condition: "broken")
Accessory.create!(name: "Schnellwechselplatte", parent_item: tripod)

projector = ParentItem.create!(
  name: "Epson EB-2250U Beamer", description: "WUXGA-Projektor, 5000 Lumen", department: department, price: "1200", tag_list: "beamer, präsentation"
)
Item.create!(uid: "BEA-001", quantity: 1, status: "available", note: "", storage_location: "Schrank C1", parent_item: projector, lending_counter: 0, condition: "flawless")
Item.create!(uid: "BEA-002", quantity: 1, status: "available", note: "", storage_location: "Schrank C1", parent_item: projector, lending_counter: 0, condition: "flawless")
Accessory.create!([
  {name: "HDMI-Kabel 5m", parent_item: projector},
  {name: "Fernbedienung", parent_item: projector},
  {name: "Transporttasche", parent_item: projector}
])

# --- Mass items (no uid, quantity > 1) ---

sd_cards = ParentItem.create!(
  name: "SD-Karte 64GB", description: "SanDisk Extreme Pro SDXC", department: department, price: "15", tag_list: "speicher, zubehör"
)
Item.create!(uid: "", quantity: 20, status: "available", note: "", storage_location: "Schublade A3", parent_item: sd_cards, lending_counter: 0, condition: "flawless")

xlr_cables = ParentItem.create!(
  name: "XLR-Kabel 5m", description: "Neutrik-Stecker, schwarz", department: department, price: "12", tag_list: "kabel, audio, zubehör"
)
Item.create!(uid: "", quantity: 15, status: "available", note: "", storage_location: "Kabelkiste 1", parent_item: xlr_cables, lending_counter: 0, condition: "flawless")

hdmi_cables = ParentItem.create!(
  name: "HDMI-Kabel 3m", description: "High Speed mit Ethernet", department: department, price: "8", tag_list: "kabel, video, zubehör"
)
Item.create!(uid: "", quantity: 10, status: "available", note: "", storage_location: "Kabelkiste 2", parent_item: hdmi_cables, lending_counter: 0, condition: "flawless")

batteries = ParentItem.create!(
  name: "AA-Akkus (4er Pack)", description: "Eneloop Pro 2500mAh", department: department, price: "14", tag_list: "akku, zubehör"
)
Item.create!(uid: "", quantity: 30, status: "available", note: "", storage_location: "Schublade A1", parent_item: batteries, lending_counter: 0, condition: "flawless")

gaffer_tape = ParentItem.create!(
  name: "Gaffertape schwarz", description: "50mm x 50m Rolle", department: department, price: "10", tag_list: "verbrauchsmaterial, zubehör"
)
Item.create!(uid: "", quantity: 8, status: "available", note: "", storage_location: "Regal 3", parent_item: gaffer_tape, lending_counter: 0, condition: "flawless")

# --- Borrowers ---

borrower_data = [
  { firstname: "Peter", lastname: "Parker", email: "test@example.com", phone: "012345678", borrower_type: "student", student_id: "123456789" },
  { firstname: "Ellen", lastname: "Ripley", email: "ripley@nostromo.example.com", phone: "055512001", borrower_type: "employee" },
  { firstname: "Marty", lastname: "McFly", email: "marty@hillvalley.example.com", phone: "055512002", borrower_type: "student", student_id: "198510211" },
  { firstname: "Dana", lastname: "Scully", email: "scully@fbi.example.com", phone: "055512003", borrower_type: "employee" },
  { firstname: "Leia", lastname: "Organa", email: "leia@alderaan.example.com", phone: "055512004", borrower_type: "student", student_id: "197705250" },
  { firstname: "Wednesday", lastname: "Addams", email: "wednesday@nevermore.example.com", phone: "055512005", borrower_type: "student", student_id: "200511230" },
  { firstname: "Gandalf", lastname: "Graurock", email: "gandalf@mittelerde.example.com", phone: "055512006", borrower_type: "employee" },
  { firstname: "Shuri", lastname: "Udaku", email: "shuri@wakanda.example.com", phone: "055512007", borrower_type: "student", student_id: "201803150" },
  { firstname: "Ferris", lastname: "Bueller", email: "ferris@dayoff.example.com", phone: "055512008", borrower_type: "student", student_id: "198606110" },
  { firstname: "Imperator", lastname: "Furiosa", email: "furiosa@citadel.example.com", phone: "055512009", borrower_type: "employee" },
]

borrowers = borrower_data.map do |data|
  Borrower.create!(data.merge(id_checked: true, insurance_checked: true, email_token: nil, tos_accepted: true, tos_accepted_at: Time.current))
end

borrower = borrowers.first
lending = Lending.create!(
  borrower: borrower, lent_at: 1.hour.ago, returned_at: Time.current, note: "", state: "completed", token: SecureRandom.urlsafe_base64(64), user: user, department: department, duration: 14, notification_counter: nil
)
line_item = LineItem.create!(
  item: arduino_item, lending: lending, quantity: 1, returned_at: Time.current
)

LegalText.create!([
  {content: "Die aktuellen Ausleihbedingungen", kind: "tos", user: user},
  {content: "Die aktuellen Datenschutzbestimmungen", kind: "privacy", user: user},
  {content: "Das aktuelle Impressum", kind: "imprint", user: user}
])

Searchkick.enable_callbacks

begin
  ParentItem.reindex
  Borrower.reindex
rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error
  puts "Elasticsearch not available, skipping reindex"
end
