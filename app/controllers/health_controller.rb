# ABOUTME: Health check endpoints for container orchestration.
# ABOUTME: Provides liveness (process alive) and readiness (dependencies available) checks.
class HealthController < ApplicationController
  def liveness
    render json: { status: "ok" }
  end

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
    { status: "error", message: e.message }
  end

  def check_elasticsearch
    Searchkick.client.ping
    { status: "ok" }
  rescue => e
    { status: "error", message: e.message }
  end
end
