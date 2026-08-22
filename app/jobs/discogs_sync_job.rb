class DiscogsSyncJob < ApplicationJob
  queue_as :default

  def perform(sync_run_id)
    sync_run = SyncRun.find(sync_run_id)
    return unless sync_run.running? || sync_run.status == "pending"

    Discogs::Sync.new(sync_run: sync_run).call
  rescue Discogs::Error
    # Already recorded on the SyncRun; no point retrying a bad token or a
    # private profile on a schedule.
    nil
  end
end
