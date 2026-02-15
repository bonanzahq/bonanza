# ABOUTME: Handles error pages routed by exceptions_app.
# ABOUTME: Renders user-facing 404 and 500 pages for routing and middleware errors.
class ErrorsController < ApplicationController
  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: "application" }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def internal_server_error
    respond_to do |format|
      format.html { render "errors/internal_server_error", status: :internal_server_error, layout: "application" }
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end
end
