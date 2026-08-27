module Api
  class ReleasesController < BaseController
    # Full release detail. Tracklists, videos and credits are not part of the
    # collection payload, so they are fetched on demand and cached in SQLite.
    def show
      release = Release.find_by!(discogs_id: params[:id])
      fetch_details(release)

      render json: ReleaseSerializer.detail(release)
    end

    def marketplace
      release = Release.find_by!(discogs_id: params[:id])
      fetch_details(release)

      render json: ReleaseSerializer.marketplace(release)
    end

    private

    def fetch_details(release)
      return unless release.details_stale?

      begin
        details = Discogs::Client.new.release(release.discogs_id)
        release.update!(details: details, details_fetched_at: Time.current)
      rescue Discogs::Error => e
        Rails.logger.warn("[Api::Releases] detail fetch failed: #{e.message}")
      end
    end
  end
end
