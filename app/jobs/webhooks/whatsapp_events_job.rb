class Webhooks::WhatsappEventsJob < ApplicationJob
  queue_as :low
  retry_on ActiveRecord::RecordNotFound, wait: 30.seconds, attempts: 5

  def perform(params = {})
    channel = find_channel_from_whatsapp_business_payload(params)
    return if channel_is_inactive?(channel)
  
    Rails.logger.info "Processing params: #{params.inspect}"

    # @waba_templates — ciclo de vida de plantilla (message_template_*) antes de los mensajes.
    template_change = template_lifecycle_change(params)
    return Whatsapp::TemplateWebhookService.new(channel, template_change).perform if template_change

    # coexistencia — mensajes respondidos desde la Business App (móvil) → salientes en Chatwoot.
    if coexistence_echo?(params) && channel.provider == 'whatsapp_cloud'
      return Whatsapp::EchoMessageService.new(inbox: channel.inbox, params: params).perform
    end

    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    when 'unoapi'
      Whatsapp::IncomingMessageUnoapiService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end

  private

  # Devuelve el `change` si es un webhook de ciclo de vida de plantilla, si no nil.
  def template_lifecycle_change(params)
    return if params[:entry].blank?

    change = params[:entry].first[:changes]&.first
    return unless change && change[:field].to_s.start_with?('message_template_')

    change
  end

  # ¿El webhook trae echoes de coexistencia (mensajes enviados desde el móvil)?
  def coexistence_echo?(params)
    return false if params[:entry].blank?

    value = params[:entry].first[:changes]&.first&.dig(:value)
    value.present? && value[:message_echoes].present?
  end

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

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
