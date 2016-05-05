Rails.application.routes.draw do
  root 'approvals#index'

  post '/approve', to: 'approvals#approve'
  post '/decline', to: 'approvals#decline'
end