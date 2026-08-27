require "test_helper"

class Api::ProfileControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  test "reports the configured account without calling Discogs" do
    get api_profile_url

    assert_response :success
    assert_equal "colecionador", json["username"]
    assert json["configured"]
    assert json["authenticated"]
  end

  test "reports a missing username as not configured" do
    without_env("DISCOGS_USERNAME") { get api_profile_url }

    assert_response :success
    assert_nil json["username"]
    assert_not json["configured"]
  end

  test "reports a missing token as unauthenticated but still configured" do
    without_env("DISCOGS_TOKEN") { get api_profile_url }

    assert json["configured"]
    assert_not json["authenticated"]
  end

  test "counts the collection, the wantlist and the distinct artists" do
    stats = (get api_profile_url; json["stats"])

    assert_equal CollectionItem.count, stats["collection_count"]
    assert_equal WantlistItem.count, stats["wantlist_count"]
    assert_equal Release.count, stats["release_count"]
    assert_equal 4, stats["artist_count"]
  end

  test "top genres and formats are counted over the collection only" do
    get api_profile_url
    stats = json["stats"]

    # Selected Ambient Works is wantlist-only, so its Electronic genre is not counted.
    assert_equal({ "value" => "Rock", "count" => 3 }, stats["top_genres"].first)
    assert_equal 1, stats["top_genres"].find { |g| g["value"] == "Electronic" }["count"]
    assert_equal({ "value" => "Vinyl", "count" => 3 }, stats["top_formats"].first)
  end

  test "decades are listed oldest first for the chart" do
    get api_profile_url

    assert_equal [ 1950, 1970 ], json["stats"]["decades"].map { |d| d["value"] }
  end

  test "top artists are ordered by how many releases they have" do
    get api_profile_url

    artists = json["stats"]["top_artists"]
    assert_equal 4, artists.size
    assert_equal artists.map { |a| a["count"] }.sort.reverse, artists.map { |a| a["count"] }
  end

  test "last_sync is the finish time of the last completed run" do
    get api_profile_url

    assert_equal sync_runs(:completed).finished_at.iso8601(3), Time.zone.parse(json["last_sync"]).iso8601(3)
  end

  test "last_sync ignores runs that failed or are still going" do
    SyncRun.delete_all
    SyncRun.create!(status: "failed", finished_at: Time.current)

    get api_profile_url

    assert_nil json["last_sync"]
  end
end
