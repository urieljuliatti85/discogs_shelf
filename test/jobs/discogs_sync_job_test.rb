require "test_helper"

class DiscogsSyncJobTest < ActiveSupport::TestCase
  def stubbed_discogs(collection_code: 200)
    stub_discogs(
      [ %r{/collection/}, discogs_response(collection_page([ collection_item(instance_id: 9001, release_id: 7001) ]), code: collection_code) ],
      [ %r{/wants}, discogs_response(wantlist_page([ wantlist_item(release_id: 7002) ])) ]
    ) { yield }
  end

  test "runs the sync for the given run" do
    sync_run = SyncRun.create!(status: "pending")

    stubbed_discogs { DiscogsSyncJob.perform_now(sync_run.id) }

    assert_predicate sync_run.reload, :completed?
    assert_not_nil CollectionItem.find_by(instance_id: 9001)
  end

  test "ignores a run that already finished" do
    sync_run = sync_runs(:completed)

    # No stub installed: any HTTP call would raise instead of passing silently.
    assert_nothing_raised { DiscogsSyncJob.perform_now(sync_run.id) }
    assert_equal "completed", sync_run.reload.status
  end

  # Retrying a bad token or a private profile on a schedule accomplishes nothing.
  test "swallows Discogs errors after recording them on the run" do
    sync_run = SyncRun.create!(status: "pending")

    assert_nothing_raised do
      stub_discogs([ %r{/collection/}, discogs_response({}, code: 401) ]) do
        DiscogsSyncJob.perform_now(sync_run.id)
      end
    end

    assert_predicate sync_run.reload, :failed?
    assert_match "Unauthorized", sync_run.error_message
  end

  test "enqueues on the default queue" do
    assert_enqueued_with(job: DiscogsSyncJob, queue: "default") do
      DiscogsSyncJob.perform_later(1)
    end
  end
end
