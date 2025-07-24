Rails.application.routes.draw do
  resources :videos, only: [ :index, :new, :create, :show ]
  root "videos#index"
end
