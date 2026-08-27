class ReleaseSerializer
  def self.summary(release)
    {
      id: release.id,
      discogs_id: release.discogs_id,
      title: release.title,
      artist: release.artist,
      year: release.year,
      thumb_url: release.thumb_url,
      cover_url: release.cover_url,
      country: release.country,
      label: release.label,
      catno: release.catno,
      genres: release.genres,
      styles: release.styles,
      formats: release.formats,
      format_summary: format_summary(release),
      discogs_url: release.discogs_url,
      marketplace_url: release.marketplace_url
    }
  end

  def self.detail(release)
    details = release.details || {}

    summary(release).merge(
      labels: release.labels,
      artists: release.artists,
      tracklist: tracklist(details),
      videos: videos(details),
      images: images(details),
      notes: details["notes"],
      released: details["released_formatted"].presence || details["released"],
      lowest_price: details["lowest_price"],
      num_for_sale: details["num_for_sale"],
      community: community(details),
      in_collection: release.collection_item.present?,
      in_wantlist: release.wantlist_item.present?,
      collection: release.collection_item && {
        rating: release.collection_item.rating,
        date_added: release.collection_item.date_added,
        notes: release.collection_item.notes
      },
      wantlist: release.wantlist_item && {
        rating: release.wantlist_item.rating,
        date_added: release.wantlist_item.date_added,
        notes: release.wantlist_item.notes
      },
      details_available: release.details.present?
    )
  end

  def self.marketplace(release)
    details = release.details || {}
    tracks = tracklist(details).reject { |track| track[:type] == "heading" }

    {
      discogs_id: release.discogs_id,
      title: release.title,
      artist: release.artist,
      album: {
        title: release.title,
        artist: release.artist,
        url: release.marketplace_url
      },
      tracks: tracks.map do |track|
        track.merge(
          marketplace_url: marketplace_search_url("#{track[:artists].presence&.join(', ') || release.artist} #{track[:title]}")
        )
      end
    }
  end

  # "2×Vinyl, LP, Album, 180g" — the line Discogs shows under a release title.
  def self.format_summary(release)
    Array(release.formats).map { |f|
      qty = f["qty"].to_i
      parts = [ qty > 1 ? "#{qty}×#{f['name']}" : f["name"] ]
      parts.concat(Array(f["descriptions"]))
      parts << f["text"] if f["text"].present?
      parts.compact_blank.join(", ")
    }.compact_blank.join(" + ")
  end

  def self.tracklist(details)
    Array(details["tracklist"]).map do |track|
      {
        position: track["position"],
        title: track["title"],
        duration: track["duration"],
        type: track["type_"],
        artists: Array(track["artists"]).map { |a| Discogs::ReleaseMapper.clean_name(a["name"]) }
      }
    end
  end

  def self.videos(details)
    Array(details["videos"]).first(8).map do |video|
      {
        title: video["title"],
        uri: video["uri"],
        duration: video["duration"],
        youtube_id: youtube_id(video["uri"])
      }
    end
  end

  def self.images(details)
    Array(details["images"]).first(12).map do |image|
      { uri: image["uri"], thumb: image["uri150"], type: image["type"] }
    end
  end

  def self.community(details)
    community = details["community"] or return nil
    {
      have: community.dig("have"),
      want: community.dig("want"),
      rating: community.dig("rating", "average"),
      rating_count: community.dig("rating", "count")
    }
  end

  def self.youtube_id(uri)
    return nil if uri.blank?
    uri[%r{(?:v=|youtu\.be/|embed/)([A-Za-z0-9_-]{11})}, 1]
  end

  def self.marketplace_search_url(query)
    "https://www.discogs.com/sell/list?q=#{CGI.escape(query)}&type=release"
  end
end
