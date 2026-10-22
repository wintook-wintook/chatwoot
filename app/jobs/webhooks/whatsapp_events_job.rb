class Webhooks::WhatsappEventsJob < ApplicationJob
  include WhatsappChannelLookup # diag/llamadas_whatsapp: compartido con WhatsappCallEventsJob
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
    # Se activa por cuenta desde el super admin (feature whatsapp_coexistence).
    if coexistence_echo?(params) && channel.provider == 'whatsapp_cloud' && coexistence_enabled?(channel)
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

  # La coexistencia se habilita por cuenta desde el super admin.
  def coexistence_enabled?(channel)
    channel.account.feature_enabled?('whatsapp_coexistence')
  end
end
