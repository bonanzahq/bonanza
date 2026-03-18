# ABOUTME: Deletes stale ES indices and reindexes ParentItem and Borrower.
# ABOUTME: Run via: RAILS_ENV=production bundle exec rails runner /path/to/reindex.rb

c = Searchkick.client

# Delete stale indices scoped to the current environment's Searchkick prefix
[ParentItem, Borrower].each do |model|
  prefix = model.searchkick_index.name
  indices = c.cat.indices(index: "#{prefix}_*", h: "index").split("\n").map(&:strip).reject(&:empty?)
  indices.each do |idx|
    puts "Deleting #{idx}"
    c.indices.delete(index: idx)
  end
end

puts "Reindexing ParentItems (#{ParentItem.count} records)..."
ParentItem.reindex
puts "Reindexing Borrowers (#{Borrower.count} records)..."
Borrower.reindex
puts "Done."
