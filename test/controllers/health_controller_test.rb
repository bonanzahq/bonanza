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

  test "degraded check does not leak error messages" do
    # ES in test env is either absent or has SSL mismatch, so this
    # naturally returns a degraded response with an ES error
    get "/health/readiness"
    json = JSON.parse(response.body)
    # If ES happens to be reachable and healthy, skip this assertion
    es_check = json["checks"]["elasticsearch"]
    return if es_check["status"] == "ok"

    assert_equal "error", es_check["status"]
    assert_not es_check.key?("message"), "Error message should not be exposed in the response"
  end
end
