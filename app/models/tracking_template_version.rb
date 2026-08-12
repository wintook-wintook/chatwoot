# ================================================================================
# proyecto@ai_agent_assistant - F4
# ================================================================================
# Modelo: TrackingTemplateVersion
# Descripción: Snapshot inmutable de un Agente IA en el momento de guardarlo.
#              Permite ver qué cambió entre dos guardados y restaurar uno anterior
#              sin duplicar el agente.
# Asociaciones: account, tracking_template, user (autor, opcional)
# ================================================================================

# == Schema Information
#
# Table name: tracking_template_versions
#
#  id                   :bigint           not null, primary key
#  note                 :string
#  snapshot             :jsonb            not null
#  source               :string           default("manual"), not null
#  version              :integer          default(1), not null
#  created_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint           not null
#  user_id              :bigint
#
# Indexes
#
#  index_tracking_template_versions_on_account_id            (account_id)
#  index_tracking_template_versions_on_template_and_version  (tracking_template_id,version) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

class TrackingTemplateVersion < ApplicationRecord
  # Los campos que definen el comportamiento del agente. `archived_at` NO está: archivar
  # no es un cambio de contenido y no debe ensuciar el historial.
  VERSIONED_FIELDS = %w[
    name objective ai_context complementary_prompt inbox_id
    tags whatsapp_templates keyword_actions
    retry_interval_value retry_interval_unit
    calendar_integration_ids booking_calendar_ids
    slots_presentation calendar_event_duration timezone
  ].freeze

  # De dónde vino el guardado. `baseline` es el estado anterior reconstruido para los
  # agentes que ya existían antes de F4; sin él, el primer diff no tendría contra qué comparar.
  # `fork` = el agente nació como copia de otro. Se distingue de `create` porque su
  # v1 no es un punto de partida en blanco: tiene un original al que compararse.
  SOURCES = %w[create manual assistant restore baseline import fork].freeze

  belongs_to :account
  belongs_to :tracking_template
  belongs_to :user, optional: true

  validates :version, presence: true, uniqueness: { scope: :tracking_template_id }
  validates :source, inclusion: { in: SOURCES }
  validates :note, length: { maximum: 255 }, allow_blank: true

  scope :ordered, -> { order(version: :desc) }

  # Solo se escribe una vez: un snapshot que se puede editar no es un snapshot.
  def readonly?
    persisted?
  end

  # Los atributos del agente tal y como quedaron en este guardado.
  def self.snapshot_of(template)
    template.attributes.slice(*VERSIONED_FIELDS)
  end

  # El estado ANTERIOR al último guardado, para reconstruir la línea base de un agente
  # que ya existía antes de que hubiera versionado.
  def self.previous_snapshot_of(template)
    VERSIONED_FIELDS.index_with { |field| template.attribute_before_last_save(field) }
  end

  def author_name
    user&.available_name || user&.name
  end
end
