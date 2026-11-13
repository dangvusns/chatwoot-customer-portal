get '/support', to: 'tickets/support#new', as: :ticket_support
post '/support', to: 'tickets/support#create'
get '/tickets/:token', to: 'tickets/tickets#show', as: :ticket
post '/tickets/:token/replies', to: 'tickets/replies#create', as: :ticket_replies
