require "test_helper"

class Discogs::ClientTest < ActiveSupport::TestCase
  # Retries and throttling both sleep; no test should pay for that.
  def client(**options)
    Discogs::Client.new(**{ username: "colecionador", token: "segredo" }.merge(options)).tap do |c|
      c.define_singleton_method(:sleep) { |seconds| (@slept ||= []) << seconds }
      c.define_singleton_method(:slept) { @slept || [] }
    end
  end

  test "configured? only needs a username, authenticated? needs a token" do
    assert_predicate client, :configured?
    assert_predicate client, :authenticated?

    assert_predicate client(token: nil), :configured?
    assert_not_predicate client(token: nil), :authenticated?

    assert_not_predicate client(username: nil), :configured?
  end

  test "blank credentials are treated as absent" do
    assert_not_predicate client(username: ""), :configured?
    assert_not_predicate client(token: ""), :authenticated?
  end

  test "collection and wantlist require a username" do
    subject = client(username: nil)

    assert_raises(Discogs::NotConfigured) { subject.collection_page }
    assert_raises(Discogs::NotConfigured) { subject.wantlist_page }
  end

  test "identity requires a token" do
    assert_raises(Discogs::NotConfigured) { client(token: nil).identity }
  end

  # --- requests ---

  test "sends the token, user agent and JSON accept header" do
    requests = stub_discogs([ %r{/users/colecionador$}, discogs_response({ "username" => "colecionador" }) ]) do
      client.profile
    end

    request = requests.sole
    assert_equal "Discogs token=segredo", request["Authorization"]
    assert_equal Discogs::Client::USER_AGENT, request["User-Agent"]
    assert_equal "application/json", request["Accept"]
  end

  test "omits the Authorization header when there is no token" do
    requests = stub_discogs([ /users/, discogs_response({}) ]) { client(token: nil).profile }

    assert_nil requests.sole["Authorization"]
  end

  test "escapes the username so it cannot break out of the path" do
    requests = stub_discogs([ %r{/users/\.\.%2F\.\.%2Fsecret}, discogs_response({}) ]) do
      client(username: "../../secret").profile
    end

    assert_equal "/users/..%2F..%2Fsecret", requests.sole.uri.path
  end

  test "escapes spaces in the username (CGI.escape, so as +)" do
    requests = stub_discogs([ %r{/users/nome\+com\+espaco}, discogs_response({}) ]) do
      client(username: "nome com espaco").profile
    end

    assert_equal "/users/nome+com+espaco", requests.sole.uri.path
  end

  test "asks for full pages of the collection, newest first" do
    requests = stub_discogs([ %r{/collection/folders/0/releases}, discogs_response(collection_page([])) ]) do
      client.collection_page
    end

    url = requests.sole.uri.to_s
    assert_includes url, "per_page=100"
    assert_includes url, "sort=added"
    assert_includes url, "sort_order=desc"
  end

  test "coerces the release id so it cannot inject a path" do
    requests = stub_discogs([ %r{/releases/0$}, discogs_response({}) ]) do
      client.release("../../secret")
    end

    assert_equal "/releases/0", requests.sole.uri.path
  end

  # --- status handling ---

  test "returns the parsed body on success" do
    stub_discogs([ /users/, discogs_response({ "num_collection" => 12 }) ]) do
      assert_equal({ "num_collection" => 12 }, client.profile)
    end
  end

  test "401 and 403 become Unauthorized" do
    [ 401, 403 ].each do |code|
      stub_discogs([ /users/, discogs_response({}, code: code) ]) do
        error = assert_raises(Discogs::Unauthorized) { client.profile }
        assert_match "DISCOGS_TOKEN", error.message
      end
    end
  end

  test "404 becomes NotFound" do
    stub_discogs([ /releases/, discogs_response({}, code: 404) ]) do
      assert_raises(Discogs::NotFound) { client.release(1) }
    end
  end

  test "an unexpected status becomes a generic error carrying the body" do
    stub_discogs([ /users/, discogs_response("explodiu", code: 500) ]) do
      error = assert_raises(Discogs::Error) { client.profile }
      assert_match "500", error.message
      assert_match "explodiu", error.message
    end
  end

  test "every Discogs error is catchable as Discogs::Error" do
    assert_operator Discogs::Unauthorized, :<, Discogs::Error
    assert_operator Discogs::NotFound, :<, Discogs::Error
    assert_operator Discogs::RateLimited, :<, Discogs::Error
    assert_operator Discogs::NotConfigured, :<, Discogs::Error
  end

  # --- retries and throttling ---

  test "retries a 429 with growing backoff and then gives up" do
    subject = client
    responses = Array.new(5) { [ /users/, discogs_response({}, code: 429) ] }

    stub_discogs(*responses) do
      assert_raises(Discogs::RateLimited) { subject.profile }
    end

    assert_equal [ 2, 4, 8 ], subject.slept, "deve dormir mais a cada tentativa"
  end

  test "a retried request eventually succeeds" do
    subject = client

    stub_discogs(
      [ /users/, discogs_response({}, code: 429) ],
      [ /users/, discogs_response({ "username" => "ok" }) ]
    ) do
      assert_equal({ "username" => "ok" }, subject.profile)
    end

    assert_equal [ 2 ], subject.slept
  end

  test "retries network failures too" do
    subject = client
    attempts = 0

    flaky = Object.new
    flaky.define_singleton_method(:request) do |_request|
      attempts += 1
      raise Net::ReadTimeout if attempts == 1
      DiscogsStubs::Response.new(code: "200", body: "{}", headers: {})
    end

    stub_singleton(Net::HTTP, :start, ->(*_a, **_k, &block) { block.call(flaky) }) do
      assert_equal({}, subject.profile)
    end
    assert_equal 2, attempts
  end

  test "gives up on a network failure after the retry budget" do
    subject = client
    always_failing = Object.new
    always_failing.define_singleton_method(:request) { |_r| raise Net::OpenTimeout }

    stub_singleton(Net::HTTP, :start, ->(*_a, **_k, &block) { block.call(always_failing) }) do
      error = assert_raises(Discogs::Error) { subject.profile }
      assert_match "Erro de rede", error.message
    end
  end

  test "pauses when the rate limit header is nearly exhausted" do
    subject = client

    stub_discogs([ /users/, discogs_response({}, remaining: 2) ]) { subject.profile }
    assert_equal [ 2 ], subject.slept
  end

  test "does not pause while there is headroom, or when the header is missing" do
    subject = client

    stub_discogs([ /users/, discogs_response({}, remaining: 40) ]) { subject.profile }
    stub_discogs([ /users/, discogs_response({}, remaining: nil) ]) { subject.profile }

    assert_empty subject.slept
  end

  # --- pagination ---

  test "each_page walks every page and yields the items" do
    subject = client
    seen = []

    stub_discogs(
      [ /page=1/, discogs_response(collection_page([ { "instance_id" => 1 } ], page: 1, pages: 2, total: 2)) ],
      [ /page=2/, discogs_response(collection_page([ { "instance_id" => 2 } ], page: 2, pages: 2, total: 2)) ]
    ) do
      subject.each_page(:collection) { |items, _| seen.concat(items) }
    end

    assert_equal [ 1, 2 ], seen.map { |item| item["instance_id"] }
  end

  test "each_page reports the totals once, from the first page" do
    subject = client
    paginations = []

    stub_discogs(
      [ /page=1/, discogs_response(collection_page([ {} ], page: 1, pages: 2, total: 7)) ],
      [ /page=2/, discogs_response(collection_page([ {} ], page: 2, pages: 2, total: 7)) ]
    ) do
      subject.each_page(:collection, on_pagination: ->(p) { paginations << p }) { |_, _| }
    end

    assert_equal [ 7 ], paginations.map { |p| p["items"] }
  end

  test "each_page reads the wants key for the wantlist" do
    subject = client
    seen = []

    stub_discogs([ %r{/wants}, discogs_response(wantlist_page([ { "id" => 5 } ])) ]) do
      subject.each_page(:wantlist) { |items, _| seen.concat(items) }
    end

    assert_equal [ 5 ], seen.map { |item| item["id"] }
  end

  test "each_page stops on an empty page even when Discogs claims more" do
    subject = client
    pages = 0

    stub_discogs([ /page=1/, discogs_response(collection_page([], page: 1, pages: 9, total: 900)) ]) do
      subject.each_page(:collection) { |_, _| pages += 1 }
    end

    assert_equal 1, pages
  end
end
