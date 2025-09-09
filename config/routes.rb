Rails.application.routes.draw do
  resources :videos do
    member do
      post :assign_performers
      post :reanalyze
    end
    resources :performances, only: [ :show, :edit, :update ]
  end

  resources :performers
  resources :performances do
    collection do
      get :healthy_ranking
    end
  end

  root "videos#index"
end
