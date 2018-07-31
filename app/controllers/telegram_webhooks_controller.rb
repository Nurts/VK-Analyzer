require 'net/http'
require 'json'
require "google/cloud/language"
class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  def start!(*)
    @main_keyboard = {
      keyboard: [[ '/add_hobby', '/start', '/find_match'], ['/remove_hobby', '/my_hobbies', '/vk_auth']],
      resize_keyboard: true,
      one_time_keyboard: false,
      selective: true,
    }
    if from["id"] and !from["is_bot"]
      begin
        user = User.find(from["id"])
        respond_with :message, text: t('.welcome_back') + " #{user.first_name}", reply_markup: @main_keyboard
      rescue
        u = User.new(id: from["id"], first_name: from["first_name"], last_name: from["last_name"], username: from["username"], active: false)
        if from["id"]
          u.save
          respond_with :message, text: t('.content') + "Please add you hobbies /add_hobby", reply_markup: @main_keyboard
        else
          respond_with :message, text: "Error please sign in to telegram"
        end
      end
      
    else
      respond_with :message, text: "Error 404"
    end
  end

  def add_hobby!(*)
    respond_with :message, text: "Please Enter Your Hobby"
    save_context :add_hobby
  end

  def remove_hobby!(*)
    inline_hobby_list =  curent_user.hobby_list.map{|hobby| {text: hobby, callback_data: hobby}}
    puts inline_hobby_list
    @hobby_list_keyboard = {
      inline_keyboard: [
        inline_hobby_list
      ],
    }
    respond_with :message, text: "Pleaes Choose a Hobby to remove", reply_markup: @hobby_list_keyboard
    save_context :remove_hobby
  end

  def my_hobbies!(*)
    respond_with :message, text: "Your hobbies: " + curent_user.hobby_list.to_s
  end

  def help!(*)
    respond_with :message, text: t('.content')
  end

  def find_match!(*)
    user = curent_user
    matched = user.find_related_hobbies
    puts matched
    if matched.any?
      match = matched[0]
      respond_with :message, text: "This user is the best match for you! \n #{match.first_name} #{match.last_name} \n Username: @#{match.username}"
    else
      respond_with :message, text: "Sorry, we cannot find suitable friend for you, try to add more hobbies to your profile"
    end
  end

  def vk_auth!(*)
    oauth_params = {
      client_id: "6647377",
      redirect_uri: "http://localhost:3000/index/#{curent_user.id}",
      display: "page",
      scope: 329950,
      response_type: "code",
      v: 5.80,
      state: "123123"
    }
    url = "https://oauth.vk.com/authorize?#{oauth_params.to_query}"
    respond_with :message, text: url
  end

  def get_groups!
    method_params = {
      extended: 0
    }
    data = vk_api('groups.get',curent_user.access_token, method_params)
    puts data
    analyze_groups(data["items"])
  end
  
#Not Commands

  def analyze_groups(g_id)
    method_params = {
      group_ids: g_id,
      fields: :description
    }
    data = vk_api('groups.getById',curent_user.access_token, method_params)
    res = {}
    data.each do |group|
      res[group["name"]] = get_categories(group["description"])
    end
    respond_with :message, text: res.to_s
  end
  
  def add_hobby(*hobbies)
    if hobbies.any?
      hobby = hobbies.join(' ')
      user = curent_user
      user.hobby_list.add(hobby)
      user.save
      respond_with :message, text: "Your hobbies: " + curent_user.hobby_list.to_s
    else
      add_hobby!
    end
  end

  def callback_query(data)
    remove_hobby(data)
  end

  def remove_hobby(*hobbies)
    if hobbies.any?
      hobby = hobbies.join(' ')
      user = curent_user
      user.hobby_list.remove(hobby)
      user.save
      respond_with :message, text: "The hobby is removed \n Your hobbies: " + curent_user.hobby_list.to_s
    else
      add_hobby!
    end
  end

  private
  def curent_user()
    begin
      User.find(from["id"]);
    rescue
      nil
    end
  end

  def vk_api(method_name, access_token, method_params)
    method_params[:access_token] = access_token
    method_params[:v]="5.80"
    url = "https://api.vk.com/method/#{method_name}?#{method_params.to_query}"
    result = Net::HTTP.get(URI.parse(url))
    result = JSON.parse(result)
    return result["response"]
  end

  def get_categories(text)
    language = Google::Cloud::Language.new
    response = language.analyze_sentiment content: text, type: :PLAIN_TEXT
    sentiment = response.document_sentiment
    respond_with :message, text: sentiment.to_s
  end
=begin
  def memo!(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo!
    end
  end

  def remind_me!(*)
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard!(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard!
      respond_with :message, text: t('.prompt'), reply_markup: {
        keyboard: [t('.buttons')],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true,
      }
    end
  end

  def inline_keyboard!(*)
    respond_with :message, text: t('.prompt'), reply_markup: {
      inline_keyboard: [
        [
          {text: t('.alert'), callback_data: 'alert'},
          {text: t('.no_alert'), callback_data: 'no_alert'},
        ],
        [{text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot'}],
      ],
    }
  end

  def callback_query(data)
    if data == 'alert'
      answer_callback_query t('.alert'), show_alert: true
    else
      answer_callback_query t('.no_alert')
    end
  end

  def message(message)
    respond_with :message, text: t('.content', text: message['text'])
  end

  def inline_query(query, _offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = Array.new(5) do |i|
      {
        type: :article,
        title: "#{query}-#{i}",
        id: "#{query}-#{i}",
        description: "#{t_description} #{i}",
        input_message_content: {
          message_text: "#{t_content} #{i}",
        },
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, _query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result!(*)
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def action_missing(action, *_args)
    if action_type == :command
      respond_with :message,
        text: t('telegram_webhooks.action_missing.command', command: action_options[:command])
    else
      respond_with :message, text: t('telegram_webhooks.action_missing.feature', action: action)
    end
  end
=end
  
end
