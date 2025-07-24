Rails.application.routes.draw do
  resources :videos, only: [ :index, :new, :create, :show, :destroy ]
  root "videos#index"
end
