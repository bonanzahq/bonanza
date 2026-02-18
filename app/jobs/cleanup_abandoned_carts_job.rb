# ABOUTME: Job that removes abandoned lending carts older than 2 days.
# ABOUTME: Delegates to Lending.remove_abandoned_carts.

class CleanupAbandonedCartsJob < ApplicationJob
  queue_as :low

  def perform
    Lending.remove_abandoned_carts
  end
end
