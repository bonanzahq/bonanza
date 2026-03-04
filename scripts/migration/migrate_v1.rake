# ABOUTME: Loads v1 MySQL data (exported as JSONL) into Redux PostgreSQL tables.
# ABOUTME: Handles column renames, enum mappings, and derived data creation.

require "json"

namespace :migrate do
  namespace :v1 do
    desc "Load v1 data from JSONL export into Redux tables"
    task load: :environment do
      data_dir = ENV.fetch("V1_DATA_DIR", Rails.root.join("tmp/v1_export").to_s)

      abort "ERROR: Data directory not found: #{data_dir}" unless Dir.exist?(data_dir)

      conn = ActiveRecord::Base.connection

      puts "=== Loading v1 data from #{data_dir} ==="

      # Interpret v1 timestamps (stored without timezone) as Berlin time
      conn.execute("SET timezone = 'Europe/Berlin'")

      # Disable FK constraints and triggers for bulk loading
      conn.execute("SET session_replication_role = 'replica'")

      # Clear target tables
      %w[
        department_memberships legal_texts gdpr_audit_logs
        conducts item_histories accessories_line_items
        line_items lendings accessories
        taggings tags links
        items parent_items borrowers users departments
      ].each { |t| conn.execute("TRUNCATE TABLE #{t} CASCADE") }

      # Drop partial unique indexes that may conflict with v1 data
      conn.execute("DROP INDEX IF EXISTS index_conducts_unique_active_ban_per_department")
      conn.execute("DROP INDEX IF EXISTS index_borrowers_unique_student_id")

      puts ""

      # Collect storage_location and role data during load
      storage_locations = {}
      user_roles = {}

      # 1. Departments
      load_jsonl(conn, data_dir, "departments", "departments") do |row|
        {
          id: row["id"],
          name: row["name"],
          room: row["room"],
          note: row["note"],
          time: row["time"],
          staffed: to_bool(row["staffed"]),
          staffed_at: row["staffed_at"],
          default_lending_duration: row["default_lending_duration"],
          hidden: false,
          genus: 0,
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 2. Users
      load_jsonl(conn, data_dir, "users", "users") do |row|
        user_roles[row["id"]] = row["role"]

        {
          id: row["id"],
          firstname: row["first_name"],
          lastname: row["last_name"],
          email: row["email"],
          encrypted_password: row["encrypted_password"],
          reset_password_token: row["reset_password_token"],
          reset_password_sent_at: row["reset_password_sent_at"],
          remember_created_at: row["remember_created_at"],
          current_department_id: row["department_id"],
          admin: (row["role"] == 3),
          confirmed_at: row["created_at"],
          invitation_token: row["invitation_token"],
          invitation_created_at: row["invitation_created_at"],
          invitation_sent_at: row["invitation_sent_at"],
          invitation_accepted_at: row["invitation_accepted_at"],
          invitation_limit: row["invitation_limit"],
          invited_by_id: row["invited_by_id"],
          invited_by_type: row["invited_by_type"],
          invitations_count: row["invitations_count"] || 0,
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 3. Borrowers (from lenders)
      load_jsonl(conn, data_dir, "lenders", "borrowers") do |row|
        {
          id: row["id"],
          firstname: row["first_name"],
          lastname: row["last_name"],
          student_id: blank_to_nil(row["student_id"]),
          email: row["email"],
          phone: row["phone"],
          email_token: row["tos_token"],
          tos_accepted: to_bool(row["tos_accepted"]),
          tos_accepted_at: to_bool(row["tos_accepted"]) ? row["created_at"] : nil,
          id_checked: to_bool(row["id_checked"]),
          insurance_checked: to_bool(row["insurance_checked"]),
          borrower_type: row["type"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 4. Parent items (capture storage_location, don't insert it)
      load_jsonl(conn, data_dir, "parent_items", "parent_items") do |row|
        sl = blank_to_nil(row["storage_location"])
        storage_locations[row["id"]] = sl if sl

        {
          id: row["id"],
          name: row["name"],
          description: row["description"],
          department_id: row["department_id"],
          price: row["price"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 5. Items (add storage_location from parent_items, comment -> note)
      load_jsonl(conn, data_dir, "items", "items") do |row|
        {
          id: row["id"],
          uid: row["uid"],
          quantity: row["quantity"],
          parent_item_id: row["parent_item_id"],
          status: row["status"],
          condition: row["condition"],
          note: row["comment"],
          storage_location: storage_locations[row["parent_item_id"]],
          lending_counter: 0,
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 6. Lendings (lender_id -> borrower_id)
      load_jsonl(conn, data_dir, "lendings", "lendings") do |row|
        {
          id: row["id"],
          note: row["note"],
          borrower_id: row["lender_id"],
          lent_at: row["lent_at"],
          state: row["state"],
          token: row["token"],
          user_id: row["user_id"],
          returned_at: row["returned_at"],
          duration: row["duration"],
          department_id: row["department_id"],
          notification_counter: row["notification_counter"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 7. Line items
      load_jsonl(conn, data_dir, "line_items", "line_items") do |row|
        {
          id: row["id"],
          item_id: row["item_id"],
          lending_id: row["lending_id"],
          quantity: row["quantity"],
          returned_at: row["returned_at"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 8. Item histories (comment -> note)
      load_jsonl(conn, data_dir, "item_histories", "item_histories") do |row|
        {
          id: row["id"],
          quantity: row["quantity"],
          note: row["comment"],
          condition: row["condition"],
          status: row["status"],
          item_id: row["item_id"],
          user_id: row["user_id"],
          line_item_id: row["line_item_id"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 9. Conducts (lender_id -> borrower_id)
      load_jsonl(conn, data_dir, "conducts", "conducts") do |row|
        {
          id: row["id"],
          kind: row["kind"],
          borrower_id: row["lender_id"],
          user_id: row["user_id"],
          department_id: row["department_id"],
          lending_id: row["lending_id"],
          reason: row["reason"],
          duration: row["duration"],
          permanent: to_bool(row["permanent"]),
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 10. Accessories
      load_jsonl(conn, data_dir, "accessories", "accessories") do |row|
        {
          id: row["id"],
          name: row["name"],
          parent_item_id: row["parent_item_id"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # 11. Accessories-line items (join table, no id)
      load_jsonl(conn, data_dir, "accessories_line_items", "accessories_line_items") do |row|
        {
          accessory_id: row["accessory_id"],
          line_item_id: row["line_item_id"]
        }
      end

      # 12. Tags
      load_jsonl(conn, data_dir, "tags", "tags") do |row|
        {
          id: row["id"],
          name: row["name"],
          taggings_count: row["taggings_count"] || 0
        }
      end

      # 13. Taggings (add tenant column)
      load_jsonl(conn, data_dir, "taggings", "taggings") do |row|
        {
          id: row["id"],
          tag_id: row["tag_id"],
          taggable_type: row["taggable_type"],
          taggable_id: row["taggable_id"],
          context: row["context"],
          tagger_type: row["tagger_type"],
          tagger_id: row["tagger_id"],
          tenant: nil,
          created_at: row["created_at"]
        }
      end

      # 14. Links
      load_jsonl(conn, data_dir, "links", "links") do |row|
        {
          id: row["id"],
          url: row["url"],
          title: row["title"],
          parent_item_id: row["parent_item_id"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        }
      end

      # === Post-migration transforms ===
      puts ""
      puts "--- Post-migration transforms ---"

      # 15. Department memberships from v1 roles
      # v1:    0=guest, 1=standard, 2=leader, 3=admin, 99=deleted
      # Redux: 0=guest, 1=member,   2=leader, 3=hidden, 99=deleted
      v1_to_redux_role = {0 => 0, 1 => 1, 2 => 2, 3 => 2, 99 => 99}

      membership_records = []
      now = Time.current.strftime("%Y-%m-%d %H:%M:%S")

      user_roles.each do |user_id, v1_role|
        dept = conn.select_value("SELECT current_department_id FROM users WHERE id = #{user_id.to_i}")
        next unless dept

        membership_records << {
          user_id: user_id,
          department_id: dept,
          role: v1_to_redux_role[v1_role] || 1,
          created_at: now,
          updated_at: now
        }
      end

      bulk_insert(conn, "department_memberships", membership_records)
      puts "  department_memberships: #{membership_records.size} created"

      # 16. Lending counters
      conn.execute(<<~SQL)
        UPDATE items SET lending_counter = (
          SELECT COUNT(*) FROM line_items WHERE line_items.item_id = items.id
        )
      SQL
      lc_count = conn.select_value("SELECT COUNT(*) FROM items WHERE lending_counter > 0")
      puts "  lending_counter: #{lc_count} items updated"

      # 17. Legal texts
      admin_id = conn.select_value("SELECT id FROM users WHERE admin = true ORDER BY id LIMIT 1")
      if admin_id
        conn.execute(<<~SQL)
          INSERT INTO legal_texts (kind, content, user_id, created_at, updated_at)
          VALUES
            (0, 'Bitte Ausleihbedingungen aktualisieren.', #{admin_id}, '#{now}', '#{now}'),
            (1, 'Bitte Datenschutzerklaerung aktualisieren.', #{admin_id}, '#{now}', '#{now}')
        SQL
        puts "  legal_texts: 2 created"
      else
        puts "  legal_texts: SKIPPED (no admin user)"
      end

      # 18. Reset sequences
      %w[
        departments users borrowers parent_items items lendings
        line_items item_histories conducts accessories tags taggings
        links department_memberships legal_texts gdpr_audit_logs
      ].each do |table|
        max_id = conn.select_value("SELECT MAX(id) FROM #{table}")
        if max_id
          conn.execute("SELECT setval('#{table}_id_seq', #{max_id})")
        else
          conn.execute("SELECT setval('#{table}_id_seq', 1, false)")
        end
      end
      puts "  sequences: reset"

      # 19. Deduplicate conducts and recreate unique indexes
      result = conn.execute(<<~SQL)
        WITH dupes AS (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY borrower_id, department_id
            ORDER BY created_at ASC, id ASC
          ) AS rn
          FROM conducts
          WHERE kind = 1 AND lifted_at IS NULL
        )
        DELETE FROM conducts WHERE id IN (SELECT id FROM dupes WHERE rn > 1)
      SQL
      deduped = result.cmd_tuples
      puts "  conducts dedup: #{deduped} duplicate active bans removed"

      conn.execute(<<~SQL)
        CREATE UNIQUE INDEX index_conducts_unique_active_ban_per_department
        ON conducts (borrower_id, department_id)
        WHERE kind = 1 AND lifted_at IS NULL
      SQL
      conn.execute(<<~SQL)
        CREATE UNIQUE INDEX index_borrowers_unique_student_id
        ON borrowers (student_id)
        WHERE student_id IS NOT NULL
      SQL
      puts "  unique indexes: recreated"

      # 20. Re-enable FK constraints
      conn.execute("SET session_replication_role = 'origin'")

      # 21. Catch orphaned records with missing departments.
      # v1 had no FK constraints, so departments could be deleted while
      # parent_items/lendings/conducts still referenced them.
      orphan_tables = {
        "parent_items" => "department_id",
        "lendings" => "department_id",
        "conducts" => "department_id"
      }

      # Create the Ponderosa department (catch-all for orphaned records and setup admin).
      ponderosa_id = conn.select_value("SELECT id FROM departments WHERE name = 'Ponderosa'")
      unless ponderosa_id
        conn.execute(<<~SQL)
          INSERT INTO departments (name, hidden, genus, created_at, updated_at)
          VALUES ('Ponderosa', true, 2, '#{now}', '#{now}')
        SQL
        ponderosa_id = conn.select_value("SELECT id FROM departments WHERE name = 'Ponderosa'")
        conn.execute("SELECT setval('departments_id_seq', GREATEST((SELECT MAX(id) FROM departments), nextval('departments_id_seq')))")
      end
      puts "  ponderosa: department id=#{ponderosa_id}"

      orphan_dept_ids = Set.new
      orphan_tables.each do |table, col|
        ids = conn.select_values(
          "SELECT DISTINCT #{col} FROM #{table} WHERE #{col} NOT IN (SELECT id FROM departments)"
        )
        ids.each { |id| orphan_dept_ids << id.to_i }
      end

      if orphan_dept_ids.any?
        orphan_tables.each do |table, col|
          count = conn.select_value(
            "SELECT COUNT(*) FROM #{table} WHERE #{col} IN (#{orphan_dept_ids.to_a.join(',')})"
          ).to_i
          if count > 0
            conn.execute(
              "UPDATE #{table} SET #{col} = #{ponderosa_id} WHERE #{col} IN (#{orphan_dept_ids.to_a.join(',')})"
            )
            puts "  ponderosa: #{count} #{table} reassigned from department(s) #{orphan_dept_ids.to_a.join(', ')} -> Ponderosa"
          end
        end
      else
        puts "  ponderosa: no orphaned department references found"
      end

      # Create setup admin in Ponderosa from ADMIN_EMAIL/ADMIN_PASSWORD env vars
      admin_email = ENV["ADMIN_EMAIL"]
      admin_password = ENV["ADMIN_PASSWORD"]
      if admin_email.present? && admin_password.present?
        existing = conn.select_value("SELECT id FROM users WHERE email = '#{conn.quote_string(admin_email)}'")
        unless existing
          admin = User.new(
            email: admin_email,
            password: admin_password,
            password_confirmation: admin_password,
            firstname: "Admin",
            lastname: "Setup",
            admin: true,
            current_department_id: ponderosa_id,
            department_memberships_attributes: [{ role: :leader, department_id: ponderosa_id }]
          )
          admin.skip_confirmation!
          admin.save!
          puts "  ponderosa: created setup admin #{admin_email}"
        else
          puts "  ponderosa: setup admin #{admin_email} already exists"
        end
      else
        puts "  ponderosa: ADMIN_EMAIL/ADMIN_PASSWORD not set, skipping setup admin"
      end

      # 22. Anonymize deleted borrowers (uses ActiveRecord, needs constraints enabled)
      deleted_count = 0
      Borrower.where(borrower_type: :deleted).find_each do |b|
        next if b.anonymized?
        b.anonymize!
        deleted_count += 1
      end
      puts "  anonymized: #{deleted_count} deleted borrowers"

      puts ""
      puts "=== Load complete ==="
    end

    desc "Validate migrated data"
    task validate: :environment do
      conn = ActiveRecord::Base.connection
      errors = []
      warnings = []
      data_dir = ENV.fetch("V1_DATA_DIR", Rails.root.join("tmp/v1_export").to_s)

      puts "=== Validating migration ==="

      # 1. Record counts (compare against JSONL export if available)
      puts "\n1. Record counts:"

      # Map JSONL source files to Redux table names
      source_to_table = {
        "departments" => "departments",
        "users" => "users",
        "lenders" => "borrowers",
        "parent_items" => "parent_items",
        "items" => "items",
        "lendings" => "lendings",
        "line_items" => "line_items",
        "item_histories" => "item_histories",
        "accessories" => "accessories",
        "accessories_line_items" => "accessories_line_items",
        "tags" => "tags",
        "taggings" => "taggings",
        "links" => "links",
        "conducts" => "conducts"
      }

      source_to_table.each do |source, table|
        actual = conn.select_value("SELECT COUNT(*) FROM #{table}").to_i
        jsonl_file = File.join(data_dir, "#{source}.jsonl")
        if File.exist?(jsonl_file)
          expected = File.foreach(jsonl_file).count
          # Conducts may be fewer due to dedup of duplicate active bans
          if table == "conducts" && actual < expected
            puts "   %-25s %6d (exported %d, %d deduped) [OK]" % [table, actual, expected, expected - actual]
          elsif actual == expected
            puts "   %-25s %6d [OK]" % [table, actual]
          else
            puts "   %-25s %6d (exported %d) [MISMATCH]" % [table, actual, expected]
            errors << "#{table}: exported #{expected}, got #{actual}"
          end
        else
          puts "   %-25s %6d (no export file to compare)" % [table, actual]
        end
      end

      # 2. Department memberships
      puts "\n2. Department memberships:"
      total_users = conn.select_value("SELECT COUNT(*) FROM users").to_i
      users_with = conn.select_value("SELECT COUNT(DISTINCT user_id) FROM department_memberships").to_i
      users_without = total_users - users_with
      puts "   #{users_with}/#{total_users} users have memberships"
      if users_without > 0
        errors << "#{users_without} users without department membership"
      end

      # 3. Admin users
      puts "\n3. Admin users:"
      conn.select_rows("SELECT id, email FROM users WHERE admin = true").each do |id, email|
        puts "   #{id}: #{email}"
      end

      # 4. Role distribution
      puts "\n4. Role distribution:"
      role_names = {0 => "guest", 1 => "member", 2 => "leader", 3 => "hidden", 99 => "deleted"}
      conn.select_rows("SELECT role, COUNT(*) FROM department_memberships GROUP BY role ORDER BY role").each do |role, count|
        puts "   %-10s %s" % [role_names[role.to_i] || "unknown(#{role})", count]
      end

      # 5. Foreign key integrity
      puts "\n5. Foreign key integrity:"
      {
        "parent_items -> departments" =>
          "SELECT COUNT(*) FROM parent_items WHERE department_id NOT IN (SELECT id FROM departments)",
        "items -> parent_items" =>
          "SELECT COUNT(*) FROM items WHERE parent_item_id NOT IN (SELECT id FROM parent_items)",
        "lendings -> borrowers" =>
          "SELECT COUNT(*) FROM lendings WHERE borrower_id IS NOT NULL AND borrower_id NOT IN (SELECT id FROM borrowers)",
        "lendings -> departments" =>
          "SELECT COUNT(*) FROM lendings WHERE department_id IS NOT NULL AND department_id NOT IN (SELECT id FROM departments)",
        "conducts -> borrowers" =>
          "SELECT COUNT(*) FROM conducts WHERE borrower_id NOT IN (SELECT id FROM borrowers)",
        "conducts -> departments" =>
          "SELECT COUNT(*) FROM conducts WHERE department_id NOT IN (SELECT id FROM departments)",
        "item_histories -> items" =>
          "SELECT COUNT(*) FROM item_histories WHERE item_id NOT IN (SELECT id FROM items)",
        "accessories -> parent_items" =>
          "SELECT COUNT(*) FROM accessories WHERE parent_item_id NOT IN (SELECT id FROM parent_items)",
        "links -> parent_items" =>
          "SELECT COUNT(*) FROM links WHERE parent_item_id NOT IN (SELECT id FROM parent_items)",
        "users -> departments" =>
          "SELECT COUNT(*) FROM users WHERE current_department_id IS NOT NULL AND current_department_id NOT IN (SELECT id FROM departments)",
        "taggings -> tags" =>
          "SELECT COUNT(*) FROM taggings WHERE tag_id NOT IN (SELECT id FROM tags)"
      }.each do |desc, query|
        orphans = conn.select_value(query).to_i
        if orphans > 0
          errors << "#{orphans} orphaned: #{desc}"
          puts "   %-30s %d orphans (ERROR)" % [desc, orphans]
        else
          puts "   %-30s OK" % desc
        end
      end

      # 6. Storage locations
      puts "\n6. Storage locations:"
      items_with_sl = conn.select_value("SELECT COUNT(*) FROM items WHERE storage_location IS NOT NULL").to_i
      puts "   #{items_with_sl} items have storage_location"

      # 7. Lending counters
      puts "\n7. Lending counters:"
      items_with_lc = conn.select_value("SELECT COUNT(*) FROM items WHERE lending_counter > 0").to_i
      max_lc = conn.select_value("SELECT MAX(lending_counter) FROM items").to_i
      puts "   #{items_with_lc} items with lending_counter > 0 (max: #{max_lc})"

      # 8. Legal texts
      puts "\n8. Legal texts:"
      puts "   #{conn.select_value("SELECT COUNT(*) FROM legal_texts")} records"

      # 9. Deleted/anonymized borrowers
      puts "\n9. Deleted borrowers:"
      deleted = conn.select_value("SELECT COUNT(*) FROM borrowers WHERE borrower_type = 2").to_i
      anon = conn.select_value("SELECT COUNT(*) FROM borrowers WHERE email LIKE '%@anonymized.local'").to_i
      puts "   #{deleted} deleted, #{anon} anonymized"

      # 10. TOS acceptance
      puts "\n10. TOS acceptance:"
      with_date = conn.select_value("SELECT COUNT(*) FROM borrowers WHERE tos_accepted = true AND tos_accepted_at IS NOT NULL").to_i
      without_date = conn.select_value("SELECT COUNT(*) FROM borrowers WHERE tos_accepted = true AND tos_accepted_at IS NULL").to_i
      puts "   #{with_date} with date, #{without_date} without date"
      if without_date > 0
        warnings << "#{without_date} borrowers accepted TOS but no tos_accepted_at"
      end

      # 11. Confirmed users
      puts "\n11. User confirmation:"
      confirmed = conn.select_value("SELECT COUNT(*) FROM users WHERE confirmed_at IS NOT NULL").to_i
      puts "   #{confirmed}/#{total_users} confirmed"
      if confirmed < total_users
        warnings << "#{total_users - confirmed} users not confirmed (can't log in)"
      end

      # Summary
      puts "\n=== Summary ==="
      if errors.any?
        puts "ERRORS (#{errors.size}):"
        errors.each { |e| puts "  - #{e}" }
      end
      if warnings.any?
        puts "WARNINGS (#{warnings.size}):"
        warnings.each { |w| puts "  - #{w}" }
      end
      if errors.empty?
        puts "PASSED" + (warnings.any? ? " with #{warnings.size} warning(s)" : "")
      else
        puts "FAILED with #{errors.size} error(s)"
        exit 1
      end
    end

    desc "Full migration: load + validate"
    task all: [:load, :validate]
  end
end

# --- Helpers ---

def load_jsonl(conn, data_dir, source_file, target_table, &block)
  file_path = File.join(data_dir, "#{source_file}.jsonl")
  unless File.exist?(file_path)
    puts "  WARNING: #{file_path} not found, skipping #{target_table}"
    return
  end

  records = []
  File.foreach(file_path) do |line|
    line = line.strip
    next if line.empty?
    row = JSON.parse(line)
    records << yield(row)

    if records.size >= 1000
      bulk_insert(conn, target_table, records)
      records = []
    end
  end

  bulk_insert(conn, target_table, records) if records.any?

  count = conn.select_value("SELECT COUNT(*) FROM #{target_table}")
  puts "  #{target_table}: #{count} rows"
end

def bulk_insert(conn, table, records)
  return if records.empty?

  columns = records.first.keys
  col_list = columns.map { |c| conn.quote_column_name(c) }.join(", ")

  values_sql = records.map do |record|
    vals = columns.map { |col| quote_value(conn, record[col]) }
    "(#{vals.join(', ')})"
  end.join(",\n")

  conn.execute("INSERT INTO #{table} (#{col_list}) VALUES #{values_sql}")
end

def quote_value(conn, value)
  case value
  when nil then "NULL"
  when true then "TRUE"
  when false then "FALSE"
  when Integer then value.to_s
  when Float then value.to_s
  else conn.quote(value.to_s)
  end
end

def to_bool(value)
  return nil if value.nil?
  value == true || value == 1 || value == "1" || value == "true"
end

def blank_to_nil(value)
  return nil if value.nil?
  str = value.to_s.strip
  str.empty? ? nil : str
end
