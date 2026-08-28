module Api
  class BaseController < ApplicationController
    # Rails.cache in production is solid_cache (shared across Puma workers via
    # the DB), which is what a rate limit needs to mean anything once there is
    # more than one process. Test's cache_store is :null_store, which would
    # make rate limits silently inert there, so test gets its own MemoryStore.
    RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

    skip_forgery_protection if: -> { request.get? }

    # rescue_from matches handlers in reverse declaration order, so the
    # catch-all has to be declared before the subclasses it would swallow.
    rescue_from Discogs::Error, with: :render_upstream_error
    rescue_from Discogs::Unauthorized, with: :render_unauthorized
    rescue_from Discogs::NotConfigured, with: :render_not_configured
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private

    def render_rate_limited
      render json: { error: "rate_limited", message: "Muitas requisições. Aguarde um pouco e tente de novo." },
             status: :too_many_requests
    end

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
