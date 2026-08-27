Rails.application.routes.draw do
  namespace :api do
    get "collection", to: "items#index", defaults: { list: "collection" }
    get "wantlist",   to: "items#index", defaults: { list: "wantlist" }

    resources :releases, only: :show do
      get :marketplace, on: :member
    end
    resource  :sync,    only: [ :show, :create ], controller: "sync"
    resource  :profile, only: :show, controller: "profile"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#index"

  # The React router owns every non-API path, so a hard refresh on
  # /wantlist or /release/123 still boots the SPA. Paths containing a dot are
  # left alone so a missing asset 404s instead of returning HTML.
  get "*path", to: "pages#index", format: false, constraints: ->(request) {
    !request.path.start_with?("/api", "/assets", "/rails") && !request.path.include?(".")
  }
end
