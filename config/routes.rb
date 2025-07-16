Rails.application.routes.draw do
  root "performers/index"
  resources :performances, only: [ :new, :create, :index, :show ]
  get "performances/healthy_ranking", to: "performances#healthy_ranking"
  resources :performers

  get "up" => "rails/health#show", as: :rails_health_check
end
