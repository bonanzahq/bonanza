# ABOUTME: Centralized exception handling for all controllers.
# ABOUTME: Rescues common exceptions and renders appropriate error pages.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  private

  def log_exception(exception, level: :error)
    Rails.logger.public_send(level, {
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.first(10),
      request_id: request.request_id,
      user_id: current_user&.id,
      path: request.path
    })
  end

  def handle_not_found(exception)
    log_exception(exception, level: :warn)
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: "application" }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  def handle_internal_error(exception)
    log_exception(exception)
    respond_to do |format|
      format.html { render "errors/internal_server_error", status: :internal_server_error, layout: "application" }
      format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
    end
  end
end
