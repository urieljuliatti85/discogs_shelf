require "test_helper"

class ReleaseTest < ActiveSupport::TestCase
  test "fixtures round-trip the JSON array columns" do
    release = releases(:clube_da_esquina)

    assert_equal [ "Rock", "Latin" ], release.genres
    assert_equal [ "MPB" ], release.styles
    assert_equal "Vinyl", release.formats.first["name"]
    assert_equal [ "Milton Nascimento", "Lô Borges" ], release.artists
  end

  test "requires a unique discogs_id" do
    duplicate = Release.new(discogs_id: releases(:kind_of_blue).discogs_id, title: "T", artist: "A")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :discogs_id
  end

  # --- search ---

  test "search matches title, artist, label and catalogue number" do
    assert_includes Release.search("unknown"), releases(:unknown_pleasures)
    assert_includes Release.search("miles"), releases(:kind_of_blue)
    assert_includes Release.search("factory"), releases(:unknown_pleasures)
    assert_includes Release.search("CL 1355"), releases(:kind_of_blue)
  end

  test "search returns everything when the term is blank" do
    assert_equal Release.count, Release.search("").count
    assert_equal Release.count, Release.search(nil).count
    assert_equal Release.count, Release.search("   ").count
  end

  test "search treats a LIKE wildcard as a literal, not as match-everything" do
    assert_empty Release.search("%")
    assert_empty Release.search("_")
  end

  # --- facet filters ---

  test "with_genre matches a whole element, not a substring" do
    assert_equal 3, Release.with_genre("Rock").count
    assert_empty Release.with_genre("Roc")
    assert_empty Release.with_genre("ock")
  end

  test "with_genre matches any position in the array" do
    # "Electronic" is second on unknown_pleasures and first on selected_ambient.
    assert_equal [ releases(:unknown_pleasures), releases(:selected_ambient) ].map(&:id).sort,
                 Release.with_genre("Electronic").pluck(:id).sort
  end

  test "with_style matches a whole element" do
    assert_equal [ releases(:selected_ambient).id ], Release.with_style("Ambient").pluck(:id)
    assert_empty Release.with_style("Ambien")
  end

  test "with_format reads the name out of the format objects" do
    assert_equal 3, Release.with_format("Vinyl").count
    assert_equal [ releases(:selected_ambient).id ], Release.with_format("CD").pluck(:id)
    assert_empty Release.with_format("LP") # a description, not a format name
  end

  test "with_decade spans the ten years starting at the given year" do
    assert_equal [ releases(:clube_da_esquina).id, releases(:unknown_pleasures).id ].sort,
                 Release.with_decade("1970").pluck(:id).sort
    assert_equal [ releases(:kind_of_blue).id ], Release.with_decade(1950).pluck(:id)
  end

  test "filters are no-ops when the value is blank" do
    assert_equal Release.count, Release.with_genre(nil).count
    assert_equal Release.count, Release.with_style("").count
    assert_equal Release.count, Release.with_format(nil).count
    assert_equal Release.count, Release.with_decade("").count
  end

  # --- facet counts ---

  test "facet counts distinct values across a scope, most frequent first" do
    genres = Release.facet(:genres)

    assert_equal({ value: "Rock", count: 3 }, genres.first)
    assert_equal 4, genres.size
    assert_equal [ "Electronic", "Jazz", "Latin", "Rock" ], genres.map { |g| g[:value] }.sort
  end

  test "facet respects the scope it is given" do
    scope = Release.with_genre("Electronic")

    assert_equal [ { value: "Electronic", count: 2 }, { value: "Rock", count: 1 } ],
                 Release.facet(:genres, scope: scope)
  end

  test "facet pulls the name out of format objects rather than the raw JSON" do
    formats = Release.facet(:formats)

    assert_equal({ value: "Vinyl", count: 3 }, formats.first)
    assert_equal [ "CD", "Cassette", "Vinyl" ], formats.map { |f| f[:value] }.sort
  end

  test "facet only accepts whitelisted columns" do
    assert_raises(KeyError) { Release.facet(:artists) }
    assert_raises(KeyError) { Release.facet("title; DROP TABLE releases") }
  end

  test "facet ties break alphabetically" do
    values = Release.facet(:styles).select { |s| s[:count] == 1 }.map { |s| s[:value] }

    assert_equal values.sort, values
  end

  # --- details cache ---

  test "details are stale when never fetched" do
    assert_predicate releases(:unknown_pleasures), :details_stale?
  end

  test "details are stale when older than 30 days" do
    release = releases(:unknown_pleasures)

    release.update!(details: { "tracklist" => [] }, details_fetched_at: 31.days.ago)
    assert_predicate release, :details_stale?

    release.update!(details_fetched_at: 29.days.ago)
    assert_not_predicate release, :details_stale?
  end

  test "details are stale when the payload is empty even if recently fetched" do
    release = releases(:unknown_pleasures)
    release.update!(details: nil, details_fetched_at: Time.current)

    assert_predicate release, :details_stale?
  end

  test "discogs_url points at the public release page" do
    assert_equal "https://www.discogs.com/release/1001", releases(:unknown_pleasures).discogs_url
  end

  test "marketplace_url points at the release listings" do
    assert_equal "https://www.discogs.com/sell/release/1001", releases(:unknown_pleasures).marketplace_url
  end

  test "destroying a release takes its list rows with it" do
    release = releases(:kind_of_blue)

    assert_difference [ "CollectionItem.count", "WantlistItem.count" ], -1 do
      release.destroy!
    end
  end
end
