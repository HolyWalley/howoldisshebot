require 'telegram/bot'
require 'net/http'
require 'json'

file = File.open('tokens.txt')

token = file.gets.to_s[0..-2]
mstoken = file.gets.to_s

puts token == token2
puts token
puts token2

Telegram::Bot::Client.run(token) do |bot| 
	bot.listen do |message|	
    case message.text
      when '/start'
      	bot.api.send_message(chat_id: message.chat.id, text: "Привет, друг! Хочешь узнать, сколько лет девушке, но напрямую спрашивать невежливо? ОК - скинь её фото и я тебе помогу :)")
      	bot.api.send_message(chat_id: message.chat.id, text: "/start - моё описание и список команд (будет пополняться)")
      	bot.api.send_message(chat_id: message.chat.id, text: "Просто загружай фото и я отвечу на твой вопрос!")
      end
  	
    if message.photo[-1] then
      file_id = message.photo[-1].file_id
      uri = URI("https://api.telegram.org/bot"+token+"/getFile?file_id=#{file_id}")
      res = Net::HTTP.get(uri)
      my_hash = JSON.parse(res)
      image_true_path = "https://api.telegram.org/file/bot"+token+"/#{my_hash["result"]["file_path"]}"
      puts image_true_path
 
      uri = URI('https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect')
      uri.query = URI.encode_www_form({
      'returnFaceId' => 'true',
      'returnFaceLandmarks' => 'false',
      'returnFaceAttributes' => 'age,gender'
      })

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['Ocp-Apim-Subscription-Key'] = mstoken
      request.body = "{\"url\":\"#{image_true_path}\"}"

      response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
    end

      h = JSON.parse(response.body)
      if h.count > 1 then
      	bot.api.send_message(chat_id: message.chat.id, text: "Дружище, на фото больше одного человека, если хочешь, чтобы я рассказал тебе о каждом из них - тебе придётся ждать пока @holywalley меня заапдейтит :)")
      elsif h.count == 1
      	if h[0]["faceAttributes"]["gender"] == "male" then
      		bot.api.send_message(chat_id: message.chat.id, text: "Кхм, твои вкусы очень специфичны, ведь на фото мужчина. Кстати, ему #{h[0]["faceAttributes"]["age"]} лет")
		else
			bot.api.send_message(chat_id: message.chat.id, text: "Ей #{h[0]["faceAttributes"]["age"]} лет, не благодари :)")
			bot.api.send_message(chat_id: message.chat.id, text: "А хотя, ладно, благодари @holywalley")

      		puts h[0]["faceAttributes"]["gender"]
      	end
      else
      	bot.api.send_message(chat_id: message.chat.id, text: "Ну тут два варианта: либо я не вижу её лицо, либо ты меня обманываешь :(")
      end
  end
  end
end