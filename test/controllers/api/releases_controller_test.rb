require "test_helper"

class Api::ReleasesControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  def detail_payload
    {
      "released_formatted" => "15 Jun 1979",
      "tracklist" => [ { "position" => "A1", "title" => "Disorder", "duration" => "3:29" } ],
      "community" => { "have" => 10, "want" => 2, "rating" => { "average" => 4.5, "count" => 8 } }
    }
  end

  test "fetches the detail from Discogs the first time and caches it" do
    release = releases(:unknown_pleasures)

    requests = stub_discogs([ %r{/releases/1001}, discogs_response(detail_payload) ]) do
      get api_release_url(release.discogs_id)
    end

    assert_response :success
    assert_equal 1, requests.size
    assert_equal "Disorder", json["tracklist"].sole["title"]
    assert_equal "15 Jun 1979", json["released"]

    release.reload
    assert_equal detail_payload, release.details
    assert_not_nil release.details_fetched_at
  end

  test "serves the cached detail without touching Discogs again" do
    release = releases(:unknown_pleasures)
    release.update!(details: detail_payload, details_fetched_at: 1.day.ago)

    # No stub: a second fetch would hit the network guard and fail the test.
    get api_release_url(release.discogs_id)

    assert_response :success
    assert_equal "Disorder", json["tracklist"].sole["title"]
  end

  test "refetches once the cache is older than 30 days" do
    release = releases(:unknown_pleasures)
    release.update!(details: { "tracklist" => [] }, details_fetched_at: 31.days.ago)

    requests = stub_discogs([ %r{/releases/1001}, discogs_response(detail_payload) ]) do
      get api_release_url(release.discogs_id)
    end

    assert_equal 1, requests.size
    assert_equal "Disorder", json["tracklist"].sole["title"]
  end

  # A dead upstream should degrade the release page, not break it.
  test "still renders when the detail fetch fails" do
    release = releases(:unknown_pleasures)

    stub_discogs([ %r{/releases/1001}, discogs_response({}, code: 500) ]) do
      get api_release_url(release.discogs_id)
    end

    assert_response :success
    assert_equal "Unknown Pleasures", json["title"]
    assert_not json["details_available"]
    assert_empty json["tracklist"]
  end

  test "keeps the stale cache when a refetch fails" do
    release = releases(:unknown_pleasures)
    release.update!(details: detail_payload, details_fetched_at: 40.days.ago)

    stub_discogs([ %r{/releases/1001}, discogs_response({}, code: 502) ]) do
      get api_release_url(release.discogs_id)
    end

    assert_response :success
    assert_equal "Disorder", json["tracklist"].sole["title"]
    assert_equal detail_payload, release.reload.details
  end

  test "looks releases up by their Discogs id, not the local one" do
    release = releases(:unknown_pleasures)
    release.update!(details: detail_payload, details_fetched_at: 1.hour.ago)

    get api_release_url(release.discogs_id)
    assert_equal 1001, json["discogs_id"]
  end

  test "404s for a release that was never synced" do
    get api_release_url(999_999)

    assert_response :not_found
    assert_equal "not_found", json["error"]
    assert_equal "Registro não encontrado", json["message"]
  end

  test "reports which lists the release is in" do
    release = releases(:kind_of_blue)
    release.update!(details: {}, details_fetched_at: 1.hour.ago)

    stub_discogs([ %r{/releases/1002}, discogs_response(detail_payload) ]) do
      get api_release_url(release.discogs_id)
    end

    assert json["in_collection"]
    assert json["in_wantlist"]
    assert_equal 4, json["collection"]["rating"]
  end

  test "returns marketplace links for the release and its tracks" do
    release = releases(:unknown_pleasures)
    release.update!(
      details: {
        "tracklist" => [
          { "position" => "A1", "title" => "Disorder", "duration" => "3:29", "type_" => "track",
            "artists" => [ { "name" => "Joy Division" } ] },
          { "position" => "", "title" => "Side A", "type_" => "heading" }
        ]
      },
      details_fetched_at: 1.hour.ago
    )

    get marketplace_api_release_url(release.discogs_id)

    assert_response :success
    assert_equal "https://www.discogs.com/sell/release/1001", json["album"]["url"]
    assert_equal 1, json["tracks"].size
    assert_equal "Disorder", json["tracks"].sole["title"]
    assert_equal(
      "https://www.discogs.com/sell/list?q=Joy+Division+Disorder&type=release",
      json["tracks"].sole["marketplace_url"]
    )
  end

  test "marketplace endpoint uses the Discogs id and returns not found for unknown releases" do
    get marketplace_api_release_url(999_999)

    assert_response :not_found
    assert_equal "not_found", json["error"]
  end
end
