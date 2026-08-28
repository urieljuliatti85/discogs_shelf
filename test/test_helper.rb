if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "net/http"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

# Nothing in the suite is allowed to reach api.discogs.com. Tests that need a
# response install one through DiscogsStubs#stub_discogs, which replaces this.
Net::HTTP.define_singleton_method(:start) do |*args, **_kwargs, &_block|
  raise "Chamada HTTP real bloqueada no teste (#{args.first}). Use stub_discogs."
end

# dotenv loads the developer's real .env in the test environment too, so pin
# the credentials the suite assumes instead of inheriting whatever is on disk.
ENV["DISCOGS_USERNAME"] = "colecionador"
ENV["DISCOGS_TOKEN"] = "token-de-teste"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper
    include StubHelpers
    include DiscogsStubs

    fixtures :all

    # RATE_LIMIT_STORE is a single MemoryStore shared by the whole process
    # (see Api::BaseController), so leftover counts from one test would bleed
    # into the next one otherwise.
    setup { Api::BaseController::RATE_LIMIT_STORE.clear }

    # The client reads ENV at construction, so the "not configured" paths need
    # the variable actually gone for the duration of the block.
    def without_env(*keys)
      saved = keys.index_with { |key| ENV[key] }
      keys.each { |key| ENV.delete(key) }
      yield
    ensure
      saved.each { |key, value| ENV[key] = value }
    end
  end
end
