Rails.application.routes.draw do
  resources :videos
  get "up" => "rails/health#show", as: :rails_health_check

  Rails.application.routes.draw do
  root "videos#new"
  end
end
