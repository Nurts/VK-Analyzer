require 'net/http'
require 'json'
class VkauthController < ApplicationController
    def index
        if params.key?(:code)
            access_params = {
                client_id: "6647377",
                client_secret: "9RNejxCk18sHN7jqVqE8",
                redirect_uri: "http://localhost:3000/index/#{params[:id]}",
                code: params[:code]
            }
            url = "https://oauth.vk.com/access_token?#{access_params.to_query}"
            result = Net::HTTP.get(URI.parse(url))
            result = JSON.parse(result)
            puts result
            puts result["access_token"]
            puts result["user_id"]
            user = User.find(params[:id])
            user.access_token = result["access_token"]
            user.vk_id = result["vk_id"].to_i
            user.save
        end
    end
end
