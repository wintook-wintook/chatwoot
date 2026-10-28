# == Schema Information
#
# Table name: channel_telegram
#
#  id         :bigint           not null, primary key
#  bot_name   :string
#  bot_token  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#
# Indexes
#
#  index_channel_telegram_on_bot_token  (bot_token) UNIQUE
#

class Channel::Telegram < ApplicationRecord
  include Channelable

  self.table_name = 'channel_telegram'
  EDITABLE_ATTRS = [:bot_token].freeze

  before_validation :ensure_valid_bot_token, on: :create
  validates :bot_token, presence: true, uniqueness: true
  before_save :setup_telegram_webhook

  def name
    'Telegram'
  end

  def telegram_api_url
    "https://api.telegram.org/bot#{bot_token}"
  end

  def send_message_on_telegram(message)
    message_id = send_message(message) if message.content.present?
    message_id = Telegram::SendAttachmentsService.new(message: message).perform if message.attachments.present?
    message_id
  end

  def get_telegram_profile_image(user_id)
    # get profile image from telegram
    response = HTTParty.get("#{telegram_api_url}/getUserProfilePhotos", query: { user_id: user_id })
    return nil unless response.success?

    photos = response.parsed_response.dig('result', 'photos')
    return if photos.blank?

    get_telegram_file_path(photos.first.last['file_id'])
  end

  def get_telegram_file_path(file_id)
    response = HTTParty.get("#{telegram_api_url}/getFile", query: { file_id: file_id })
    return nil unless response.success?

    "https://api.telegram.org/file/bot#{bot_token}/#{response.parsed_response['result']['file_path']}"
  end

  def process_error(message, response)
    return unless response.parsed_response['ok'] == false

    # https://github.com/TelegramBotAPI/errors/tree/master/json
    message.external_error = "#{response.parsed_response['error_code']}, #{response.parsed_response['description']}"
    message.status = :failed
    message.save!
  end

  def chat_id(message)
    message.conversation[:additional_attributes]['chat_id']
  end

  def reply_to_message_id(message)
    message.content_attributes['in_reply_to_external_id']
  end

  private

  def ensure_valid_bot_token
    response = HTTParty.get("#{telegram_api_url}/getMe")
    unless response.success?
      errors.add(:bot_token, 'invalid token')
      return
    end

    self.bot_name = response.parsed_response['result']['username']
  end

  def setup_telegram_webhook
    HTTParty.post("#{telegram_api_url}/deleteWebhook")
    response = HTTParty.post("#{telegram_api_url}/setWebhook",
                             body: {
                               url: "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/telegram/#{bot_token}"
                             })
    errors.add(:bot_token, 'error setting up the webook') unless response.success?
  end

  def send_message(message)
    response = message_request(chat_id(message), message.content, reply_markup(message), reply_to_message_id(message))
    process_error(message, response)
    response.parsed_response['result']['message_id'] if response.success?
  end

  def reply_markup(message)
    return unless message.content_type == 'input_select'

    {
      one_time_keyboard: true,
      inline_keyboard: message.content_attributes['items'].map do |item|
        [{
          text: item['title'],
          callback_data: item['value']
        }]
      end
    }.to_json
  end

  def convert_markdown_to_telegram_html(text)
    # ref: https://core.telegram.org/bots/api#html-style

    # Tomado de Chatwoot v4.19. Antes los \n se cambiaban por <br> ANTES de CommonMarker y un
    # bloque ``` no se reconocía: la tabla de horarios de @solicitudes llegaba sin alinear.

    # Escape HTML entities first to prevent HTML injection
    # This ensures only markdown syntax is converted, not raw HTML
    escaped_text = CGI.escapeHTML(text)

    # Parse markdown with hardbreaks: preserve all newlines as <br>
    # (sin la extensión strikethrough de v4.19: aquí no se usaba y tacharía cualquier «~x~»)
    html = CommonMarker.render_html(escaped_text, [:HARDBREAKS]).strip

    # Convert paragraph breaks to double newlines to preserve them
    # CommonMarker creates <p> tags for paragraph breaks, but Telegram doesn't support <p>
    html_with_breaks = html.gsub(%r{</p>\s*<p>}, "\n\n")

    # Remove opening and closing <p> tags
    html_with_breaks = html_with_breaks.gsub(%r{</?p>}, '')

    # Sanitize to only allowed tags
    stripped_html = Rails::HTML5::SafeListSanitizer.new.sanitize(html_with_breaks, tags: %w[b strong i em u ins s strike del a code pre blockquote],
                                                                                   attributes: %w[href])

    # Convert <br /> tags to newlines for Telegram
    stripped_html.gsub(%r{<br\s*/?>}, "\n")
  end

  def message_request(chat_id, text, reply_markup = nil, reply_to_message_id = nil)
    text_payload = convert_markdown_to_telegram_html(text)

    HTTParty.post("#{telegram_api_url}/sendMessage",
                  body: {
                    chat_id: chat_id,
                    text: text_payload,
                    reply_markup: reply_markup,
                    parse_mode: 'HTML',
                    reply_to_message_id: reply_to_message_id
                  })
  end
end
