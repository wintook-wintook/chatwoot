# ================================================================================
# proyecto@ai_agent_assistant - F4 · rescatado en feat/agentes_ia_unificado (21/10/2026)
# ================================================================================
# Modelo: TrackingTemplateVersion
# Descripción: Snapshot inmutable de un Agente IA en el momento de guardarlo.
#              Permite ver qué cambió entre dos guardados y restaurar uno anterior
#              sin duplicar el agente.
# Asociaciones: account, tracking_template, user (autor, opcional)
#
# Las versiones viven en el AGENTE, no en la conversación del Asistente: antes cada
# sesión tenía su propio historial suelto y lo editado desde la ficha no dejaba
# ninguno. Ahora todo guardado que cambie el comportamiento deja una versión aquí,
# con `source` diciendo desde dónde se hizo.
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
  # Los campos que definen el comportamiento del agente. Fuera quedan los derivados
  # (training_structure sale del Entrenamiento), el respaldo de una vez
  # (previous_complementary_prompt) y los datos de la Galería y de «Configurar».
  VERSIONED_FIELDS = %w[
    name objective ai_context complementary_prompt inbox_id
    tags whatsapp_templates keyword_actions
    retry_interval_value retry_interval_unit
    calendar_integration_ids booking_calendar_ids
    slots_presentation calendar_event_duration timezone kbase_hook_id
    email_signature
  ].freeze

  # Desde dónde se guardó:
  #   create     el alta del agente          manual     la ficha (a mano)
  #   assistant  el Asistente (chat/editor)  configured la pestaña «Configurar»
  #   import     importar un archivo         gallery    bajado de la Galería
  #   restore    volver a una anterior       baseline   el estado previo al versionado
  SOURCES = %w[create manual assistant configured import gallery restore baseline].freeze

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
