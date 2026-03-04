# ABOUTME: Deletes stale ES indices and reindexes ParentItem and Borrower.
# ABOUTME: Run via: bundle exec rails runner /path/to/reindex.rb RAILS_ENV=production

c = Searchkick.client

# List and delete all stale parent_items indices
indices = c.cat.indices(index: "parent_items_*", h: "index").split("\n").map(&:strip).reject(&:empty?)
indices.each do |idx|
  puts "Deleting #{idx}"
  c.indices.delete(index: idx)
end

# List and delete all stale borrowers indices
indices = c.cat.indices(index: "borrowers_*", h: "index").split("\n").map(&:strip).reject(&:empty?)
indices.each do |idx|
  puts "Deleting #{idx}"
  c.indices.delete(index: idx)
end

puts "Reindexing ParentItems (#{ParentItem.count} records)..."
ParentItem.reindex
puts "Reindexing Borrowers (#{Borrower.count} records)..."
Borrower.reindex
puts "Done."
