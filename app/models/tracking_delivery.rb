# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_deliveries
#
#  id                   :bigint           not null, primary key
#  attempt_number       :integer          not null
#  delivered_at         :datetime
#  error_code           :string
#  error_kind           :string
#  error_title          :text
#  failed_at            :datetime
#  kind                 :string           not null
#  next_retry_at        :datetime
#  read_at              :datetime
#  repetition           :integer          default(0), not null
#  retry_count          :integer          default(0), not null
#  sent_at              :datetime
#  status               :string           default("sent"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  contact_tracking_id  :bigint           not null
#  message_id           :bigint
#  source_id            :string
#  tracking_campaign_id :bigint
#
# Indexes
#
#  index_tracking_deliveries_on_account_id                       (account_id)
#  index_tracking_deliveries_on_contact_tracking_id              (contact_tracking_id)
#  index_tracking_deliveries_on_message_id                       (message_id) UNIQUE
#  index_tracking_deliveries_on_source_id                        (source_id)
#  index_tracking_deliveries_on_tracking_campaign_id             (tracking_campaign_id)
#  index_tracking_deliveries_on_tracking_campaign_id_and_status  (tracking_campaign_id,status)
#  index_tracking_deliveries_pending_confirmation                (sent_at) WHERE ((status)::text = 'sent'::text)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (contact_tracking_id => contact_trackings.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (tracking_campaign_id => tracking_campaigns.id) ON DELETE => nullify
#
# ================================================================================
# proyecto@automatizacion_campanas
# Modelo: TrackingDelivery
# ================================================================================
# Un registro por cada envío real de un seguimiento por WhatsApp (plan de campañas,
# Fase 1: docs/campanas_agentes_ia_capacidad_plan.md §13). "Enviado" solo significa que
# Meta aceptó la petición; el webhook de estado del mensaje mueve el registro a
# delivered / read / failed (ver Message#sync_tracking_delivery).
#
#   attempt_number  intento del seguimiento (attempt_count + 1 al enviar)
#   repetition      response_adjustments_count al enviar (modo reintento por reagenda)
#   retry_count     cuántas veces se reenvió este mismo intento por un fallo temporal
#   next_retry_at   presente cuando el fallo programó un reenvío
#   error_kind      ver TrackingDeliveries::ErrorClassifier
#
# El estado solo avanza: un webhook viejo nunca pisa a uno nuevo, y si Meta confirmó la
# entrega, un "failed" que llegue después no la deshace.
# ================================================================================
class TrackingDelivery < ApplicationRecord
  STATUSES = %w[sent delivered read failed unconfirmed].freeze
  KINDS = %w[template session].freeze
  # Orden de avance; failed solo aplica sobre sent / unconfirmed.
  STATUS_RANK = { 'sent' => 0, 'unconfirmed' => 0, 'failed' => 1, 'delivered' => 2, 'read' => 3 }.freeze
  UNCONFIRMED_AFTER = 24.hours

  belongs_to :account
  belongs_to :contact_tracking
  belongs_to :tracking_campaign, optional: true
  belongs_to :message, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }

  # Grupo de entrega que ve la pantalla de campañas (1 por prospecto, su último envío).
  def self.bucket(status, next_retry_at = nil)
    case status
    when 'delivered', 'read' then 'delivered'
    when 'unconfirmed'       then 'unconfirmed'
    when 'failed'            then next_retry_at.present? ? 'retrying' : 'failed'
    else                          'sent'
    end
  end

  def bucket
    self.class.bucket(status, next_retry_at)
  end

  def failed?
    status == 'failed'
  end

  # "Meta 131026: Message undeliverable" — mismo formato que last_error del seguimiento.
  def error_summary
    return if error_code.blank? && error_title.blank?

    "Meta #{[error_code, error_title].compact_blank.join(': ')}".truncate(250)
  end

  # Aplica el estado que reporta el mensaje. Devuelve true si cambió.
  def apply_message_status!(new_status, external_error = nil, at = Time.current)
    new_status = new_status.to_s
    return false unless advances_to?(new_status)

    attrs = { status: new_status, "#{new_status}_at": at }
    attrs.merge!(self.class.error_attributes(external_error)) if new_status == 'failed'
    attrs[:delivered_at] = at if new_status == 'read' && delivered_at.nil?
    update!(attrs)
    true
  end

  def advances_to?(new_status)
    return %w[sent unconfirmed].include?(status) if new_status == 'failed'

    STATUS_RANK.key?(new_status) && STATUS_RANK[new_status] > STATUS_RANK.fetch(status, 0)
  end

  # external_error llega como "131026: Message undeliverable" (webhook) o como el cuerpo
  # JSON de la respuesta de Meta (rechazo al momento del envío).
  def self.parse_error(raw)
    return {} if raw.blank?

    error = begin
      JSON.parse(raw)['error']
    rescue JSON::ParserError, TypeError
      nil
    end
    return { code: error['code'].to_s, title: error.dig('error_data', 'details') || error['message'] } if error.is_a?(Hash)

    match = raw.to_s.match(/\A(\d+):\s*(.*)\z/m)
    match ? { code: match[1], title: match[2].strip } : { code: nil, title: raw.to_s }
  end

  def self.error_attributes(external_error)
    parsed = parse_error(external_error)
    {
      error_code: parsed[:code],
      error_title: parsed[:title]&.truncate(500),
      error_kind: TrackingDeliveries::ErrorClassifier.kind(parsed[:code])
    }
  end
end
