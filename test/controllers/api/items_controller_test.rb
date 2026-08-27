require "test_helper"

class Api::ItemsControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  test "returns the collection with pagination, sort and facets" do
    get api_collection_url

    assert_response :success
    assert_equal CollectionItem.count, json["items"].size
    assert_equal "added_desc", json["sort"]
    assert_equal({ "page" => 1, "per_page" => 48, "total" => 4, "total_pages" => 1 }, json["pagination"])
    assert_equal %w[genres styles formats decades], json["facets"].keys
  end

  test "each item carries the release summary plus its list fields" do
    get api_collection_url, params: { q: "unknown" }

    item = json["items"].sole
    assert_equal "collection", item["list"]
    assert_equal "Unknown Pleasures", item["title"]
    assert_equal "Joy Division", item["artist"]
    assert_equal 5, item["rating"]
    assert_equal "Vinyl, LP, Album", item["format_summary"]
  end

  test "the wantlist is served by the same action from another route" do
    get api_wantlist_url

    assert_response :success
    assert_equal WantlistItem.count, json["items"].size
    assert_equal [ "wantlist" ], json["items"].map { |i| i["list"] }.uniq
  end

  test "filters narrow the list" do
    get api_collection_url, params: { genre: "Jazz" }

    assert_equal [ "Kind Of Blue" ], json["items"].map { |i| i["title"] }
  end

  test "facet counts reflect the other active filters" do
    get api_collection_url
    unfiltered = json["facets"]["genres"].find { |g| g["value"] == "Rock" }["count"]

    get api_collection_url, params: { decade: "1970" }
    filtered = json["facets"]["genres"].find { |g| g["value"] == "Rock" }["count"]

    assert_equal 3, unfiltered
    assert_equal 2, filtered
  end

  test "decade facets come back as numbers, newest first" do
    get api_collection_url

    decades = json["facets"]["decades"]
    assert_equal [ 1970, 1950 ], decades.map { |d| d["value"] }
    assert_equal 2, decades.first["count"]
  end

  test "a filter that matches nothing returns an empty list, not an error" do
    get api_collection_url, params: { genre: "Sertanejo" }

    assert_response :success
    assert_empty json["items"]
    assert_equal 0, json["pagination"]["total"]
    assert_equal 1, json["pagination"]["total_pages"]
  end

  test "sorting is driven by the query string" do
    get api_collection_url, params: { sort: "artist_asc" }

    assert_equal "aardvark coletivo", json["items"].first["artist"]
    assert_equal "artist_asc", json["sort"]
  end

  test "an unknown sort falls back instead of failing" do
    get api_collection_url, params: { sort: "; DROP TABLE releases" }

    assert_response :success
    assert_equal "added_desc", json["sort"]
    assert_equal 5, Release.count
  end

  test "per_page is capped by the server" do
    get api_collection_url, params: { per_page: 9999 }

    assert_equal ItemsQuery::MAX_PER_PAGE, json["pagination"]["per_page"]
  end

  test "paginates" do
    get api_collection_url, params: { per_page: 2, page: 2 }

    assert_equal 2, json["items"].size
    assert_equal 2, json["pagination"]["total_pages"]
  end

  test "unknown query parameters are ignored" do
    get api_collection_url, params: { admin: true, order: "rand()" }

    assert_response :success
    assert_equal CollectionItem.count, json["items"].size
  end

  test "never calls Discogs" do
    # The network guard in test_helper raises on any real call, so reaching a
    # successful response is the assertion.
    get api_collection_url, params: { q: "miles", genre: "Jazz", sort: "year_asc" }

    assert_response :success
  end
end
