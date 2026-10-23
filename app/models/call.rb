# ================================================================================
# diag/llamadas_whatsapp (F1) — UNA LLAMADA DE VOZ DE WHATSAPP
# ================================================================================
# Portado de la v4.19 (enterprise/app/models/call.rb) solo con lo de WhatsApp: sin
# conferencias de Twilio, sin push VoIP al celular, sin transcripción.
#
#   ringing ──► in_progress ──► completed
#      │                    └─► failed      (error que reporta Meta)
#      ├──► no_answer (colgó, timeout de 60 s, o el agente colgó antes)
#      ├──► rejected  (el agente rechazó)
#      └──► failed
#
# La señalización viaja en `meta`: sdp_offer / sdp_answer / ice_servers, y también
# initiated_at, ended_at y recording_enabled (copiado de la bandeja al crearla, para que
# un cambio a media llamada no la afecte).
# Plan: docs/llamadas_whatsapp_plan.md
# ================================================================================

# == Schema Information
#
# Table name: calls
#
#  id                   :bigint           not null, primary key
#  direction            :integer          not null
#  duration_seconds     :integer
#  end_reason           :string
#  meta                 :jsonb            not null
#  provider             :integer          default("whatsapp"), not null
#  ring_state           :jsonb            not null
#  started_at           :datetime
#  status               :string           default("ringing"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  accepted_by_agent_id :bigint
#  account_id           :bigint           not null
#  contact_id           :bigint           not null
#  conversation_id      :bigint           not null
#  inbox_id             :bigint           not null
#  message_id           :bigint
#  provider_call_id     :string           not null
#
# Indexes
#
#  index_calls_on_account_id_and_contact_id        (account_id,contact_id)
#  index_calls_on_account_id_and_conversation_id   (account_id,conversation_id)
#  index_calls_on_account_id_and_created_at        (account_id,created_at)
#  index_calls_on_message_id                       (message_id)
#  index_calls_on_provider_and_provider_call_id    (provider,provider_call_id) UNIQUE
#  index_calls_ringing_on_provider_and_created_at  (provider,created_at) WHERE ((status)::text = 'ringing'::text)
#

class Call < ApplicationRecord
  STATUSES = %w[ringing in_progress completed no_answer failed rejected].freeze
  TERMINAL_STATUSES = %w[completed no_answer failed rejected].freeze

  # El dashboard habla de inbound/outbound (como la v4.19), no de incoming/outgoing.
  DISPLAY_DIRECTION = { 'incoming' => 'inbound', 'outgoing' => 'outbound' }.freeze

  # El navegador necesita al menos un STUN para descubrir su IP pública ante Meta.
  DEFAULT_STUN_URL = 'stun:stun.l.google.com:19302'.freeze

  store_accessor :meta, :sdp_offer, :sdp_answer, :ice_servers, :initiated_at, :ended_at, :recording_enabled

  enum provider: { twilio: 0, whatsapp: 1 }
  enum direction: { incoming: 0, outgoing: 1 }

  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation
  belongs_to :contact
  belongs_to :message, optional: true
  belongs_to :accepted_by_agent, class_name: 'User', optional: true

  validates :provider_call_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # La decisión de grabar se toma al crearla (P1/F7): la de la bandeja en ese momento.
  before_create { self.recording_enabled = inbox&.channel.try(:recording_enabled?) || false if meta['recording_enabled'].nil? }

  # F8: al quedar perdida, sus acciones (notificación, nota, ticket…) en segundo plano.
  # Se anota al guardar: los servicios hacen merge_meta! (reload) después del update! y para
  # el commit saved_change_to_status? ya se perdió.
  after_update { @became_missed = true if saved_change_to_status? && missed? }
  after_commit :enqueue_missed_call_actions, if: -> { @became_missed }

  scope :active, -> { where.not(status: TERMINAL_STATUSES) }
  scope :ringing, -> { where(status: 'ringing') }

  def self.default_ice_servers
    urls = ENV.fetch('VOICE_CALL_STUN_URLS', DEFAULT_STUN_URL).split(',').filter_map { |u| u.strip.presence }
    [{ urls: urls }]
  end

  def ringing?
    status == 'ringing'
  end

  def in_progress?
    status == 'in_progress'
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  # Perdida = entrante que terminó sin que un agente la tomara (dispara las acciones de F8).
  def missed?
    return false unless incoming? && terminal?

    status == 'no_answer' || (%w[completed failed].include?(status) && accepted_by_agent_id.nil?)
  end

  def recording_enabled?
    recording_enabled == true
  end

  def display_status
    status.to_s.tr('_', '-')
  end

  def direction_label
    DISPLAY_DIRECTION[direction]
  end

  # Mezcla llaves en `meta` en la base, sin pisar las que otro proceso escribió desde que se
  # cargó esta copia (llegan webhooks de Meta y acciones del agente a la vez).
  def merge_meta!(values)
    self.class.where(id: id).update_all(["meta = COALESCE(meta, '{}'::jsonb) || ?::jsonb", values.to_json]) # rubocop:disable Rails/SkipsModelValidations
    reload
  end

  def from_number
    incoming? ? contact&.phone_number : inbox.channel.try(:phone_number)
  end

  def to_number
    incoming? ? inbox.channel.try(:phone_number) : contact&.phone_number
  end

  def enqueue_missed_call_actions
    @became_missed = false
    Calls::MissedCallJob.perform_later(id)
  end

  # Lo que viaja al dashboard (burbuja, widget, eventos).
  def push_event_data
    {
      id: id, provider_call_id: provider_call_id, provider: provider,
      direction: direction_label, status: display_status,
      duration_seconds: duration_seconds, end_reason: end_reason,
      accepted_by_agent_id: accepted_by_agent_id,
      accepted_by_agent_name: accepted_by_agent&.available_name,
      started_at: started_at&.to_i, ended_at: ended_at,
      from_number: from_number, to_number: to_number,
      conversation_id: conversation_id, inbox_id: inbox_id
    }
  end
end
