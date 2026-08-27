require "test_helper"

class ItemsQueryTest < ActiveSupport::TestCase
  # Positional, not a keyword: `query(sort: "x")` must land in params, and a
  # `scope:` keyword would swallow the whole hash instead.
  def query(params = {}, scope = CollectionItem.all)
    ItemsQuery.new(scope, params)
  end

  def titles(query)
    query.results.map { |item| item.release.title }
  end

  # --- filtering ---

  test "no filters returns the whole list" do
    assert_equal CollectionItem.count, query.total
  end

  test "filters compose with each other" do
    assert_equal 1, query(genre: "Rock", decade: "1970", q: "unknown").total
    assert_equal 0, query(genre: "Jazz", decade: "1970").total
  end

  test "search reaches through the join to the release" do
    assert_equal [ "Kind Of Blue" ], titles(query(q: "miles"))
  end

  test "filtered is the unpaginated scope, so facet counts ignore the page" do
    scoped = query(per_page: 1)

    assert_equal 1, scoped.results.size
    assert_equal CollectionItem.count, scoped.filtered.count
  end

  test "the wantlist runs through the same pipeline" do
    scoped = query({ genre: "Electronic" }, WantlistItem.all)

    assert_equal [ "Selected Ambient Works 85-92" ], titles(scoped)
  end

  # --- sorting ---

  test "defaults to newest addition first" do
    assert_equal "added_desc", query.sort
    assert_equal "Clube Da Esquina", titles(query).first
  end

  test "falls back to the default when the sort key is unknown" do
    assert_equal "added_desc", query(sort: "ORDER BY 1; DROP TABLE releases").sort
    assert_equal titles(query), titles(query(sort: "inexistente"))
  end

  test "added_asc is the reverse order" do
    assert_equal titles(query(sort: "added_desc")).reverse, titles(query(sort: "added_asc"))
  end

  # Binary collation would sort lowercase "aardvark" after "Joy Division".
  test "artist sorts are case-insensitive" do
    artists = query(sort: "artist_asc").results.map { |item| item.release.artist }

    assert_equal "aardvark coletivo", artists.first
    assert_equal artists.sort_by(&:downcase), artists
  end

  test "artist_desc reverses the case-insensitive order" do
    assert_equal "aardvark coletivo", query(sort: "artist_desc").results.map { |i| i.release.artist }.last
  end

  test "title sort is case-insensitive too" do
    assert_equal [ "Clube Da Esquina", "demos caseiras", "Kind Of Blue", "Unknown Pleasures" ],
                 titles(query(sort: "title_asc"))
  end

  test "year sorts push releases without a year to the end in both directions" do
    assert_equal "demos caseiras", titles(query(sort: "year_desc")).last
    assert_equal "demos caseiras", titles(query(sort: "year_asc")).last

    assert_equal [ 1979, 1972, 1959 ], query(sort: "year_desc").results.map { |i| i.release.year }.compact
    assert_equal [ 1959, 1972, 1979 ], query(sort: "year_asc").results.map { |i| i.release.year }.compact
  end

  test "rating_desc puts the highest rating first" do
    assert_equal 5, query(sort: "rating_desc").results.first.rating
  end

  # --- pagination ---

  test "per_page defaults and is capped" do
    assert_equal ItemsQuery::DEFAULT_PER_PAGE, query.per_page
    assert_equal ItemsQuery::DEFAULT_PER_PAGE, query(per_page: "0").per_page
    assert_equal ItemsQuery::DEFAULT_PER_PAGE, query(per_page: "-5").per_page
    assert_equal ItemsQuery::DEFAULT_PER_PAGE, query(per_page: "abacaxi").per_page
    assert_equal ItemsQuery::MAX_PER_PAGE, query(per_page: "5000").per_page
    assert_equal 10, query(per_page: "10").per_page
  end

  test "page is never below one" do
    assert_equal 1, query.page
    assert_equal 1, query(page: "0").page
    assert_equal 1, query(page: "-3").page
    assert_equal 2, query(page: "2").page
  end

  test "pages do not overlap and cover the whole list" do
    first = titles(query(per_page: 2, page: 1))
    second = titles(query(per_page: 2, page: 2))

    assert_equal 2, first.size
    assert_equal 2, second.size
    assert_empty first & second
    assert_equal titles(query).sort, (first + second).sort
  end

  test "a page past the end is empty rather than an error" do
    assert_empty query(page: "99").results
  end

  test "total_pages rounds up and is at least one" do
    assert_equal 2, query(per_page: 3).total_pages
    assert_equal 1, query(per_page: 4).total_pages
    assert_equal 1, query(q: "nada-encontra-isso").total_pages
  end
end
