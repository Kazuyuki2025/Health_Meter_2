Rails.application.routes.draw do
  resources :videos, only: [ :index, :new, :create, :show, :destroy ]
  resources :performers, only: [ :index, :new, :create, :show, :destroy ]
  resources :performances, only: [ :index, :new, :create, :show, :destroy ]
  root "performers#index"
end
