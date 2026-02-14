# ABOUTME: Tests for health check endpoints.
# ABOUTME: Verifies liveness and readiness responses for container orchestration.

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET /up returns 200 with ok status" do
    get "/up"
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
  end

  test "GET /health/liveness returns 200 with ok status" do
    get "/health/liveness"
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
  end

  test "GET /health/readiness returns 200 with checks" do
    get "/health/readiness"
    assert_response :ok
    json = JSON.parse(response.body)
    assert_includes ["ok", "degraded"], json["status"]
    assert json.key?("checks")
    assert json["checks"].key?("database")
    assert json["checks"].key?("elasticsearch")
  end

  test "health endpoints do not require authentication" do
    # No sign_in call - should still work
    get "/health/liveness"
    assert_response :ok
  end
end
