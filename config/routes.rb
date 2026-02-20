Rails.application.routes.draw do
  get "health" => "health#show"
  get "health/readiness" => "health#readiness"

  resources :departments, path: '/werkstaetten' do
    member do
      patch 'schliessen', :to =>'departments#unstaff', :as => "unstaff"
      patch 'besetzen', :to => 'departments#staff', :as => "staff"
    end
  end

  devise_for :users,
    path: '',
    path_names: { sign_in: 'login', sign_out: 'logout', password: 'password', confirmation: 'verification', unlock: 'unblock' },
    controllers: { invitations: 'users/invitations' }

  devise_scope :user do
    delete 'invitations/:id', :to => 'users/invitations#admin_destroy', as: "delete_user_invitation"
  end

  get 'ausleihbedingungen', :to => 'static_pages#ausleihbedingungen'
  get 'datenschutz', :to => 'static_pages#datenschutz'
  get 'impressum', :to => 'static_pages#impressum'
  get 'ausleihkorb/ausleiher', :to => 'static_pages#lender'

  get 'verwaltung/verleihende', :to => 'users#index'
  get 'verwaltung/texte', :to => 'static_pages#edit'
  get 'verwaltung/texte/:id', :to => 'static_pages#edit_single_legal_text', as: 'edit_single_legal_text'
  patch 'verwaltung/texte/:id', :to => 'static_pages#update', as: 'update_legal_text'
  get 'verwaltung/statistik', to: 'statistics#index'

  get '/artikel', to: redirect('/verwaltung')
  resources :parent_items, path: 'artikel', except: :index

  delete 'artikel/:id/file/:file_id', :to => 'parent_items#destroy_file', as: 'delete_parent_item_file'

  resources :borrowers, path: 'verwaltung' do
    member do
      post :export_data
      post :request_deletion
    end
  end

  scope 'checkout' do
    resources :borrowers, as: 'checkout_borrower', except: :index
  end

  post 'ausleiher/:id/verhalten', to: 'borrowers#add_conduct', as: 'borrower_add_conduct'
  delete 'ausleiher/:id/verhalten/:conducts_id/entfernen', to: 'borrowers#remove_conduct', as: 'borrower_remove_conduct'

  match 'ausleihe', to: 'lending#index', via: [:get, :post], :as => 'lending'
  post 'ausleihe/zum_ausleihkorb', to: 'lending#populate', :as => 'lending_populate'
  get 'ausleihe/:id/token/:token' => 'lending#show', :as => :token_lending
  get 'ausleihe/:id/token/:token/agreement' => 'lending#show_printable_agreement', :as => :lending_agreement
  match 'ausleihe/:id', to: 'lending#destroy', via: [:delete, :post], :as => :lending_destroy
  patch 'ausleihe/:id/ausleihzeit', to: 'lending#change_duration', :as => :change_lending_duration

  get 'checkout', :to => 'checkout#index' , :as => :checkout
  match 'checkout/:state', to: 'checkout#index', via: [:get, :post], :as => :checkout_state
  patch 'checkout/update/:state', :to => 'checkout#update', :as => :update_checkout

  get '/checkout/update/confirmation', to: redirect('/checkout/confirmation')

  delete 'ausleihkorb/:line_item_id', :to => 'lending#remove_line_item', :as => :remove_line_item
  patch 'ausleihkorb', :to => 'lending#update', :as => :update_cart
  put 'ausleihkorb/leeren', :to => 'lending#empty', :as => :empty_cart

  get 'ruecknahme', :to => 'returns#index', :as => :return
  post 'ruecknahme', :to => 'returns#take_back', :as => :take_back

  get 'email_bestaetigen/:token', to: 'borrowers#confirm_email', as: 'confirm_email'
  get 'email_bestaetigen/:token/send_email', to: 'borrowers#send_confirm_email_email', as: 'send_confirm_email'
  get 'registrieren', to: 'borrowers#self_register', as: 'borrower_self_registration'
  post 'registrieren', to: 'borrowers#self_create', as: 'borrower_self_create'
  get 'registrieren/bestaetigung-ausstehend', to: 'borrowers#email_confirmation_pending', as: 'borrower_email_pending'

  get 'autocomplete/items', to: 'autocomplete#items'
  get 'autocomplete/items/depts/:dept_id', to: 'autocomplete#items'
  get 'autocomplete/borrowers', to: 'autocomplete#borrowers'

  resources :users do
    member do
      post :send_password_reset
    end
  end

  get 'home', to: 'static_pages#index', :as => 'public_home_page'
  
  authenticated :user do
    root :to => redirect('/ausleihe'), :as => "authenticated_root"
  end

  root "static_pages#index"

  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
