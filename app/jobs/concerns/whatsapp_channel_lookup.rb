# frozen_string_literal: true

# Encuentra el canal de WhatsApp de un webhook de Meta. Estaba en WhatsappEventsJob; se
# comparte con WhatsappCallEventsJob (diag/llamadas_whatsapp, F2).
module WhatsappChannelLookup
  extend ActiveSupport::Concern

  private

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?

    # feat/licencias (F3): una cuenta suspendida ya no descarta mensajes; se guardan y es el
    # motor el que no contesta (Licenses::Silence), igual que en los demás canales.

    false
  end

  def find_channel_by_url_param(params)
    return unless params[:phone_number]

    Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  def find_channel_from_whatsapp_business_payload(params)
    # for the case where facebook cloud api support multiple numbers for a single app
    # https://github.com/chatwoot/chatwoot/issues/4712#issuecomment-1173838350
    # we will give priority to the phone_number in the payload
    return get_channel_from_wb_payload(params) if params[:object] == 'whatsapp_business_account'

    find_channel_by_url_param(params)
  end

  def get_channel_from_wb_payload(wb_params)
    phone_number = "+#{wb_params[:entry].first[:changes].first.dig(:value, :metadata, :display_phone_number)}"
    phone_number_id = wb_params[:entry].first[:changes].first.dig(:value, :metadata, :phone_number_id)
    channel = Channel::Whatsapp.find_by(phone_number: phone_number)
    # validate to ensure the phone number id matches the whatsapp channel
    return channel if channel && channel.provider_config['phone_number_id'] == phone_number_id
  end
end
