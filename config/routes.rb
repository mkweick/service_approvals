Rails.application.routes.draw do
  root 'approvals#index'

  post '/approve-repair', to: 'approvals#approve_repair'
  post '/decline-repair', to: 'approvals#decline_repair'

  post '/approve-promo', to: 'approvals#approve_promo'
  post '/change-promo', to: 'approvals#change_promo'
end