Rails.application.routes.draw do
  resources :videos do
    member do
      post :assign_performers
      post :reanalyze
      get :frame_data
      get :all_frames_data
      get :player
    end
    resources :performances, only: [ :show, :edit, :update ]
  end

  resources :performers do
    collection do
      get :healthy_ranking
      get :unhealthy_risks
    end
    member do
      get :unhealthy_risks_detail
    end
  end

  resources :performances

  root "videos#index"
end
