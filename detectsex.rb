require 'telegram/bot'
require 'net/http'
require 'json'
require 'dotenv'

file = File.open('tokens.txt')

Dotenv.load('.env')
TGTOKEN  = ENV['TGTOKEN']
MSTOKEN = ENV['MSTOKEN']

API_TELEGRAM = "https://api.telegram.org/"

def prepare_url(params)
  API_TELEGRAM+params
end

def prepare_answer(answer_from_faceapi)
  if answer_from_faceapi.count > 1 then
    return "Дружище, на фото больше одного человека, если хочешь, чтобы я рассказал тебе о каждом из них - тебе придётся ждать пока @holywalley меня заапдейтит :)"
  elsif answer_from_faceapi.count == 1
    if answer_from_faceapi[0]["faceAttributes"]["gender"] == "male" then
      return "Кхм, твои вкусы очень специфичны, ведь на фото мужчина. Кстати, ему #{answer_from_faceapi[0]["faceAttributes"]["age"]} лет"
    else
      return "Ей #{answer_from_faceapi[0]["faceAttributes"]["age"]} лет, не благодари :)"
      return "А хотя, ладно, благодари @holywalley"
    end
  else
    return "Ну тут два варианта: либо я не вижу её лицо, либо ты меня обманываешь :("
  end
end 

def get_image_true_path(message)
  file_id = message.photo.last.file_id

  uri = URI(prepare_url("bot"+TGTOKEN+"/getFile?file_id=#{file_id}"))
  res = Net::HTTP.get(uri)
  my_hash = JSON.parse(res)

  image_true_path = prepare_url("file/bot"+TGTOKEN+"/#{my_hash["result"]["file_path"]}")
end

def get_response_from_faceapi(image_true_path)
  uri = URI('https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect')
  uri.query = URI.encode_www_form({
    'returnFaceId' => 'true',
    'returnFaceLandmarks' => 'false',
    'returnFaceAttributes' => 'age,gender'
  })

  request = Net::HTTP::Post.new(uri.request_uri)
  request['Content-Type'] = 'application/json'
  request['Ocp-Apim-Subscription-Key'] = MSTOKEN
  request.body = "{\"url\":\"#{image_true_path}\"}"

  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    http.request(request)
  end
  response
end

Telegram::Bot::Client.run(TGTOKEN) do |bot| 
	bot.listen do |message|	
    case message.text
      when '/start'
      	bot.api.send_message(chat_id: message.chat.id, text: "Привет, друг! Хочешь узнать, сколько лет девушке, но напрямую спрашивать невежливо? ОК - скинь её фото и я тебе помогу :)")
      	bot.api.send_message(chat_id: message.chat.id, text: "/start - моё описание и список команд (будет пополняться)")
      	bot.api.send_message(chat_id: message.chat.id, text: "Просто загружай фото и я отвечу на твой вопрос!")
    end
  	
    if message.photo.last then
      image_true_path = get_image_true_path(message)
      puts "New Photo Uploaded"      
      response = get_response_from_faceapi(image_true_path)
      answer_from_faceapi = JSON.parse(response.body)
      bot.api.send_message(chat_id: message.chat.id, text: prepare_answer(answer_from_faceapi))
      puts "The answer is given"
    end
  end
end