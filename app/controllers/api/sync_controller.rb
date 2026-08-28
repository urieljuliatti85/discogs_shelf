module Api
  class SyncController < BaseController
    # A full sync crawls the whole Discogs collection/wantlist. SyncRun.running?
    # already blocks a second run while one is in flight, but not repeated
    # attempts once one finishes or fails, so this caps how often the endpoint
    # can kick off the external crawl at all.
    rate_limit to: 5, within: 10.minutes, only: :create, store: RATE_LIMIT_STORE, with: :render_rate_limited

    def show
      render json: serialize(SyncRun.current)
    end

    def create
      if SyncRun.running?
        return render json: serialize(SyncRun.current), status: :accepted
      end

      client = Discogs::Client.new
      raise Discogs::NotConfigured, "DISCOGS_USERNAME não está configurado" unless client.configured?

      sync_run = SyncRun.create!(status: "pending")
      DiscogsSyncJob.perform_later(sync_run.id)

      render json: serialize(sync_run), status: :created
    end

    private

    def serialize(sync_run)
      return { status: "never_run" } if sync_run.nil?

      {
        id: sync_run.id,
        status: sync_run.status,
        stage: sync_run.stage,
        synced_count: sync_run.synced_count,
        total_count: sync_run.total_count,
        progress: sync_run.progress,
        started_at: sync_run.started_at,
        finished_at: sync_run.finished_at,
        error_message: sync_run.error_message
      }
    end
  end
end
