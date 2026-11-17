get '/support', to: 'tickets/support#new', as: :ticket_support
post '/support', to: 'tickets/support#create'
get '/tickets/:token', to: 'tickets/tickets#show', as: :ticket
post '/tickets/:token/replies', to: 'tickets/replies#create', as: :ticket_replies

namespace :premium_support, path: 'premium-support' do
  root to: 'home#index'
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'
  get 'password/new', to: 'access_links#new', as: :new_password
  post 'password', to: 'access_links#create'
  get 'access/:token', to: 'access_links#edit', as: :access
  patch 'access/:token', to: 'access_links#update'
  resources :tickets, only: [:new, :create, :show, :update] do
    post :reply, on: :member
    resources :attachments, only: [:show]
  end
end

namespace :api do
  namespace :v1 do
    resources :accounts, only: [] do
      scope module: :accounts do
        resources :portal_customers, only: [:index, :create, :update] do
          member do
            post :invitation
            post :password_reset
            post :suspend
            post :reactivate
          end
        end
      end
    end
  end
end
