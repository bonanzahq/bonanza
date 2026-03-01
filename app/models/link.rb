# ABOUTME: Link model — external URLs attached to a ParentItem.
# ABOUTME: Automatically prepends http:// to URLs that lack a scheme.

class Link < ApplicationRecord
  belongs_to :parent_item

  validates :url, presence: true

  before_validation :prepend_scheme

  private

  def prepend_scheme
    return if url.blank?
    return if url.start_with?("http://", "https://")

    self.url = "http://#{url}"
  end
end
