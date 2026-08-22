# Shared filtering/sorting/pagination for the collection and the wantlist.
class ItemsQuery
  SORTS = {
    "added_desc"  => { date_added: :desc, id: :desc },
    "added_asc"   => { date_added: :asc, id: :asc },
    "artist_asc"  => nil,
    "artist_desc" => nil,
    "title_asc"   => nil,
    "year_desc"   => nil,
    "year_asc"    => nil,
    "rating_desc" => { rating: :desc }
  }.freeze

  DEFAULT_PER_PAGE = 48
  MAX_PER_PAGE = 100

  attr_reader :params

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def releases
    Release.where(id: filtered.select(:release_id))
  end

  # Filtered but not paginated, used for facet counts.
  def filtered
    scope = @scope.joins(:release)
    scope = scope.merge(Release.search(params[:q]))
    scope = scope.merge(Release.with_genre(params[:genre]))
    scope = scope.merge(Release.with_style(params[:style]))
    scope = scope.merge(Release.with_format(params[:media]))
    scope = scope.merge(Release.with_decade(params[:decade]))
    scope
  end

  def results
    sorted = apply_sort(filtered)
    sorted.includes(:release).offset((page - 1) * per_page).limit(per_page)
  end

  def total
    @total ||= filtered.count
  end

  def total_pages
    return 1 if total.zero?
    (total / per_page.to_f).ceil
  end

  def page
    [ params[:page].to_i, 1 ].max
  end

  def per_page
    value = params[:per_page].to_i
    return DEFAULT_PER_PAGE if value <= 0
    [ value, MAX_PER_PAGE ].min
  end

  def sort
    key = params[:sort].to_s
    SORTS.key?(key) ? key : "added_desc"
  end

  private

  def apply_sort(scope)
    case sort
    when "artist_asc"  then scope.order("releases.artist COLLATE NOCASE ASC, releases.year ASC")
    when "artist_desc" then scope.order("releases.artist COLLATE NOCASE DESC, releases.year ASC")
    when "title_asc"   then scope.order("releases.title COLLATE NOCASE ASC")
    when "year_desc"   then scope.order(Arel.sql("releases.year IS NULL, releases.year DESC"))
    when "year_asc"    then scope.order(Arel.sql("releases.year IS NULL, releases.year ASC"))
    else scope.order(SORTS.fetch(sort))
    end
  end
end
