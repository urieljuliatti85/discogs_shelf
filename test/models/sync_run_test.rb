require "test_helper"

class SyncRunTest < ActiveSupport::TestCase
  test "rejects a status outside the known set" do
    assert_not SyncRun.new(status: "meio-termo").valid?
    SyncRun::STATUSES.each { |status| assert SyncRun.new(status: status).valid?, status }
  end

  test "current is the most recently created run" do
    newest = SyncRun.create!(status: "pending", created_at: 1.minute.ago)
    SyncRun.create!(status: "completed", created_at: 3.hours.ago)

    assert_equal newest, SyncRun.current
  end

  test "running? covers pending and running" do
    SyncRun.delete_all
    assert_not SyncRun.running?

    run = SyncRun.create!(status: "pending")
    assert SyncRun.running?

    run.update!(status: "running")
    assert SyncRun.running?

    run.update!(status: "completed")
    assert_not SyncRun.running?
  end

  # Without this window a job killed mid-flight would block every later sync.
  test "running? ignores runs older than an hour" do
    SyncRun.delete_all
    SyncRun.create!(status: "running", created_at: 61.minutes.ago)

    assert_not SyncRun.running?
  end

  test "progress is a clamped percentage" do
    run = SyncRun.new(synced_count: 0, total_count: 0)
    assert_equal 0, run.progress, "sem total não dá para calcular"

    run.total_count = 200
    run.synced_count = 50
    assert_equal 25, run.progress

    # A page can carry more rows than the reported total; never report >100.
    run.synced_count = 300
    assert_equal 100, run.progress
  end

  test "start! marks the run running and stamps the start" do
    run = SyncRun.create!(status: "pending")

    freeze_time do
      run.start!(stage: "collection")

      assert_equal "running", run.status
      assert_equal "collection", run.stage
      assert_equal Time.current, run.started_at
      assert_predicate run, :running?
    end
  end

  test "finish! completes the run" do
    run = SyncRun.create!(status: "running")
    run.finish!

    assert_predicate run, :completed?
    assert_equal "done", run.stage
    assert_not_nil run.finished_at
  end

  test "fail! records a truncated message and closes the run" do
    run = SyncRun.create!(status: "running")
    run.fail!("x" * 1200)

    assert_predicate run, :failed?
    assert_equal 1000, run.error_message.length
    assert_not_nil run.finished_at
  end
end
