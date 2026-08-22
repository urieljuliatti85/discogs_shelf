require "net/http"
require "uri"
require "json"

module Discogs
  # Thin wrapper over the Discogs REST API.
  #
  # Only needs a username for public profiles; a personal access token raises the
  # rate limit from 25 to 60 requests/minute and is required for private ones.
  class Client
    BASE_URL = "https://api.discogs.com".freeze
    USER_AGENT = "DiscogsShelf/1.0 +https://github.com/discogs-shelf".freeze
    PER_PAGE = 100
    MAX_RETRIES = 3

    attr_reader :username, :token

    def initialize(username: ENV["DISCOGS_USERNAME"], token: ENV["DISCOGS_TOKEN"])
      @username = username.presence
      @token = token.presence
    end

    def configured?
      username.present?
    end

    def authenticated?
      token.present?
    end

    # Verifies the token and returns the authenticated user's profile.
    def identity
      raise NotConfigured, "DISCOGS_TOKEN não está definido" unless authenticated?
      get("/oauth/identity")
    end

    def profile(user = username)
      get("/users/#{CGI.escape(user)}")
    end

    def collection_page(page: 1, per_page: PER_PAGE, folder_id: 0)
      require_username!
      get("/users/#{CGI.escape(username)}/collection/folders/#{folder_id}/releases",
          page: page, per_page: per_page, sort: "added", sort_order: "desc")
    end

    def wantlist_page(page: 1, per_page: PER_PAGE)
      require_username!
      get("/users/#{CGI.escape(username)}/wants", page: page, per_page: per_page)
    end

    def release(discogs_id)
      get("/releases/#{discogs_id.to_i}")
    end

    # Yields every item across all pages. `key` is "releases" or "wants".
    # Yields the pagination hash first via `on_pagination` so callers can report totals.
    def each_page(kind, on_pagination: nil)
      page = 1
      loop do
        body = kind == :wantlist ? wantlist_page(page: page) : collection_page(page: page)
        pagination = body["pagination"] || {}
        on_pagination&.call(pagination) if page == 1

        items = body[kind == :wantlist ? "wants" : "releases"] || []
        yield items, pagination

        pages = pagination["pages"].to_i
        break if page >= pages || items.empty?
        page += 1
      end
    end

    private

    def require_username!
      raise NotConfigured, "DISCOGS_USERNAME não está definido" unless configured?
    end

    def get(path, **params)
      uri = URI.join(BASE_URL, path)
      uri.query = URI.encode_www_form(params) if params.any?

      attempt = 0
      begin
        attempt += 1
        response = perform(uri)
        handle(response, uri)
      rescue RateLimited => e
        raise e if attempt > MAX_RETRIES
        sleep(retry_delay(attempt))
        retry
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError => e
        raise Error, "Erro de rede ao falar com o Discogs: #{e.message}" if attempt > MAX_RETRIES
        sleep(retry_delay(attempt))
        retry
      end
    end

    def perform(uri)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "application/json"
      request["Authorization"] = "Discogs token=#{token}" if authenticated?

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
    end

    def handle(response, uri)
      throttle(response)

      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 401, 403
        raise Unauthorized, "O Discogs recusou a requisição para #{uri.path} (#{response.code}). " \
                            "Confira o DISCOGS_TOKEN, ou deixe o perfil público."
      when 404
        raise NotFound, "O Discogs não tem nada em #{uri.path}"
      when 429
        raise RateLimited, "Limite de requisições do Discogs atingido"
      else
        raise Error, "O Discogs retornou #{response.code} em #{uri.path}: #{response.body.to_s.truncate(200)}"
      end
    end

    # Discogs allows 60 requests/minute authenticated. When we get close to the
    # ceiling, pause so a long sync degrades instead of failing.
    def throttle(response)
      remaining = response["X-Discogs-Ratelimit-Remaining"].to_i
      return if response["X-Discogs-Ratelimit-Remaining"].nil?
      sleep(2) if remaining <= 2
    end

    def retry_delay(attempt)
      [ 2**attempt, 30 ].min
    end
  end
end
