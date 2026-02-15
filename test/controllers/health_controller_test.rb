# ABOUTME: Tests for the health check endpoint.
# ABOUTME: Verifies readiness response including dependency checks.

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET /health/readiness returns 200 with checks" do
    get "/health/readiness"
    assert_response :ok
    json = JSON.parse(response.body)
    assert_includes ["ok", "degraded"], json["status"]
    assert json.key?("checks")
    assert json["checks"].key?("database")
    assert json["checks"].key?("elasticsearch")
  end

  test "health endpoint does not require authentication" do
    # No sign_in call - should still work
    get "/health/readiness"
    assert_response :ok
  end
end
