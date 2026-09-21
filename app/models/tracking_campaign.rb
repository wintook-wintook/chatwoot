# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_campaigns
#
#  id                    :bigint           not null, primary key
#  audience              :jsonb            not null
#  daily_cap             :integer
#  ends_at               :datetime
#  entry_delay_minutes   :integer          default(0), not null
#  mode                  :string           default("batch"), not null
#  name                  :string           not null
#  objective             :string
#  respect_working_hours :boolean          default(TRUE), not null
#  scheduled_for         :datetime
#  status                :string           default("running"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  inbox_id              :bigint
#  tracking_template_id  :bigint
#  user_id               :bigint
#
# Indexes
#
#  index_tracking_campaigns_on_account_id             (account_id)
#  index_tracking_campaigns_on_account_id_and_status  (account_id,status)
#  index_tracking_campaigns_on_inbox_id               (inbox_id)
#  index_tracking_campaigns_on_tracking_template_id   (tracking_template_id)
#  index_tracking_campaigns_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#  fk_rails_...  (user_id => users.id)
#

# ================================================================================
# Modelo: TrackingCampaign
# ================================================================================
# Agrupador con nombre de una asignación masiva de seguimientos (Agente IA).
# Reúne los ContactTracking creados en una misma corrida del bulk assign para
# poder medir, en el dashboard, qué pasó con la campaña (enviados, respondieron,
# agendaron, finalizados). NO es el Campaign nativo de Chatwoot (envíos).
#
# proyecto@automatizacion_campanas — LA VENTANA (docs/automatizacion_campanas_plan.md §3):
#   batch       Por lote: audiencia fija (segmento o etiqueta), tomada al crear.
#   continuous  Continua: audiencia dinámica, la inscriben las automatizaciones.
# `scheduled_for` es el INICIO de la ventana y `ends_at` su fin (opcional). Cada contacto
# que entra, o que se intentó meter, es una TrackingCampaignEntry.
# ================================================================================

class TrackingCampaign < ApplicationRecord
  STATUSES = %w[draft running paused finished].freeze
  MODES = %w[batch continuous].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :inbox, optional: true
  belongs_to :user, optional: true

  has_many :contact_trackings, dependent: :nullify
  has_many :entries, class_name: 'TrackingCampaignEntry', dependent: :delete_all

  validates :name, presence: true, length: { minimum: 2, maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  # El objective se copia de la plantilla (que permite hasta 500). Sin esta
  # validación explícita, la de ApplicationRecord lo limitaría a 255 y el
  # create! reventaría con RecordInvalid en plantillas de objective largo.
  validates :objective, length: { maximum: 500 }, allow_nil: true
  validates :mode, inclusion: { in: MODES }
  validates :entry_delay_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :daily_cap, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :window_order

  scope :active, -> { where(status: %w[draft running paused]) }

  def continuous?
    mode == 'continuous'
  end

  # ¿La ventana acepta inscripciones en este momento? Pausada y terminada, nunca; antes del
  # inicio sí: la inscripción queda programada para el inicio (plan §3.2).
  def accepting_entries?(at = Time.current)
    %w[draft running].include?(status) && (ends_at.nil? || at <= ends_at)
  end

  # Estadísticas agregadas de los seguimientos de la campaña (alimentan el dashboard).
  def stats
    grouped = contact_trackings.group(:status).count
    {
      total: grouped.values.sum,
      pending: grouped.fetch('pending', 0) + grouped.fetch('scheduled', 0),
      active: grouped.fetch('active', 0) + grouped.fetch('paused', 0),
      completed: grouped.fetch('completed', 0),
      failed: grouped.fetch('failed', 0) + grouped.fetch('cancelled', 0)
    }
  end

  private

  def window_order
    return if ends_at.blank? || scheduled_for.blank? || ends_at > scheduled_for

    errors.add(:ends_at, 'debe ser posterior al inicio')
  end
end
