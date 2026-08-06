# == Schema Information
#
# Table name: channel_instagram
#
#  id              :bigint           not null, primary key
#  access_token    :string           not null
#  expires_at      :datetime
#  instagram_id    :string           not null
#  provider_config :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#
# Indexes
#
#  index_channel_instagram_on_account_id_and_instagram_id  (account_id,instagram_id) UNIQUE
#  index_channel_instagram_on_instagram_id                 (instagram_id) UNIQUE
#

# Canal nativo de Instagram (Instagram API with Instagram Login).
#
# Convive con la ruta legacy, en la que Instagram viaja dentro de Channel::FacebookPage
# a través de su columna `instagram_id`. Ambos se resuelven por el mismo webhook y el
# router da prioridad a este canal. Ver docs/instagram_plan.md
class Channel::Instagram < ApplicationRecord
  include Channelable
  include Reauthorizable
  include HTTParty

  self.table_name = 'channel_instagram'
  EDITABLE_ATTRS = [:instagram_id, :access_token, :expires_at, { provider_config: {} }].freeze

  # El token de larga duración caduca a los 60 días y se renueva con un job diario.
  TOKEN_REFRESH_THRESHOLD = 10.days

  # Campos del webhook a los que se suscribe la app para esta cuenta de Instagram.
  # @see https://developers.facebook.com/docs/instagram-platform/webhooks#enable-subscriptions
  SUBSCRIBED_FIELDS = %w[messages message_reactions messaging_seen].freeze

  validates :access_token, presence: true
  validates :instagram_id, presence: true, uniqueness: true

  # Verificar el webhook en la app de Meta NO basta: hay que suscribir la app a cada
  # cuenta de Instagram, una por una. Sin esta llamada el OAuth sale bien, el inbox se
  # crea y no llega ni un mensaje, sin ningún error a la vista.
  after_create_commit :subscribe_later
  before_destroy :unsubscribe

  def name
    'Instagram'
  end

  # Instagram impone la ventana de 24 h de forma real. Aun así, las conversaciones de este
  # canal se siguen marcando con additional_attributes.type = 'instagram_direct_message',
  # porque Conversation#can_reply? se bifurca por ese atributo para aplicar la ampliación
  # a 7 días del tag HUMAN_AGENT.
  def messaging_window_enabled?
    true
  end

  # Misma firma que Channel::FacebookPage#create_contact_inbox: los servicios de webhook
  # la invocan sin saber de qué canal se trata.
  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  # Perfil de un contacto (no de la cuenta propia). La ruta legacy hace lo mismo con Koala
  # y el token de la Página; aquí basta el token del canal.
  # Devuelve las mismas claves que Koala (id/name/username/profile_pic) para que
  # WebhooksBaseService#find_or_create_contact valga igual para ambos canales.
  def fetch_contact_profile(ig_scoped_id)
    response = HTTParty.get(
      "#{Instagram::OauthService::GRAPH_HOST}/#{api_version}/#{ig_scoped_id}",
      query: { fields: 'name,username,profile_pic', access_token: access_token }
    )

    raise profile_error(response) unless response.success?

    (response.parsed_response || {}).merge('id' => ig_scoped_id.to_s)
  end

  def token_expired?
    expires_at.present? && expires_at < Time.current
  end

  def token_about_to_expire?
    expires_at.present? && expires_at < TOKEN_REFRESH_THRESHOLD.from_now
  end

  def username
    provider_config['username']
  end

  # En segundo plano para no hacer esperar al administrador a una ida y vuelta contra Meta
  # en mitad del alta, y para poder reintentar si Meta contesta mal en ese momento.
  def subscribe_later
    Channels::Instagram::SubscribeJob.perform_later(self)
  end

  # Pide la suscripción a Meta. Es idempotente: repetirla sobre una cuenta ya suscrita no
  # rompe nada, así que puede relanzarse desde `rake instagram:subscribe` sin miedo.
  #
  # Nunca lanza: un fallo aquí no debe tumbar el alta del inbox (el token es válido y la
  # cuenta ya está conectada), pero se deja registrado en provider_config para que
  # `rake instagram:doctor` lo enseñe en vez de dejar el canal mudo sin explicación.
  def subscribe
    response = HTTParty.post(
      subscribed_apps_url,
      # Meta espera una lista separada por comas, no un array repetido en la query.
      query: { subscribed_fields: SUBSCRIBED_FIELDS.join(','), access_token: access_token }
    )

    record_subscription_result(response)
  rescue StandardError => e
    record_subscription_result(nil, e.message)
  end

  def unsubscribe
    HTTParty.delete(subscribed_apps_url, query: { access_token: access_token })
    true
  rescue StandardError => e
    Rails.logger.warn("[Instagram] unsubscribe failed for channel #{id}: #{e.message}")
    true
  end

  # ¿Meta tiene realmente la suscripción activa? Se pregunta en vivo porque la suscripción
  # vive en Meta, no aquí: alguien puede haberla quitado desde el panel de la app.
  def webhook_subscribed?
    response = HTTParty.get(subscribed_apps_url, query: { access_token: access_token })
    return false unless response.success?

    Array(response.parsed_response.try(:[], 'data')).any?
  rescue StandardError => e
    Rails.logger.warn("[Instagram] subscription check failed for channel #{id}: #{e.message}")
    false
  end

  def webhook_subscribed_at
    provider_config['webhook_subscribed_at']
  end

  def webhook_subscription_error
    provider_config['webhook_subscription_error']
  end

  private

  def subscribed_apps_url
    "#{Instagram::OauthService::GRAPH_HOST}/#{api_version}/#{instagram_id}/subscribed_apps"
  end

  # Meta responde {"success": true}; un 200 con success=false también es un fallo.
  def record_subscription_result(response, error = nil)
    error ||= subscription_error(response)

    if error.present?
      Rails.logger.warn("[Instagram] webhook subscription failed for channel #{id}: #{error}")
    else
      Rails.logger.info("[Instagram] webhook subscribed for channel #{id} (#{SUBSCRIBED_FIELDS.join(', ')})")
    end

    if persisted?
      update_columns( # rubocop:disable Rails/SkipsModelValidations
        provider_config: provider_config.merge(
          'webhook_subscribed_at' => error.present? ? nil : Time.current.iso8601,
          'webhook_subscription_error' => error
        )
      )
    end

    error.blank?
  end

  def subscription_error(response)
    return 'sin respuesta de Meta' if response.blank?

    body = response.parsed_response
    body = {} unless body.is_a?(Hash)

    return body.dig('error', 'message') || "HTTP #{response.code}" unless response.success?
    return 'Meta respondió success=false' if body.key?('success') && !body['success']

    nil
  end

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v25.0')
  end

  # El código de Meta viaja dentro del error: quien lo captura decide si es token muerto,
  # falta de consentimiento o el bot revisor. Ver Instagram::MessageText.
  def profile_error(response)
    body = response.parsed_response
    body = {} unless body.is_a?(Hash)

    Instagram::OauthService::OauthError.new(
      body.dig('error', 'message') || "HTTP #{response.code}",
      body.dig('error', 'code')
    )
  end
end
