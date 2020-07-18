GoTrack::Application.routes.draw do
  devise_for :user

  root to: 'home#index'

  get '/login', to: 'home#index'

  devise_scope :user do
    get '/user/sign_out', to: 'devise/sessions#destroy'
  end

  get '/set_ui_version' => 'application#set_ui_version', as: 'set_ui_version'
  get 'home' => 'home#index'
  get 'render_confirmation_modal' => 'application#render_confirmation_modal'

  get 'home/dispatch' => 'home#dispatch_device' # NOTE - dispatch needs to be changed to dispatch_device to avoid global name conflict
  post 'home/dispatch' => 'home#dispatch_device'

  get 'home/:action' => 'home'

  post '/home/act_as_if_account' => 'home#act_as_if_account'

  get '/geocoded_locations', to: 'locations#search_readings_location'

  resources :groups

  resources :devices, except: %i(new create show) do
    collection do
      post :search_devices
      post :choose_mt
    end
  end

  get 'reports' => 'reports#index'
  get 'reports/:action(/:id)' => 'reports', id: /\d+/, as: :action_reports

  resources :users, except: %i(show)

  resources :contact do
    collection do
      get :index
      post :thanks
    end
  end

  get 'settings' => 'settings#index'
  post 'settings' => 'settings#submit'

  get 'readings/:action(/:id)' => 'readings'

  namespace :api do
    post 'messages/send_messages' => 'messages#send_messages'
  end

  get 'admin_status/:action(/:id)' => 'admin_status'

  resources :scheduled_reports do
    member do
      get :download
    end
  end

  resources :geofences do
    collection do
      get :for_device
    end
  end

  get 'utils/:action(/:id)' => 'utils'
  get 'simulator' => 'simulator#index'
  get 'simulator/insert_reading' => 'simulator#insert_reading'

  resources :maintenances, except: %i(edit update) do
    member do
      post :reset
      get :reset
      post :complete
    end
  end

  namespace :admin do
    root to: 'overview#index'
    post :set_login_message, to: 'overview#set_login_message'
    get 'toggle_login_message', to: 'overview#toggle_login_message'

    resources :accounts, constraints: { id: /\d+/ } do
      collection do
        get '/search' => 'accounts#search'
      end
    end

    resources :device_profiles, constraints: { id: /\d+/ }

    resources :devices, constraints: { id: /\d+/ } do
      collection do
        get :digital_sensor_form
        get '/search' => 'devices#search'
        get '/clear_history' => 'devices#clear_history'
        get '/on_change_gateway_get_device_types' => 'devices#on_change_gateway_get_device_types'
      end
    end

    resources :users, except: [:show], constraints: { id: /\d+/ } do
      collection do
        get '/search' => 'users#search'
      end
    end
  end

  resources :devices do
    resources :test_readings, only: %i(new create)
  end

  resources :one_time_reports, only: %i(new create)
end
