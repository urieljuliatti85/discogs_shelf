module Api
  class ProfileController < BaseController
    def show
      client = Discogs::Client.new

      render json: {
        username: client.username,
        configured: client.configured?,
        authenticated: client.authenticated?,
        stats: stats,
        last_sync: SyncRun.latest.where(status: "completed").first&.finished_at
      }
    end

    private

    def stats
      collection = Release.where(id: CollectionItem.select(:release_id))
      {
        collection_count: CollectionItem.count,
        wantlist_count: WantlistItem.count,
        release_count: Release.count,
        artist_count: collection.distinct.count(:artist),
        top_genres: Release.facet(:genres, scope: collection).first(8),
        top_formats: Release.facet(:formats, scope: collection).first(6),
        decades: collection.where.not(year: nil)
                           .group(Arel.sql("(releases.year / 10) * 10"))
                           .order(Arel.sql("1 ASC"))
                           .count
                           .map { |decade, count| { value: decade.to_i, count: count } },
        top_artists: collection.group(:artist).order(Arel.sql("COUNT(*) DESC")).limit(8).count
                               .map { |artist, count| { value: artist, count: count } }
      }
    end
  end
end
