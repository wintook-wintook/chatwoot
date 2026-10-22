# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  # @waba_templates — plantillas gestionadas desde Chatwoot (tabla propia, no el JSONB).
  # FK explícita: el nombre demodulizado 'Whatsapp' infiere 'whatsapp_id', no 'channel_whatsapp_id'.
  has_many :whatsapp_templates, foreign_key: :channel_whatsapp_id, inverse_of: :channel_whatsapp, dependent: :destroy

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud unoapi].freeze
  before_validation :ensure_webhook_verify_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validate :validate_provider_config

  after_create :sync_templates

  def name
    'Whatsapp'
  end

  def provider_service
    if provider == 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    elsif provider == 'unoapi'
      Whatsapp::Providers::UnoapiService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  def messaging_window_enabled?
    provider_config['url'] == 'https://graph.facebook.com'
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  # ── diag/llamadas_whatsapp (F2) — llamadas de voz ─────────────────────────────
  # La configuración vive en provider_config (no hay columnas nuevas):
  #   calling_enabled               activadas en Chatwoot y en Meta
  #   calling_direction             both | inbound | outbound          (por omisión both)
  #   recording_enabled             grabar (P1/F7)                      (por omisión no)
  #   ring_strategy                 cascade | all_online                (por omisión cascade)
  #   calls_webhook                 auto (Chatwoot suscribió `calls`) | manual (hay que
  #                                 marcar `calls` en la App de Meta: bandejas configuradas a mano)
  # Solo la API oficial (whatsapp_cloud) tiene llamadas; unoapi y 360dialog no.
  CALLING_DIRECTIONS = %w[both inbound outbound].freeze

  def voice_calling_supported?
    provider == 'whatsapp_cloud'
  end

  def voice_enabled?
    voice_calling_supported? && provider_config['calling_enabled'] == true && account.feature_enabled?('whatsapp_calls')
  end

  def calling_direction
    CALLING_DIRECTIONS.include?(provider_config['calling_direction']) ? provider_config['calling_direction'] : 'both'
  end

  def inbound_calls_allowed?
    voice_enabled? && calling_direction != 'outbound'
  end

  def outbound_calls_allowed?
    voice_enabled? && calling_direction != 'inbound'
  end

  def recording_enabled?
    provider_config['recording_enabled'] == true
  end

  # Activa en Meta (y oculta el botón de llamar al cliente si son «solo salientes») y
  # suscribe el campo `calls` del webhook cuando Chatwoot maneja la suscripción. Se guarda
  # sin validar: la validación vuelve a consultar las credenciales en Meta y podría fallar
  # por algo ajeno, dejando la bandeja diciendo una cosa y Meta otra.
  def enable_voice_calling!(direction: calling_direction)
    raise 'Las llamadas solo funcionan con la API oficial de WhatsApp (Cloud API)' unless voice_calling_supported?
    raise 'La cuenta no tiene activadas las llamadas de WhatsApp' unless account.feature_enabled?('whatsapp_calls')

    direction = 'both' unless CALLING_DIRECTIONS.include?(direction)
    provider_service.update_calling_status('ENABLED', icon: direction == 'outbound' ? 'DISABLE_ALL' : 'DEFAULT')
    self.provider_config = provider_config.merge('calling_enabled' => true, 'calling_direction' => direction,
                                                 'calls_webhook' => subscribe_calls_webhook ? 'auto' : 'manual')
    save!(validate: false)
  end

  # Se apaga primero en Chatwoot (ya no suena nada) y después en Meta, sin frenar si Meta
  # falla: un admin no debe quedar atrapado con las llamadas prendidas.
  def disable_voice_calling!
    self.provider_config = provider_config.merge('calling_enabled' => false)
    save!(validate: false)
    provider_service.update_calling_status('DISABLED') if voice_calling_supported?
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] no se pudo apagar en Meta la bandeja #{id}: #{e.message}"
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service
  delegate :message_path, to: :provider_service
  delegate :message_update_payload, to: :provider_service
  delegate :message_update_http_method, to: :provider_service

  private

  # Solo las bandejas del registro integrado: ahí Chatwoot es dueño de la suscripción. En las
  # configuradas a mano los campos se marcan en la App de Meta (no se toca su callback).
  def subscribe_calls_webhook
    return false unless provider_config['source'] == 'embedded_signup'

    callback_url = "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/whatsapp/#{CGI.escape(phone_number)}"
    response = Whatsapp::FacebookApiClient.new.subscribe_webhook(
      provider_config['business_account_id'], provider_config['api_key'], callback_url,
      provider_config['webhook_verify_token'], subscribed_fields: %w[messages calls]
    )
    response.success?
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] no se pudo suscribir `calls` en la bandeja #{id}: #{e.message}"
    false
  end

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if %w[whatsapp_cloud unoapi].include?(provider)
  end

  def validate_provider_config
    errors.add(:provider_config, 'Invalid Credentials') unless provider_service.validate_provider_config?
  rescue HTTParty::Error => e
    errors.add(:provider_config, e.message)
  rescue SocketError, Errno::ECONNREFUSED
    errors.add(:provider_config, 'Conection refused, verify Whatsapp Cloud API URL field')
  end
end
