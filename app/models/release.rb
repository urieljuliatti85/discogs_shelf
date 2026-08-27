class Release < ApplicationRecord
  has_one :collection_item, dependent: :destroy
  has_one :wantlist_item, dependent: :destroy

  validates :discogs_id, presence: true, uniqueness: true
  validates :title, :artist, presence: true

  scope :search, ->(term) {
    return all if term.blank?
    q = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("releases.title LIKE :q OR releases.artist LIKE :q OR releases.label LIKE :q OR releases.catno LIKE :q", q: q)
  }

  # SQLite's json_each lets us match a single element of the stored JSON array
  # instead of doing a substring match on the serialized text.
  scope :with_genre, ->(genre) {
    return all if genre.blank?
    where("EXISTS (SELECT 1 FROM json_each(releases.genres) WHERE json_each.value = ?)", genre)
  }

  scope :with_style, ->(style) {
    return all if style.blank?
    where("EXISTS (SELECT 1 FROM json_each(releases.styles) WHERE json_each.value = ?)", style)
  }

  scope :with_format, ->(format) {
    return all if format.blank?
    where("EXISTS (SELECT 1 FROM json_each(releases.formats) WHERE json_extract(json_each.value, '$.name') = ?)", format)
  }

  scope :with_decade, ->(decade) {
    return all if decade.blank?
    start_year = decade.to_i
    where(year: start_year..(start_year + 9))
  }

  # JSON array columns that can be faceted, mapped to the expression that pulls
  # a display value out of one element. Interpolating anything outside this
  # table into the query below would be an injection point.
  FACETS = {
    genres:  { column: "genres",  path: "json_each.value" },
    styles:  { column: "styles",  path: "json_each.value" },
    formats: { column: "formats", path: "json_extract(json_each.value, '$.name')" }
  }.freeze

  # Distinct values of a JSON array column across the given scope, with counts.
  def self.facet(name, scope: all)
    facet = FACETS.fetch(name.to_sym)
    path = facet[:path]
    column = facet[:column]

    # The alias must not be `value`: json_each already exposes a column by that
    # name, and SQLite would group by the raw JSON element instead.
    sql = <<~SQL
      SELECT #{path} AS facet_value, COUNT(*) AS facet_count
      FROM (#{scope.select(:id, column).to_sql}) AS r, json_each(r.#{column})
      WHERE #{path} IS NOT NULL AND #{path} != ''
      GROUP BY facet_value
      ORDER BY facet_count DESC, facet_value ASC
    SQL

    connection.select_all(sql).map { |row| { value: row["facet_value"], count: row["facet_count"] } }
  end

  def discogs_url
    "https://www.discogs.com/release/#{discogs_id}"
  end

  def marketplace_url
    "https://www.discogs.com/sell/release/#{discogs_id}"
  end

  def details_stale?
    details.blank? || details_fetched_at.nil? || details_fetched_at < 30.days.ago
  end
end
