class Whatsapp::Providers::WhatsappCloudService < Whatsapp::Providers::BaseService
  # @waba_templates — resultado accionable de las operaciones de plantilla contra Meta.
  TemplateResult = Struct.new(:success, :meta_id, :status, :error, :rate_limited, keyword_init: true) do
    def success?
      success
    end
  end

  def send_message(phone_number, message)
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(message, phone_number, template_info)
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        to: phone_number,
        template: template_body_parameters(template_info),
        type: 'template'
      }.to_json
    )

    process_response(message, response)
  end

  # @waba_templates — crea una plantilla en Meta (queda PENDING de aprobación).
  # POST /{business_account_id}/message_templates
  def create_template(payload)
    response = HTTParty.post("#{business_account_path}/message_templates", headers: api_headers, body: payload.to_json)
    build_template_result(response, :create)
  end

  # @waba_templates — Meta REEMPLAZA los components enteros y la vuelve a PENDING.
  # POST /{meta_template_id}
  def edit_template(meta_id, components:, category: nil)
    body = { components: components }
    body[:category] = category if category.present?
    response = HTTParty.post(message_template_path(meta_id), headers: api_headers, body: body.to_json)
    build_template_result(response, :edit)
  end

  # @waba_templates — borra por hsm_id (sin él borraría TODAS las variantes de idioma).
  # DELETE /{business_account_id}/message_templates?name=&hsm_id=  · 404 = no-op.
  def delete_template(name:, meta_template_id: nil)
    query = { name: name }
    query[:hsm_id] = meta_template_id if meta_template_id.present?
    response = HTTParty.delete("#{business_account_path}/message_templates", headers: api_headers, query: query)
    return TemplateResult.new(success: true) if response.code == 404

    build_template_result(response, :delete)
  end

  def sync_templates
    # ensuring that channels with wrong provider config wouldn't keep trying to sync templates
    whatsapp_channel.mark_message_templates_updated
    templates = fetch_whatsapp_templates("#{business_account_path}/message_templates?access_token=#{whatsapp_channel.provider_config['api_key']}")
    whatsapp_channel.update(message_templates: templates, message_templates_last_updated: Time.now.utc) if templates.present?
  end

  # @waba_templates — lista cruda de plantillas de Meta (para el upsert por fila del sync).
  # A diferencia de fetch_whatsapp_templates (que devuelve [] en silencio si Meta falla y se
  # usa en el sync automático), aquí LANZAMOS el error real de Meta para que el dashboard
  # muestre el motivo (token vencido, config incompleta, etc.) en vez de un genérico.
  def templates_list
    fetch_templates_or_raise("#{business_account_path}/message_templates?access_token=#{whatsapp_channel.provider_config['api_key']}")
  end

  def fetch_templates_or_raise(url)
    response = HTTParty.get(url)
    unless response.success?
      meta_message = response.parsed_response.is_a?(Hash) ? response.parsed_response.dig('error', 'message') : nil
      raise "Meta respondió #{response.code}: #{meta_message || 'error desconocido'}"
    end

    next_page = next_url(response)
    return response['data'] + fetch_templates_or_raise(next_page) if next_page.present?

    response['data']
  end

  def fetch_whatsapp_templates(url)
    response = HTTParty.get(url)
    return [] unless response.success?

    next_url = next_url(response)

    return response['data'] + fetch_whatsapp_templates(next_url) if next_url.present?

    response['data']
  end

  def next_url(response)
    response['paging'] ? response['paging']['next'] : ''
  end

  def validate_provider_config?
    response = HTTParty.get("#{business_account_path}/message_templates?access_token=#{whatsapp_channel.provider_config['api_key']}")
    response.success?
  end

  def api_headers
    { 'Authorization' => "Bearer #{whatsapp_channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    "#{api_base_path}/v20.0/#{media_id}"
  end

  def message_update_payload(message)
    payload = {
      messaging_product: 'whatsapp',
      status: message[:status],
      message_id: message[:source_id],
      recipient_id: message[:sender][:phone_number]
    }
    if message[:conversation][:contact_inbox][:source_id].include?('@g.us')
      payload.merge({ group_id: message[:conversation][:contact_inbox][:source_id] })
    end
    payload
  end

  def message_update_http_method
    :post
  end

  def message_path(_message)
    messages_path
  end

  private

  def api_base_path
    whatsapp_channel.provider_config['url'] || ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end

  # TODO: See if we can unify the API versions and for both paths and make it consistent with out facebook app API versions
  def phone_id_path
    "#{api_base_path}/v20.0/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  def messages_path
    "#{phone_id_path}/messages"
  end

  def business_account_path
    "#{api_base_path}/v14.0/#{whatsapp_channel.provider_config['business_account_id']}"
  end

  # @waba_templates — nodo de la plantilla (misma versión que el WABA, por consistencia).
  def message_template_path(meta_id)
    "#{api_base_path}/v14.0/#{meta_id}"
  end

  def build_template_result(response, action)
    if response.success?
      body = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      TemplateResult.new(success: true, meta_id: body['id'], status: body['status'])
    elsif response.code == 429
      TemplateResult.new(success: false, rate_limited: true, error: rate_limit_message(action))
    else
      Rails.logger.error "[waba_templates] #{action} falló: #{response.body}"
      TemplateResult.new(success: false, error: template_error_message(response))
    end
  end

  # Mensaje accionable por acción (sin reintento ciego).
  def rate_limit_message(action)
    case action
    when :create then 'Límite de creación de plantillas (100/hora). Intenta más tarde.'
    when :edit   then 'Límite de edición (10 cada 30 días; 1 cada 24h en plantillas aprobadas).'
    else 'Límite de peticiones alcanzado. Intenta más tarde.'
    end
  end

  def template_error_message(response)
    parsed = response.parsed_response
    parsed.is_a?(Hash) ? parsed.dig('error', 'message').presence || response.body : response.body
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      messages_path,
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        context: whatsapp_reply_context(message),
        to: phone_number,
        text: { body: format_content(message) },
        type: 'text'
      }.to_json
    )

    process_response(message, response)
  end

  def format_content(message)
    feature = whatsapp_channel.inbox.account.feature_enabled?('send_agent_name_in_whatsapp_message')
    config = whatsapp_channel.provider_config['send_agent_name']
    return message.content if !feature && !config

    message.sender_name&.present? ? "*#{message&.sender_name}*: \n#{message.content}" : message.content
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = {
      'link': attachment.download_url
    }
    type_content['caption'] = message.content unless %w[audio sticker].include?(type)
    type_content['filename'] = attachment.file.filename if type == 'document'
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        :messaging_product => 'whatsapp',
        :context => whatsapp_reply_context(message),
        'to' => phone_number,
        'type' => type,
        type.to_s => type_content
      }.to_json
    )

    process_response(message, response)
  end

  def process_response(message, response)
    if response.success?
      response['messages'].first['id']
    else
      Rails.logger.error response.body
      message.update!(status: :failed, external_error: response.body)
      nil
    end
  end

  def template_body_parameters(template_info)
    {
      name: template_info[:name],
      language: {
        policy: 'deterministic',
        code: template_info[:lang_code]
      },
      components: [{
        type: 'body',
        parameters: template_info[:parameters]
      }]
    }
  end

  def whatsapp_reply_context(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    return nil if reply_to.blank?

    {
      message_id: reply_to
    }
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        to: phone_number,
        interactive: payload,
        type: 'interactive'
      }.to_json
    )

    process_response(message, response)
  end
end
