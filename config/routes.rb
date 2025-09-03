Rails.application.routes.draw do
  resources :videos do
    member do
      post :assign_performers
    end
    resources :performances, only: [ :show, :edit, :update ]
  end

  resources :performers
  resources :performances

  root "videos#index"
end
