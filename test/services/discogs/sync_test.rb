require "test_helper"

class Discogs::SyncTest < ActiveSupport::TestCase
  def client
    @client ||= Discogs::Client.new(username: "colecionador", token: "segredo").tap do |c|
      c.define_singleton_method(:sleep) { |_seconds| nil }
    end
  end

  def run_sync(collection: [], wantlist: [], sync_run: nil)
    result = nil
    stub_discogs(
      [ %r{/collection/folders/0/releases}, discogs_response(collection_page(collection)) ],
      [ %r{/wants}, discogs_response(wantlist_page(wantlist)) ]
    ) do
      result = Discogs::Sync.new(client: client, sync_run: sync_run).call
    end
    result
  end

  # --- importing ---

  test "imports collection items and the releases behind them" do
    run_sync(collection: [ collection_item(instance_id: 9001, release_id: 7001, title: "Novo Disco") ])

    release = Release.find_by(discogs_id: 7001)
    assert_equal "Novo Disco", release.title
    assert_equal [ "Rock" ], release.genres

    item = CollectionItem.find_by(instance_id: 9001)
    assert_equal release, item.release
    assert_equal 1, item.folder_id
    assert_equal Time.zone.parse("2024-03-01T10:00:00-08:00"), item.date_added
  end

  test "imports wantlist items" do
    run_sync(
      collection: [ collection_item(instance_id: 9001, release_id: 7001) ],
      wantlist: [ wantlist_item(release_id: 7002, rating: 4, notes: "achar barato") ]
    )

    item = WantlistItem.find_by(release: Release.find_by(discogs_id: 7002))
    assert_equal 4, item.rating
    assert_equal "achar barato", item.notes
  end

  test "collection notes come back as an array" do
    item = collection_item(instance_id: 9001, release_id: 7001)
    item["notes"] = [ { "field_id" => 3, "value" => "Vinil colorido" } ]

    run_sync(collection: [ item ])

    assert_equal [ { "field_id" => 3, "value" => "Vinil colorido" } ],
                 CollectionItem.find_by(instance_id: 9001).notes
  end

  test "updates an existing release instead of duplicating it" do
    existing = releases(:unknown_pleasures)

    run_sync(
      collection: [ collection_item(instance_id: 5001, release_id: existing.discogs_id, title: "Título Novo") ],
      wantlist: [ wantlist_item(release_id: releases(:selected_ambient).discogs_id) ]
    )

    assert_equal 1, Release.where(discogs_id: existing.discogs_id).count
    assert_equal "Título Novo", existing.reload.title
  end

  test "reuses the collection row for a known instance_id" do
    existing = collection_items(:unknown_pleasures)

    run_sync(collection: [
      collection_item(instance_id: existing.instance_id, release_id: releases(:unknown_pleasures).discogs_id, rating: 1)
    ])

    assert_equal 1, existing.reload.rating
    assert_equal existing.id, CollectionItem.find_by(instance_id: existing.instance_id).id
  end

  test "skips items with no basic_information rather than blowing up" do
    run_sync(collection: [
      { "instance_id" => 9001, "basic_information" => nil },
      collection_item(instance_id: 9002, release_id: 7001)
    ])

    assert_nil CollectionItem.find_by(instance_id: 9001)
    assert_not_nil CollectionItem.find_by(instance_id: 9002)
  end

  test "an unparseable date_added becomes nil" do
    item = collection_item(instance_id: 9001, release_id: 7001)
    item["date_added"] = "não é uma data"

    run_sync(collection: [ item ])

    assert_nil CollectionItem.find_by(instance_id: 9001).date_added
  end

  # --- mirroring ---

  test "removes collection rows Discogs no longer lists" do
    kept = collection_items(:unknown_pleasures)

    run_sync(
      collection: [ collection_item(instance_id: kept.instance_id, release_id: releases(:unknown_pleasures).discogs_id) ],
      wantlist: [ wantlist_item(release_id: releases(:selected_ambient).discogs_id) ]
    )

    assert_equal [ kept.instance_id ], CollectionItem.pluck(:instance_id)
  end

  test "removes wantlist rows Discogs no longer lists" do
    kept = releases(:selected_ambient)

    run_sync(
      collection: [ collection_item(instance_id: 5001, release_id: releases(:unknown_pleasures).discogs_id) ],
      wantlist: [ wantlist_item(release_id: kept.discogs_id) ]
    )

    assert_equal [ kept.id ], WantlistItem.pluck(:release_id)
  end

  test "deletes releases left behind by neither list" do
    run_sync(
      collection: [ collection_item(instance_id: 5001, release_id: releases(:unknown_pleasures).discogs_id) ],
      wantlist: [ wantlist_item(release_id: releases(:selected_ambient).discogs_id) ]
    )

    assert_equal [ releases(:selected_ambient).discogs_id, releases(:unknown_pleasures).discogs_id ].sort,
                 Release.pluck(:discogs_id).sort
  end

  # The guard matters: an empty response is far more likely to be an upstream
  # hiccup than a genuinely emptied collection, and wiping the DB is not
  # recoverable without another full sync.
  test "an empty response deletes nothing" do
    assert_no_difference [ "CollectionItem.count", "WantlistItem.count", "Release.count" ] do
      run_sync(collection: [], wantlist: [])
    end
  end

  # --- progress reporting ---

  test "records totals and progress on the sync run" do
    sync_run = SyncRun.create!(status: "pending")

    stub_discogs(
      [ %r{/collection/}, discogs_response(collection_page([ collection_item(instance_id: 9001, release_id: 7001) ], total: 1)) ],
      [ %r{/wants}, discogs_response(wantlist_page([ wantlist_item(release_id: 7002) ], total: 1)) ]
    ) do
      Discogs::Sync.new(client: client, sync_run: sync_run).call
    end

    assert_equal 2, sync_run.reload.total_count, "coleção + lista de desejos"
    assert_equal 2, sync_run.synced_count
    assert_equal 100, sync_run.progress
  end

  test "completes the run and stamps the finish" do
    sync_run = run_sync(collection: [ collection_item(instance_id: 9001, release_id: 7001) ])

    assert_predicate sync_run, :completed?
    assert_equal "done", sync_run.stage
    assert_not_nil sync_run.started_at
    assert_not_nil sync_run.finished_at
  end

  test "creates its own run when none is handed in" do
    assert_difference "SyncRun.count", 1 do
      run_sync(collection: [ collection_item(instance_id: 9001, release_id: 7001) ])
    end
  end

  test "walks every page of a long collection" do
    page_one = collection_page([ collection_item(instance_id: 9001, release_id: 7001) ], page: 1, pages: 2, total: 2)
    page_two = collection_page([ collection_item(instance_id: 9002, release_id: 7002) ], page: 2, pages: 2, total: 2)

    stub_discogs(
      [ %r{folders/0/releases\?page=1}, discogs_response(page_one) ],
      [ %r{folders/0/releases\?page=2}, discogs_response(page_two) ],
      [ %r{/wants}, discogs_response(wantlist_page([])) ]
    ) do
      Discogs::Sync.new(client: client).call
    end

    assert_equal [ 9001, 9002 ], CollectionItem.where(instance_id: [ 9001, 9002 ]).pluck(:instance_id).sort
  end

  # --- failure ---

  test "a failure marks the run failed and re-raises" do
    sync_run = SyncRun.create!(status: "pending")

    error = assert_raises(Discogs::Unauthorized) do
      stub_discogs([ %r{/collection/}, discogs_response({}, code: 401) ]) do
        Discogs::Sync.new(client: client, sync_run: sync_run).call
      end
    end

    assert_predicate sync_run.reload, :failed?
    assert_match "Discogs::Unauthorized", sync_run.error_message
    assert_match "DISCOGS_TOKEN", error.message
    assert_not_nil sync_run.finished_at
  end

  test "a failure partway through leaves the rows it already wrote" do
    stub_discogs(
      [ %r{/collection/}, discogs_response(collection_page([ collection_item(instance_id: 9001, release_id: 7001) ])) ],
      [ %r{/wants}, discogs_response({}, code: 500) ]
    ) do
      assert_raises(Discogs::Error) { Discogs::Sync.new(client: client).call }
    end

    assert_not_nil CollectionItem.find_by(instance_id: 9001)
  end
end
