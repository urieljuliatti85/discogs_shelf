require "test_helper"

class Api::BaseControllerTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  # with_routing tears the response down when its block ends, so the
  # assertions have to run inside it.
  def raising(error_class)
    with_routing do |routes|
      routes.draw { get "explode" => "exploding#show" }
      get "/explode", params: { kind: error_class.name }
      yield
    end
  end

  test "a missing configuration is a 503, not a server error" do
    raising(Discogs::NotConfigured) do
      assert_response :service_unavailable
      assert_equal "not_configured", json["error"]
      assert_equal "estourou", json["message"]
    end
  end

  # rescue_from matches in reverse declaration order, so the Discogs::Error
  # catch-all must stay declared before its subclasses. If it moves below them,
  # these two collapse into 502.
  test "a rejected credential is a 401" do
    raising(Discogs::Unauthorized) do
      assert_response :unauthorized
      assert_equal "unauthorized", json["error"]
    end
  end

  test "an upstream failure is a 502" do
    raising(Discogs::Error) do
      assert_response :bad_gateway
      assert_equal "discogs_error", json["error"]
    end
  end

  test "a NotFound from Discogs is still an upstream failure, not a 404" do
    raising(Discogs::NotFound) do
      assert_response :bad_gateway
    end
  end

  test "a missing local record is a 404 with a Portuguese message" do
    raising(ActiveRecord::RecordNotFound) do
      assert_response :not_found
      assert_equal "Registro não encontrado", json["message"]
    end
  end

  test "every error response is JSON with an error code and a message" do
    [ Discogs::NotConfigured, Discogs::Unauthorized, Discogs::Error, ActiveRecord::RecordNotFound ].each do |error|
      raising(error) do
        assert_equal "application/json", response.media_type, error.name
        assert_equal %w[error message], json.keys.sort, error.name
      end
    end
  end
end
