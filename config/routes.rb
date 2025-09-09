Rails.application.routes.draw do
  resources :videos do
    member do
      post :assign_performers
      post :reanalyze
    end
    resources :performances, only: [ :show, :edit, :update ]
  end

  resources :performers do
    collection do
      get :healthy_ranking
    end
  end

  resources :performances

  root "videos#index"
end
