# ABOUTME: Link model — external URLs attached to a ParentItem.
# ABOUTME: Automatically prepends http:// to URLs that lack a scheme.

class Link < ApplicationRecord
  belongs_to :parent_item

  validates :url, presence: true
  validate :url_must_be_valid, if: -> { url.present? }

  before_validation :prepend_scheme

  private

  def prepend_scheme
    return if url.blank?
    return if url.start_with?("http://", "https://")

    self.url = "http://#{url}"
  end

  def url_must_be_valid
    uri = URI.parse(url)
    errors.add(:url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host&.include?(".")
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end
