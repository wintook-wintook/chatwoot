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

  validates :access_token, presence: true
  validates :instagram_id, presence: true, uniqueness: true

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

    raise Instagram::OauthService::OauthError, profile_error(response) unless response.success?

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

  private

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v25.0')
  end

  def profile_error(response)
    body = response.parsed_response
    body = {} unless body.is_a?(Hash)

    body.dig('error', 'message') || "HTTP #{response.code}"
  end
end
