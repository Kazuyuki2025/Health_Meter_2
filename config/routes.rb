Rails.application.routes.draw do
  resources :videos
  resources :performers
  resources :performances
  root "performers#index"
end
