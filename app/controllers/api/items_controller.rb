module Api
  # Serves both /api/collection and /api/wantlist — the two lists differ only in
  # which join model they read from.
  class ItemsController < BaseController
    def index
      query = ItemsQuery.new(base_scope, list_params)

      render json: {
        items: query.results.map { |item| ItemSerializer.call(item, list: list_name) },
        pagination: {
          page: query.page,
          per_page: query.per_page,
          total: query.total,
          total_pages: query.total_pages
        },
        sort: query.sort,
        facets: facets_for(query)
      }
    end

    private

    def list_name
      params[:list] == "wantlist" ? "wantlist" : "collection"
    end

    def base_scope
      list_name == "wantlist" ? WantlistItem.all : CollectionItem.all
    end

    def facets_for(query)
      releases = Release.where(id: query.filtered.select(:release_id))
      {
        genres: Release.facet(:genres, scope: releases).first(30),
        styles: Release.facet(:styles, scope: releases).first(30),
        formats: Release.facet(:formats, scope: releases).first(20),
        decades: decades_for(releases)
      }
    end

    def decades_for(releases)
      releases.where.not(year: nil)
              .group(Arel.sql("(releases.year / 10) * 10"))
              .order(Arel.sql("1 DESC"))
              .count
              .map { |decade, count| { value: decade.to_i, count: count } }
    end
  end
end
