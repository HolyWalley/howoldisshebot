require 'telegram/bot'
require 'net/http'
require 'json'
require 'dotenv'

Dotenv.load('.env')
TGTOKEN = ENV['TGTOKEN']
MSTOKEN = ENV['MSTOKEN']

FACE_API_URI = 'https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect'.freeze
API_TELEGRAM = 'https://api.telegram.org/'.freeze
START_MESSAGE = 'Привет, друг! Хочешь узнать, сколько лет девушке, но'\
  ' напрямую спрашивать невежливо? ОК - скинь её фото и я тебе помогу :)'\
  "\n\n/start - моё описание и список команд (будет пополняться)"\
  "\n\nПросто загружай фото и я отвечу на твой вопрос!".freeze

def prepare_url(params)
  API_TELEGRAM + params
end

def prepare_answer(answer_from_faceapi)
  count = answer_from_faceapi.count
  return 'Дружище, на фото больше одного человека, если хочешь, чтобы я рассказал тебе о каждом из них - тебе придётся ждать пока @holywalley меня заапдейтит :)' if count > 1
  return 'Ну тут два варианта: либо я не вижу её лицо, либо ты меня обманываешь :(' if count <= 0
  face_attrs = answer_from_faceapi[0]['faceAttributes']
  age = face_attrs['age']
  gender = face_attrs['gender']
  return "Кхм, твои вкусы очень специфичны, ведь на фото мужчина. Кстати, ему #{age} лет" if gender == 'male'
  "Ей #{age} лет, не благодари :)\nА хотя, ладно, благодари @holywalley"
end

def get_image_true_path(message)
  file_id = message.photo.last.file_id

  uri = URI(prepare_url('bot' + TGTOKEN + "/getFile?file_id=#{file_id}"))
  res = Net::HTTP.get(uri)
  my_hash = JSON.parse(res)
  prepare_url('file/bot' + TGTOKEN + "/#{my_hash['result']['file_path']}")
end

def get_response_from_faceapi(image_true_path)
  uri = URI(FACE_API_URI)
  uri.query = URI.encode_www_form(
    'returnFaceId' => 'true',
    'returnFaceLandmarks' => 'false',
    'returnFaceAttributes' => 'age,gender'
    )
  request = Net::HTTP::Post.new(uri.request_uri)
  request['Content-Type'] = 'application/json'
  request['Ocp-Apim-Subscription-Key'] = MSTOKEN
  request.body = { url: image_true_path }
  request.body = JSON.generate(request.body)
  begin
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
  rescue Exception => msg
    puts msg
  end  
end

def send_message(bot, message, s_message)
  bot.api.send_message(chat_id: message.chat.id, text: s_message)
end

Telegram::Bot::Client.run(TGTOKEN) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      send_message(bot, message, START_MESSAGE)
    end
    if message.photo.last
      image_true_path = get_image_true_path(message)
      puts 'New Photo Uploaded'
      if response = get_response_from_faceapi(image_true_path)
        answer_from_faceapi = JSON.parse(response.body)
        send_message(bot, message, prepare_answer(answer_from_faceapi))
        puts 'The answer is given'
      else
        send_message(bot, message, 'Упс, что-то пошло не так. Попробуйте позже :(')
        puts 'The answer is not given'
      end
    end
  end
end
