# ABOUTME: Rake task for first-time production setup.
# ABOUTME: Creates initial admin user and legal texts from environment variables.

namespace :bootstrap do
  desc "Create initial admin user and legal texts from environment variables"
  task admin: :environment do
    if User.where(admin: true).exists?
      puts "Admin user already exists, skipping bootstrap."
      next
    end

    admin_email = ENV["ADMIN_EMAIL"]
    admin_password = ENV["ADMIN_PASSWORD"]

    if admin_email.blank?
      abort "ADMIN_EMAIL environment variable is required for initial setup."
    end

    if admin_password.blank?
      abort "ADMIN_PASSWORD environment variable is required for initial setup."
    end

    ActiveRecord::Base.transaction do
      # Create default department if none exists
      if Department.count == 0
        Department.create!(
          name: "Standard",
          room: "TBD",
          default_lending_duration: 14,
          staffed: false,
          hidden: false,
          genus: "female"
        )
        puts "Created default department."
      end

      # Create admin user
      department = Department.first
      admin = User.create!(
        email: admin_email,
        password: admin_password,
        password_confirmation: admin_password,
        firstname: "Admin",
        lastname: "User",
        admin: true,
        current_department: department,
        department_memberships_attributes: [
          { role: "leader", department: department }
        ]
      )
      puts "Created admin user: #{admin.email}"

      # Create legal texts
      LegalText.create!([
        {
          content: "Die Ausleihbedingungen müssen noch festgelegt werden.",
          kind: "tos",
          user: admin
        },
        {
          content: "Die Datenschutzbestimmungen müssen noch festgelegt werden.",
          kind: "privacy",
          user: admin
        },
        {
          content: "Das Impressum muss noch festgelegt werden.",
          kind: "imprint",
          user: admin
        }
      ])
      puts "Created legal texts (tos, privacy, imprint)."
    end

    puts "Bootstrap completed successfully."
  end
end
