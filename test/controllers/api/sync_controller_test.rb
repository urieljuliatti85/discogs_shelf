require "test_helper"

class Api::SyncControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  test "reports never_run before the first sync" do
    SyncRun.delete_all

    get api_sync_url

    assert_response :success
    assert_equal({ "status" => "never_run" }, json)
  end

  test "reports the most recent run with its progress" do
    SyncRun.create!(status: "running", stage: "collection", synced_count: 30, total_count: 120)

    get api_sync_url

    assert_equal "running", json["status"]
    assert_equal "collection", json["stage"]
    assert_equal 25, json["progress"]
    assert_equal 120, json["total_count"]
  end

  test "surfaces the error message of a failed run" do
    SyncRun.create!(status: "failed", error_message: "token inválido")

    get api_sync_url

    assert_equal "failed", json["status"]
    assert_equal "token inválido", json["error_message"]
  end

  test "starting a sync creates a run and enqueues the job" do
    assert_difference "SyncRun.count", 1 do
      assert_enqueued_with(job: DiscogsSyncJob) do
        post api_sync_url
      end
    end

    assert_response :created
    assert_equal "pending", json["status"]
    assert_equal SyncRun.current.id, json["id"]
  end

  test "refuses to start a second run while one is in flight" do
    running = SyncRun.create!(status: "running")

    assert_no_difference "SyncRun.count" do
      assert_no_enqueued_jobs do
        post api_sync_url
      end
    end

    assert_response :accepted
    assert_equal running.id, json["id"]
  end

  test "a stalled run older than an hour no longer blocks a new sync" do
    SyncRun.create!(status: "running", created_at: 2.hours.ago)

    assert_difference "SyncRun.count", 1 do
      post api_sync_url
    end

    assert_response :created
  end

  test "refuses to sync when no username is configured" do
    without_env("DISCOGS_USERNAME") do
      assert_no_difference "SyncRun.count" do
        post api_sync_url
      end
    end

    assert_response :service_unavailable
    assert_equal "not_configured", json["error"]
    assert_match "DISCOGS_USERNAME", json["message"]
  end
end
