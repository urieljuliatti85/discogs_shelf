require "test_helper"

class ReleaseSerializerTest < ActiveSupport::TestCase
  test "summary carries what the list views render" do
    payload = ReleaseSerializer.summary(releases(:unknown_pleasures))

    assert_equal "Unknown Pleasures", payload[:title]
    assert_equal "Joy Division", payload[:artist]
    assert_equal 1979, payload[:year]
    assert_equal "FACT 10", payload[:catno]
    assert_equal [ "Rock", "Electronic" ], payload[:genres]
    assert_equal "https://www.discogs.com/release/1001", payload[:discogs_url]
    assert_equal "https://www.discogs.com/sell/release/1001", payload[:marketplace_url]
  end

  test "summary leaves the lazily fetched detail fields out" do
    payload = ReleaseSerializer.summary(releases(:unknown_pleasures))

    assert_not_includes payload.keys, :tracklist
    assert_not_includes payload.keys, :videos
    assert_not_includes payload.keys, :community
  end

  # --- format_summary ---

  test "format_summary reads like the line Discogs shows" do
    assert_equal "Vinyl, LP, Album", ReleaseSerializer.format_summary(releases(:unknown_pleasures))
  end

  test "format_summary prefixes the quantity only for multi-disc sets" do
    assert_equal "2×Vinyl, LP, Album, Gatefold",
                 ReleaseSerializer.format_summary(releases(:clube_da_esquina))
  end

  test "format_summary joins several formats with a plus" do
    release = Release.new(formats: [
      { "name" => "Vinyl", "qty" => "1", "descriptions" => [ "LP" ] },
      { "name" => "CD", "qty" => "2", "descriptions" => [] }
    ])

    assert_equal "Vinyl, LP + 2×CD", ReleaseSerializer.format_summary(release)
  end

  test "format_summary survives missing formats" do
    assert_equal "", ReleaseSerializer.format_summary(Release.new(formats: []))
    assert_equal "", ReleaseSerializer.format_summary(Release.new(formats: nil))
  end

  # --- detail ---

  test "detail adds the cached Discogs payload to the summary" do
    release = releases(:unknown_pleasures)
    release.update!(details: {
      "released_formatted" => "15 Jun 1979",
      "notes" => "Prensagem original",
      "lowest_price" => 42.5,
      "num_for_sale" => 3,
      "tracklist" => [
        { "position" => "A1", "title" => "Disorder", "duration" => "3:29", "type_" => "track",
          "artists" => [ { "name" => "Joy Division (2)" } ] }
      ],
      "community" => { "have" => 100, "want" => 20, "rating" => { "average" => 4.7, "count" => 55 } }
    }, details_fetched_at: Time.current)

    payload = ReleaseSerializer.detail(release)

    assert_equal "15 Jun 1979", payload[:released]
    assert_equal 42.5, payload[:lowest_price]
    assert_equal({ have: 100, want: 20, rating: 4.7, rating_count: 55 }, payload[:community])
    assert_equal [ { position: "A1", title: "Disorder", duration: "3:29", type: "track",
                     artists: [ "Joy Division" ] } ], payload[:tracklist]
    assert payload[:details_available]
  end

  test "detail falls back to the raw release date when Discogs sends no formatted one" do
    release = releases(:unknown_pleasures)
    release.update!(details: { "released" => "1979-06-15" })

    assert_equal "1979-06-15", ReleaseSerializer.detail(release)[:released]
  end

  test "detail works with no cached payload at all" do
    payload = ReleaseSerializer.detail(releases(:unknown_pleasures))

    assert_not payload[:details_available]
    assert_empty payload[:tracklist]
    assert_empty payload[:videos]
    assert_nil payload[:community]
  end

  test "detail reports which lists the release belongs to" do
    both = ReleaseSerializer.detail(releases(:kind_of_blue))
    assert both[:in_collection]
    assert both[:in_wantlist]
    assert_equal 4, both[:collection][:rating]
    assert_equal "Procurar prensagem original", ReleaseSerializer.detail(releases(:selected_ambient))[:wantlist][:notes]

    only_wanted = ReleaseSerializer.detail(releases(:selected_ambient))
    assert_not only_wanted[:in_collection]
    assert_nil only_wanted[:collection]
  end

  test "marketplace returns album and track purchase links" do
    release = releases(:unknown_pleasures)
    release.update!(details: {
      "tracklist" => [
        { "position" => "A1", "title" => "Disorder", "type_" => "track",
          "artists" => [ { "name" => "Joy Division" } ] }
      ]
    })

    payload = ReleaseSerializer.marketplace(release)

    assert_equal "https://www.discogs.com/sell/release/1001", payload[:album][:url]
    assert_equal "https://www.discogs.com/sell/list?q=Joy+Division+Disorder&type=release",
                 payload[:tracks].sole[:marketplace_url]
  end

  test "detail caps videos and images" do
    release = releases(:unknown_pleasures)
    release.update!(details: {
      "videos" => Array.new(12) { |i| { "title" => "V#{i}", "uri" => "https://youtu.be/#{'a' * 11}" } },
      "images" => Array.new(20) { |i| { "uri" => "https://img/#{i}.jpg", "uri150" => "https://img/#{i}-t.jpg", "type" => "secondary" } }
    })

    payload = ReleaseSerializer.detail(release)

    assert_equal 8, payload[:videos].size
    assert_equal 12, payload[:images].size
  end

  # --- youtube ids ---

  test "extracts the youtube id from every url shape Discogs stores" do
    assert_equal "dQw4w9WgXcQ", ReleaseSerializer.youtube_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    assert_equal "dQw4w9WgXcQ", ReleaseSerializer.youtube_id("https://youtu.be/dQw4w9WgXcQ")
    assert_equal "dQw4w9WgXcQ", ReleaseSerializer.youtube_id("https://www.youtube.com/embed/dQw4w9WgXcQ")
  end

  test "returns no youtube id for anything else" do
    assert_nil ReleaseSerializer.youtube_id("https://vimeo.com/12345")
    assert_nil ReleaseSerializer.youtube_id("")
    assert_nil ReleaseSerializer.youtube_id(nil)
  end
end

class ItemSerializerTest < ActiveSupport::TestCase
  test "wraps the release summary with the per-item fields" do
    payload = ItemSerializer.call(collection_items(:unknown_pleasures), list: "collection")

    assert_equal "collection", payload[:list]
    assert_equal "Unknown Pleasures", payload[:title]
    assert_equal 5, payload[:rating]
    assert_equal collection_items(:unknown_pleasures).id, payload[:item_id]
  end

  test "empty notes serialize as nil rather than an empty array" do
    assert_nil ItemSerializer.call(collection_items(:unknown_pleasures), list: "collection")[:notes]
    assert_equal [ { "field_id" => 1, "value" => "Capa desgastada" } ],
                 ItemSerializer.call(collection_items(:kind_of_blue), list: "collection")[:notes]
  end

  test "wantlist notes are plain text" do
    assert_equal "Procurar prensagem original",
                 ItemSerializer.call(wantlist_items(:selected_ambient), list: "wantlist")[:notes]
  end
end
