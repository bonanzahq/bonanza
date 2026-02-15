# ABOUTME: Health check endpoint for monitoring application and dependency status.
# ABOUTME: Checks database and Elasticsearch connectivity.
class HealthController < ApplicationController
  def readiness
    checks = {
      database: check_database,
      elasticsearch: check_elasticsearch
    }
    all_ok = checks.values.all? { |c| c[:status] == "ok" }

    render json: { status: all_ok ? "ok" : "degraded", checks: checks },
           status: all_ok ? :ok : :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue => e
    Rails.logger.error("Health check failed: database: #{e.class}: #{e.message}")
    { status: "error" }
  end

  def check_elasticsearch
    Searchkick.client.ping
    { status: "ok" }
  rescue => e
    Rails.logger.error("Health check failed: elasticsearch: #{e.class}: #{e.message}")
    { status: "error" }
  end
end
