# == Schema Information
#
# Table name: channel_tiktok
#
#  id                       :bigint           not null, primary key
#  access_token             :string           not null
#  expires_at               :datetime         not null
#  refresh_token            :string           not null
#  refresh_token_expires_at :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  business_id              :string           not null
#
# Indexes
#
#  index_channel_tiktok_on_account_id_and_business_id  (account_id,business_id) UNIQUE
#  index_channel_tiktok_on_business_id                 (business_id) UNIQUE
#

# Canal de mensajes directos de TikTok, contra la TikTok Business API.
#
# A diferencia de los canales de Meta, aquí el token de acceso dura ~1 día y viene
# acompañado de un token de refresco con su propia caducidad. Nunca se lee `access_token`
# a pelo: se pide `validated_access_token`, que lo renueva si hace falta.
# Ver: docs/tiktok_plan.md
class Channel::Tiktok < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_tiktok'
  EDITABLE_ATTRS = [:business_id, :access_token, :refresh_token, :expires_at, :refresh_token_expires_at].freeze

  # Una sola autorización fallida basta para pedir reautorización: si el token de refresco
  # ya no vale, no hay nada que reintentar.
  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :business_id, presence: true, uniqueness: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :refresh_token_expires_at, presence: true

  def name
    'Tiktok'
  end

  # TikTok impone una ventana de 48 h para responder a un usuario.
  def messaging_window_enabled?
    true
  end

  # Único punto de acceso al token. Renueva de forma perezosa (ver Tiktok::TokenService):
  # con tokens de un día, comprobarlo en cada uso es más fiable que un job programado.
  def validated_access_token
    Tiktok::TokenService.new(channel: self).access_token
  end
end
