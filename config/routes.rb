Rails.application.routes.draw do
  telegram_webhook TelegramWebhooksController
  get '/index/:id', to: 'vkauth#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
