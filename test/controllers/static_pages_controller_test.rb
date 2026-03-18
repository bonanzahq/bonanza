# ABOUTME: Tests for StaticPagesController.
# ABOUTME: Covers legal text editing and auto-creation of missing records.

require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = create(:department)
    @admin = create(:user, :admin, department: @department)
  end

  test "edit creates missing legal text records" do
    assert_equal 0, LegalText.count

    sign_in @admin
    get verwaltung_texte_path

    assert_response :success
    assert_equal 3, LegalText.count
    assert LegalText.where(kind: :tos).exists?
    assert LegalText.where(kind: :privacy).exists?
    assert LegalText.where(kind: :imprint).exists?
  end

  test "edit does not duplicate existing legal text records" do
    LegalText.create!(kind: :tos, content: "Existing TOS", user: @admin)
    LegalText.create!(kind: :privacy, content: "Existing Privacy", user: @admin)
    assert_equal 2, LegalText.count

    sign_in @admin
    get verwaltung_texte_path

    assert_response :success
    assert_equal 3, LegalText.count
    assert_equal "Existing TOS", LegalText.current_tos.content
    assert_equal "Existing Privacy", LegalText.current_privacy.content
  end

  test "edit renders when all legal texts exist" do
    LegalText.create!(kind: :tos, content: "TOS", user: @admin)
    LegalText.create!(kind: :privacy, content: "Privacy", user: @admin)
    LegalText.create!(kind: :imprint, content: "Imprint", user: @admin)

    sign_in @admin
    get verwaltung_texte_path

    assert_response :success
    assert_equal 3, LegalText.count
  end
end
