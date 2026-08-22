module Api
  class BaseController < ApplicationController
    skip_forgery_protection if: -> { request.get? }

    # rescue_from matches handlers in reverse declaration order, so the
    # catch-all has to be declared before the subclasses it would swallow.
    rescue_from Discogs::Error, with: :render_upstream_error
    rescue_from Discogs::Unauthorized, with: :render_unauthorized
    rescue_from Discogs::NotConfigured, with: :render_not_configured
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private

    def render_not_configured(error)
      render json: { error: "not_configured", message: error.message }, status: :service_unavailable
    end

    def render_unauthorized(error)
      render json: { error: "unauthorized", message: error.message }, status: :unauthorized
    end

    def render_upstream_error(error)
      render json: { error: "discogs_error", message: error.message }, status: :bad_gateway
    end

    def render_not_found(_error)
      render json: { error: "not_found", message: "Registro não encontrado" }, status: :not_found
    end

    def list_params
      params.permit(:q, :genre, :style, :media, :decade, :sort, :page, :per_page)
    end
  end
end
