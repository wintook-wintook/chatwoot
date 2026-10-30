class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    return if message.message_type == :outgoing && message.source_id&.is_present? # is message send by own

    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end

  def send_template_message
    name, namespace, lang_code, processed_parameters = processable_channel_message_template

    return if name.blank?

    message_id = channel.send_template(message, message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       })
    message.update!(source_id: message_id) if message_id.present?
  end

  def processable_channel_message_template
    if template_params.present?
      return enhanced_template_params if channel.provider == 'whatsapp_cloud'

      return legacy_template_params
    end

    # Delete the following logic once the update for template_params is stable
    # see if we can match the message content to a template
    # An example template may look like "Your package has been shipped. It will be delivered in {{1}} business days.
    # We want to iterate over these templates with our message body and see if we can fit it to any of the templates
    # Then we use regex to parse the template varibles and convert them into the proper payload
    channel.message_templates&.each do |template|
      match_obj = template_match_object(template)
      next if match_obj.blank?

      # we have a match, now we need to parse the template variables and convert them into the wa recommended format
      processed_parameters = match_obj.captures.map { |x| { type: 'text', text: x } }

      # no need to look up further end the search
      return [template['name'], template['namespace'], template['language'], processed_parameters]
    end
    [nil, nil, nil, nil]
  end

  # 360dialog y UnoAPI: solo el cuerpo, como siempre.
  def legacy_template_params
    [
      template_params['name'],
      template_params['namespace'],
      template_params['language'],
      build_processed_parameters(template_params['name'], template_params['processed_params'])
    ]
  end

  # feat/plantillas_whatsapp_mejoras F1: en WhatsApp Cloud la plantilla sale con TODOS sus
  # components (encabezado de texto o archivo, cuerpo, pie, botones) vía el procesador de la
  # 4.19, que también entiende el formato viejo {"1": "Juan"}. Si no hay components (la
  # plantilla no está en message_templates o no lleva variables) se arma como siempre: el JSON
  # que llega a Meta es el mismo que antes. Un dato inválido (liga mala, código > 15) deja el
  # mensaje fallido con el motivo en vez de mandarlo roto.
  def enhanced_template_params
    params = with_template_file(template_params.deep_dup)
    return [nil, nil, nil, nil] if params.nil?

    name, namespace, language, components = Whatsapp::TemplateProcessorService.new(
      channel: channel, template_params: params, message: message
    ).call
    components = build_processed_parameters(template_params['name'], template_params['processed_params']) if components.blank?
    [name, namespace, language, components]
  rescue ArgumentError => e
    message.update!(status: :failed, external_error: e.message)
    [nil, nil, nil, nil]
  end

  # El encabezado con archivo que no trae liga: el guardado en la plantilla (header.source =
  # 'template') o uno que el agente subió para este envío ('upload', con su signed_id). La liga
  # para Meta se saca AHORA (caduca en una hora) y no se guarda; en el mensaje queda la que no
  # caduca, para la burbuja. Si no hay archivo, el mensaje queda fallido con el motivo.
  # nil = no se manda.
  def with_template_file(params)
    header = params.dig('processed_params', 'header')
    return params unless header.is_a?(Hash) && %w[template upload].include?(header['source'])

    datos, error = header['source'] == 'upload' ? uploaded_file(header) : stored_template_file(params)
    if error
      message.update!(status: :failed, external_error: error)
      return
    end

    save_template_file(datos.except('media_url'))
    header.merge!(datos).except!('source', 'signed_id')
    params
  end

  def stored_template_file(params)
    resultado = ContactTrackings::TemplateHeader.for(channel, params['name'], params['language'])
    return [nil, 'La plantilla no lleva archivo en el encabezado.'] if resultado.nil?
    return [nil, resultado.error] if resultado.error.present?

    [resultado.processed_header, nil]
  end

  def uploaded_file(header)
    blob = ActiveStorage::Blob.find_signed(header['signed_id'].to_s)
    return [nil, 'El archivo subido ya no existe: vuelve a subirlo.'] if blob.nil?

    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    nombre = header['media_name'].presence || blob.filename.to_s if header['media_type'] == 'document'
    [{ 'media_url' => blob.url(expires_in: 1.hour), 'media_type' => header['media_type'], 'media_name' => nombre,
       'preview_url' => Rails.application.routes.url_helpers.rails_blob_url(blob) }.compact, nil]
  end

  def save_template_file(datos)
    atributos = message.additional_attributes.deep_dup
    atributos['template_params']['processed_params']['header'].merge!(datos)
    message.update!(additional_attributes: atributos)
  end

  def build_processed_parameters(template_name, processed_params)
    return if processed_params.blank?

    if named_parameter_template?(template_name)
      processed_params.map { |key, value| { type: 'text', parameter_name: key, text: value } }
    else
      processed_params.map { |_, value| { type: 'text', text: value } }
    end
  end

  def named_parameter_template?(template_name)
    matching_template = channel.message_templates&.find { |template| template['name'] == template_name }
    matching_template&.dig('parameter_format') == 'NAMED'
  end

  def template_match_object(template)
    body_object = validated_body_object(template)
    return if body_object.blank?

    template_match_regex = build_template_match_regex(body_object['text'])
    message.content.match(template_match_regex)
  end

  def build_template_match_regex(template_text)
    # Converts the whatsapp template to a comparable regex string to check against the message content
    # the variables are of the format {{num}} ex:{{1}}

    # transform the template text into a regex string
    # we need to replace the {{num}} with matchers that can be used to capture the variables
    template_text = template_text.gsub(/{{\d}}/, '(.*)')
    # escape if there are regex characters in the template text
    template_text = Regexp.escape(template_text)
    # ensuring only the variables remain as capture groups
    template_text = template_text.gsub(Regexp.escape('(.*)'), '(.*)')

    template_match_string = "^#{template_text}$"
    Regexp.new template_match_string
  end

  def validated_body_object(template)
    # we don't care if its not approved template
    return if template['status'] != 'approved'

    # we only care about text body object in template. if not present we discard the template
    # we don't support other forms of templates
    template['components'].find { |obj| obj['type'] == 'BODY' && obj.key?('text') }
  end

  def send_session_message
    uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    phone_number = if uuid_regex.match?(message.conversation.contact_inbox.source_id)
                     message.conversation.contact_inbox.contact.phone_number.sub('+', '')
                   else
                     message.conversation.contact_inbox.source_id
                   end
    message_id = channel.send_message(phone_number, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
