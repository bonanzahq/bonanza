# ABOUTME: Rake tasks for detecting and resolving orphaned lendings.
# ABOUTME: Orphaned lendings have line_items referencing items that no longer exist.

namespace :lendings do
  desc "List lendings with orphaned line items (referencing non-existent items)"
  task find_orphaned: :environment do
    orphaned_line_items = LineItem.orphaned.includes(:lending)

    if orphaned_line_items.empty?
      puts "No orphaned line items found."
      next
    end

    puts "Found #{orphaned_line_items.count} orphaned line item(s):\n\n"

    orphaned_line_items.group_by(&:lending).each do |lending, line_items|
      dept_name = lending.department&.name || "unknown"
      borrower_name = lending.borrower&.fullname || "unknown"
      status = lending.returned_at? ? "returned" : "active"

      puts "Lending ##{lending.id} (#{status}, dept: #{dept_name}, borrower: #{borrower_name})"
      puts "  State: #{lending.state}, lent_at: #{lending.lent_at}, returned_at: #{lending.returned_at}"

      line_items.each do |li|
        puts "  Line item ##{li.id}: item_id=#{li.item_id} (MISSING), qty=#{li.quantity}, returned_at=#{li.returned_at}"
      end

      puts ""
    end

    lending_ids = orphaned_line_items.map(&:lending_id).uniq
    active_count = Lending.where(id: lending_ids, returned_at: nil).count
    puts "Summary: #{orphaned_line_items.count} orphaned line item(s) across #{lending_ids.size} lending(s), #{active_count} active."
  end

  desc "Force-close all active lendings with orphaned line items"
  task close_orphaned: :environment do
    active_orphaned = Lending.with_orphaned_items.where(returned_at: nil)

    if active_orphaned.empty?
      puts "No active orphaned lendings found."
      next
    end

    puts "Found #{active_orphaned.count} active orphaned lending(s). Force-closing...\n\n"

    # Rake tasks have no current user — create a system user reference
    system_user = User.find_by(admin: true)
    unless system_user
      puts "ERROR: No admin user found. Cannot force-close without an admin user."
      next
    end

    closed = 0
    active_orphaned.find_each do |lending|
      begin
        lending.force_close!(system_user, "Automated cleanup of orphaned line items via rake task")
        puts "  Closed lending ##{lending.id}"
        closed += 1
      rescue => e
        puts "  ERROR closing lending ##{lending.id}: #{e.message}"
      end
    end

    puts "\nDone. Closed #{closed} of #{active_orphaned.count} lending(s)."
  end
end
