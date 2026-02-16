# ABOUTME: Tests that no view files contain hardcoded localhost:3000 URLs.
# ABOUTME: Greps all ERB templates and JS files to catch protocol-relative URLs that break behind proxies.

require "test_helper"

class HardcodedUrlsTest < ActiveSupport::TestCase
  test "no ERB view files contain localhost:3000" do
    view_dir = Rails.root.join("app/views")
    matches = Dir.glob(view_dir.join("**/*.erb")).flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?("<%#", "<!--") && line.strip.end_with?("-->", "%>")
        "#{file}:#{index + 1}: #{line.strip}" if line.include?("localhost:3000")
      end
    end

    assert_empty matches,
      "Found hardcoded localhost:3000 URLs in view files:\n#{matches.join("\n")}"
  end

  test "no JavaScript files contain uncommented localhost:3000" do
    js_dir = Rails.root.join("app/javascript")
    matches = Dir.glob(js_dir.join("**/*.js")).flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?("//", "/*", "*")
        "#{file}:#{index + 1}: #{line.strip}" if line.include?("localhost:3000")
      end
    end

    assert_empty matches,
      "Found hardcoded localhost:3000 URLs in JS files:\n#{matches.join("\n")}"
  end
end
