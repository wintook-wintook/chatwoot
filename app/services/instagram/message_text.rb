class Instagram::MessageText < Instagram::WebhooksBaseService
  attr_reader :messaging

  # Códigos de Meta que hay que distinguir al leer el perfil de un contacto.
  # @see https://developers.facebook.com/docs/messenger-platform/error-codes
  TOKEN_EXPIRED    = 190  # el token dejó de valer: toca reautorizar
  CONSENT_REQUIRED = 230  # el usuario nunca escribió primero; sin consentimiento no hay perfil
  UNKNOWN_IG_USER  = 9010 # el remitente no es un usuario real (el bot revisor de Meta)

  def initialize(messaging)
    super()
    @messaging = messaging
  end

  def perform
    instagram_id, contact_id = instagram_and_contact_ids
    inbox_channel(instagram_id)
    # person can connect the channel and then delete the inbox
    return if @inbox.blank?

    # This channel might require reauthorization, may be owner might have changed the fb password
    if @inbox.channel.reauthorization_required?
      Rails.logger.info("Skipping message processing as reauthorization is required for inbox #{@inbox.id}")
      return
    end

    return unsend_message if message_is_deleted?

    ensure_contact(contact_id) if contacts_first_message?(contact_id)

    create_message
  end

  private

  def instagram_and_contact_ids
    if agent_message_via_echo?
      [@messaging[:sender][:id], @messaging[:recipient][:id]]
    else
      [@messaging[:recipient][:id], @messaging[:sender][:id]]
    end
  end

  def ensure_contact(ig_scope_id)
    result = fetch_contact_profile(ig_scope_id)

    find_or_create_contact(result) if result.present?
  end

  # El canal nativo consulta graph.instagram.com con su propio token; el legacy sigue
  # usando Koala con el token de la Página.
  def fetch_contact_profile(ig_scope_id)
    profile = if @inbox.native_instagram?
                @inbox.channel.fetch_contact_profile(ig_scope_id)
              elsif @inbox.facebook?
                Koala::Facebook::API.new(@inbox.channel.page_access_token).get_object(ig_scope_id)
              end

    profile || {}
  rescue Koala::Facebook::ClientError, ::Instagram::OauthService::OauthError => e
    handle_profile_error(e, ig_scope_id)
  rescue StandardError => e
    report_profile_error(e)
  end

  # No todo fallo al leer el perfil es una avería del canal. Tratarlos todos igual hacía
  # dos daños: marcaba la autorización como rota por errores normales, y tiraba mensajes
  # que sí se podían guardar.
  # @see https://developers.facebook.com/docs/messenger-platform/error-codes
  def handle_profile_error(error, ig_scope_id)
    case profile_error_code(error)
    when TOKEN_EXPIRED    then handle_profile_auth_error(error)
    when CONSENT_REQUIRED then skip_profile
    when UNKNOWN_IG_USER  then unknown_user(ig_scope_id)
    else report_profile_error(error)
    end
  end

  def profile_error_code(error)
    # Koala clasifica el token caducado por tipo de excepción, no siempre por código.
    return TOKEN_EXPIRED if error.is_a?(Koala::Facebook::AuthenticationError)

    (error.try(:code) || error.try(:fb_error_code)).to_i
  end

  def handle_profile_auth_error(error)
    @inbox.channel.authorization_error!
    Rails.logger.warn("Authorization error for account #{@inbox.account_id} for inbox #{@inbox.id}")
    ChatwootExceptionTracker.new(error, account: @inbox.account).capture_exception
    {}
  end

  # 230: el usuario nunca escribió primero, así que Meta no da acceso a su perfil. Es lo
  # esperado en una conversación que abrimos nosotros, no una avería: ni marca el canal ni
  # merece llegar a Sentry.
  def skip_profile
    Rails.logger.info("[Instagram] perfil no accesible sin consentimiento del usuario, inbox #{@inbox.id}")
    {}
  end

  # 9010: el remitente no es un usuario real de Instagram. Le pasa al bot con el que Meta
  # valida la app durante App Review; si no se crea contacto, la prueba de Meta no ve
  # ningún mensaje y la revisión se rechaza por "la integración no funciona".
  def unknown_user(ig_scope_id)
    Rails.logger.info("[Instagram] remitente sin perfil (9010), se crea contacto genérico: #{ig_scope_id}")
    { 'id' => ig_scope_id.to_s, 'name' => "Instagram #{ig_scope_id}" }
  end

  def report_profile_error(error)
    Rails.logger.warn("[InstagramUserFetchClientError]: account_id #{@inbox.account_id} inbox_id #{@inbox.id}")
    Rails.logger.warn("[InstagramUserFetchClientError]: #{error.message}")
    ChatwootExceptionTracker.new(error, account: @inbox.account).capture_exception
    {}
  end

  def agent_message_via_echo?
    @messaging[:message][:is_echo].present?
  end

  def message_is_deleted?
    @messaging[:message][:is_deleted].present?
  end

  # if contact was present before find out contact_inbox to create message
  def contacts_first_message?(ig_scope_id)
    @contact_inbox = @inbox.contact_inboxes.where(source_id: ig_scope_id).last
    @contact_inbox.blank? && @inbox.channel.instagram_id.present?
  end

  def unsend_message
    message_to_delete = @inbox.messages.find_by(
      source_id: @messaging[:message][:mid]
    )
    return if message_to_delete.blank?

    message_to_delete.attachments.destroy_all
    message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
  end

  def create_message
    return unless @contact_inbox

    Messages::Instagram::MessageBuilder.new(@messaging, @inbox, outgoing_echo: agent_message_via_echo?).perform
  end
end
