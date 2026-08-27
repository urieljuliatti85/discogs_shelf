require "test_helper"

# The React router owns every non-API path, so the catch-all has to re-serve the
# SPA shell for deep links while still letting genuinely missing files 404.
class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the root serves the SPA shell" do
    get root_url

    assert_response :success
    assert_select "div#root"
  end

  test "deep links boot the SPA instead of 404ing" do
    [ "/wantlist", "/stats", "/release/1001", "/qualquer/coisa/profunda" ].each do |path|
      get path

      assert_response :success, "#{path} deveria servir o shell"
      assert_select "div#root"
    end
  end

  # Without the dot exclusion a missing bundle would return HTML with a 200,
  # and the browser would try to execute the shell as JavaScript.
  test "paths that look like files are not swallowed by the catch-all" do
    [ "/application.js", "/assets/nao-existe.css", "/favicon.ico" ].each do |path|
      get path

      assert_response :not_found, "#{path} deveria escapar do catch-all"
    end
  end

  test "unknown API paths are not swallowed by the catch-all either" do
    get "/api/inexistente"

    assert_response :not_found
  end

  test "the shell links the compiled bundles" do
    get root_url

    assert_select "script[src*=application]"
    assert_select "link[href*=application][rel=stylesheet]"
  end
end
