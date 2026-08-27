require_relative "stub_helpers"

# Canned Discogs responses. The client talks to Net::HTTP directly, so the seam
# is Net::HTTP.start — everything above it (retries, throttling, status
# mapping, pagination) runs for real.
module DiscogsStubs
  include StubHelpers

  Response = Struct.new(:code, :body, :headers, keyword_init: true) do
    def [](name) = headers[name]
  end

  # `remaining: nil` omits the rate limit header entirely, like an error page.
  def discogs_response(body, code: 200, remaining: 50)
    headers = remaining.nil? ? {} : { "X-Discogs-Ratelimit-Remaining" => remaining.to_s }
    Response.new(
      code: code.to_s,
      body: body.is_a?(String) ? body : body.to_json,
      headers: headers
    )
  end

  # Takes [url_matcher, response] pairs. Each pair is consumed by the first
  # request it matches, so a paginated fetch can hand back page 1 then page 2,
  # and an unmatched request fails the test instead of hitting the network.
  # Yields the list of requests made, for asserting on the URLs.
  def stub_discogs(*pairs)
    requests = []
    pending = pairs.dup

    http = Object.new
    http.define_singleton_method(:request) do |request|
      requests << request
      url = request.uri.to_s
      index = pending.index { |matcher, _| matcher === url }
      raise "Requisição Discogs inesperada: #{url}" if index.nil?
      pending.delete_at(index).last
    end

    stub_singleton(Net::HTTP, :start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      yield requests
    end

    requests
  end

  # A `basic_information` blob shaped like the one Discogs returns.
  def basic_information(id:, title: "Título", artist: "Artista", **overrides)
    {
      "id" => id,
      "title" => title,
      "year" => 1979,
      "thumb" => "https://img.discogs.com/#{id}-thumb.jpg",
      "cover_image" => "https://img.discogs.com/#{id}-cover.jpg",
      "resource_url" => "https://api.discogs.com/releases/#{id}",
      "country" => "Brazil",
      "artists" => [ { "name" => artist, "join" => "" } ],
      "genres" => [ "Rock" ],
      "styles" => [ "Post-Punk" ],
      "labels" => [ { "name" => "Selo", "catno" => "CAT-#{id}" } ],
      "formats" => [ { "name" => "Vinyl", "qty" => "1", "descriptions" => [ "LP", "Album" ] } ]
    }.merge(overrides.transform_keys(&:to_s))
  end

  def collection_page(items, page: 1, pages: 1, total: nil)
    {
      "pagination" => { "page" => page, "pages" => pages, "items" => total || items.size },
      "releases" => items
    }
  end

  def wantlist_page(items, page: 1, pages: 1, total: nil)
    {
      "pagination" => { "page" => page, "pages" => pages, "items" => total || items.size },
      "wants" => items
    }
  end

  def collection_item(instance_id:, release_id:, rating: 0, **info)
    {
      "instance_id" => instance_id,
      "folder_id" => 1,
      "rating" => rating,
      "date_added" => "2024-03-01T10:00:00-08:00",
      "notes" => [],
      "basic_information" => basic_information(id: release_id, **info)
    }
  end

  def wantlist_item(release_id:, rating: 0, notes: nil, **info)
    {
      "rating" => rating,
      "notes" => notes,
      "date_added" => "2024-04-02T10:00:00-08:00",
      "basic_information" => basic_information(id: release_id, **info)
    }
  end
end
