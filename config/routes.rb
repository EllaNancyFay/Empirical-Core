require 'sidekiq/web'

EmpiricalGrammar::Application.routes.draw do


  use_doorkeeper

  # authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  # end

  resources :admins, only: [:show], format: 'json' do
    resources :teachers, only: [:index, :create]
  end

  # for admins to sign in as teachers
  resources :users do
    member do
      get :admin_sign_in_classroom_manager, to: 'admins#sign_in_classroom_manager'
      get :admin_sign_in_progress_reports, to: 'admins#sign_in_progress_reports'
      get :admin_sign_in_account_settings, to: 'admins#sign_in_account_settings'
    end
  end

  # for Stripe
  resources :charges


  resources :subscriptions
  resources :assessments
  resources :assignments
  resource :profile
  resources :password_reset
  resources :schools, only: [:index], format: 'json'
  resources :unit_templates, only: [:index, :show], format: 'json'

  resources :activity_sessions, only: [] do
    get :anonymous, on: :collection
    get :play, on: :member
    put :play, on: :member
  end
  # 3rd party apps depend on the below, do not change :
  get 'activity_sessions/:uid' => 'activity_sessions#result'


  resources :activities, only: [] do
    post :retry, on: :member
    get :search, on: :collection
  end

  resources :grades, only: [:index]

  get :porthole_proxy, to: 'porthole_proxy#index'

  namespace :teachers do

    resources :units, as: 'units_path'  # moved from within classroom, since units are now cross-classroom

    resources :unit_templates, only: [:index] do
      collection do
        post :fast_assign, controller: 'unit_templates', action: 'fast_assign'
      end
    end

    resources :classroom_activities, only: [:destroy, :update], as: 'classroom_activities_path'


    get 'my_account' => 'classroom_manager#my_account'
    get 'my_account_data' => 'classroom_manager#my_account_data'
    put 'update_my_account' => 'classroom_manager#update_my_account'
    delete 'delete_my_account' => 'classroom_manager#delete_my_account'
    put 'units/:id/hide' => 'units#hide', as: 'hide_units_path'

    namespace :progress_reports do
      resources :activity_sessions, only: [:index]
      resources :csv_exports, only: [:create]

      namespace :concepts do
        resources :students, only: [:index] do
          resources :concepts, only: [:index]
        end
      end

      namespace :standards do
        resources :classrooms, only: [:index] do
          resources :students, controller: "classroom_students", only: [:index] do
            resources :topics, controller: "student_topics", only: [:index]
          end

          resources :topics, controller: "classroom_topics", only: [:index] do
            resources :students, controller: "topic_students", only: [:index]
          end
        end
      end
    end

    resources :classrooms do
      collection do
        get :regenerate_code
        get :lesson_planner, controller: "classroom_manager", action: 'lesson_planner'
        post :lesson_planner, controller: "classroom_manager", action: 'lesson_planner'
        get :scorebook, controller: 'classroom_manager', action: 'scorebook'
        get :scores, controller: 'classroom_manager', action: 'scores'
        get :dashboard, controller: 'classroom_manager', action: 'dashboard'
        get :search_activities, controller: 'classroom_manager', action: 'search_activities'
        get :retrieve_classrooms_for_assigning_activities, controller: 'classroom_manager', action: 'retrieve_classrooms_for_assigning_activities'
        post :assign_activities, controller: 'classroom_manager', action: 'assign_activities'

        ##DASHBOARD ROUTES
        get :classroom_mini, controller: 'classroom_manager', action: 'classroom_mini'
        get :dashboard_query, controller: 'classroom_manager', action: 'dashboard_query'
        get :premium, controller: 'classroom_manager', action: 'premium'
      end

      member do
        get :hide #I am not sure why, however the first hide request on a classroom is always a get. Subsequent ones are put.
        put :hide
      end

      resources :activities, controller: 'classroom_activities'

      resources :students do
        put :reset_password
      end

      # TODO: abstract this list as well. Duplicated in nav in layout.
      %w(invite_students accounts import).each do |page|
        get page => "classroom_manager##{page}"
      end

    end
  end

  put '/students_classrooms/hide', to: 'students_classrooms#hide', as: 'students_classrooms_archive'

  # API routes
  namespace :api do
    namespace :v1 do
      resources :activities,              except: [:index, :new, :edit]
      resources :activity_flags,          only: [:index]
      resources :activity_sessions,       except: [:index, :new, :edit]
      resources :sections,                only: [:index]
      resources :topics,                  only: [:index]
      resources :topic_categories,        only: [:index]
      resources :concepts,                only: [:index, :create]

      resource :me, controller: 'me',     except: [:index, :new, :edit, :destroy]
      resource :ping, controller: 'ping', except: [:index, :new, :edit, :destroy]
      resource :firebase_tokens,          only: [:create]
    end

    # Try to route any GET, DELETE, POST, PUT or PATCH to the proper controller.
    # This converts requests like GET /v1/ping to /api/v1/ping, and also
    # /ping to /api/v1/ping.
    #
    # These routes are lost since they are globs, and thus will match anything
    # not previously matched.
    # [:get, :delete, :post, :put, :patch].each do |method|
    #   match 'v:api/*path', to: redirect("/api/v1/%{path}"), via: method
    #   match '*path', to: redirect("/api/v1/%{path}"), via: method
    # end
  end

  # for some reason, session_path with method :delete does not evaluate correctly in profiles/student.html.erb
  # so we have the patch below:
  get '/session', to: 'sessions#destroy'
  resource :session

  resource :account do
    post :role, to: 'accounts#role'
  end

  namespace :auth do
    get "/google_oauth2/callback" => 'google#google'
    get '/clever/callback', to: 'clever#clever'
  end

  get '/clever/auth_url_details', to: 'clever#auth_url_details'
  get '/auth/failure', to: 'sessions#failure'

  put '/select_school', to: 'accounts#select_school'

  namespace :cms do
    resources :admin_accounts, only: [:index, :create, :update, :destroy]
    resources :admins, only: [:index, :create, :update, :destroy]
    resources :categories
    resources :concepts
    resources :sections
    resources :activity_classifications
    resources :topics
    resources :topic_categories
    resources :authors, only: [:index, :create, :update, :destroy]
    resources :unit_templates, only: [:index, :create, :update, :destroy]
    resources :unit_template_categories, only: [:index, :create, :update, :destroy]

    resources :activities, path: 'activity_type/:activity_classification_id/activities' do
      resource :data
    end

    resources :users do
      resource :subscription

      collection do
        match 'search' => 'users#search', via: [:get, :post], as: :search
      end
      member do
        get :show_json
        put :sign_in
      end
    end
  end

  # tooltip is just for prototyping tooltip, if its still there you can remove it.
  %w(tooltip press blog_posts supporters middle_school story learning develop mission faq tos privacy activities new impact stats team premium teacher_resources press_kit play media news).each do |page|
    get page => "pages##{page}", as: "#{page}"
  end
  get 'activities/section/:section_id' => 'pages#activities', as: "activities_section"
  get 'activities/packs' => 'teachers/unit_templates#index'
  get 'activities/packs/:id' => 'teachers/unit_templates#show'

  get 'lessons' => 'pages#activities' # so that old links still work
  get 'about' => 'pages#activities' # so that old links still work

  get 'demo' => 'teachers/progress_reports/standards/classrooms#demo'

  patch 'verify_question' => 'chapter/practice#verify'
  get   'verify_question' => 'chapter/practice#verify_status'
  patch 'cheat'           => 'chapter/practice#cheat'
  get '/404' => 'errors#error_404'
  get '/500' => 'errors#error_500'

  root to: 'pages#home'

  # http://stackoverflow.com/questions/26130130/what-are-the-routes-i-need-to-set-up-to-preview-emails-using-rails-4-1-actionmai
  get '/lib/mailer_previews' => "rails/mailers#index"
  get '/lib/mailer_previews/*path' => "rails/mailers#preview"

  # catch-all 404
  get '*path', to: 'application#routing_error'
end
