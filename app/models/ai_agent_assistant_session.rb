# == Schema Information
#
# Table name: ai_agent_assistant_sessions
#
#  id                   :bigint           not null, primary key
#  draft                :jsonb            not null
#  messages             :jsonb            not null
#  mode                 :string           default("interview"), not null
#  proposals            :jsonb            not null
#  step                 :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint
#  user_id              :bigint           not null
#
# Indexes
#
#  index_ai_agent_assistant_sessions_on_account_id_and_user_id  (account_id,user_id)
#  index_ai_agent_assistant_sessions_on_tracking_template_id    (tracking_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
# ================================================================================
# proyecto@ai_agent_assistant - F5
# ================================================================================
# Modelo: AiAgentAssistantSession
# Descripción: Una conversación del asistente con su borrador. El borrador es un
#              Agente IA a medio hacer; las propuestas son lo que el asistente
#              sugirió y el usuario todavía no aceptó.
# Asociaciones: account, user, tracking_template (opcional)
# ================================================================================

class AiAgentAssistantSession < ApplicationRecord
  # entrevista (de cero) · auditar (ya tengo un prompt) · ajuste (cambio puntual)
  MODES = %w[interview audit tweak].freeze

  # El borrador es un subconjunto del Agente IA: los mismos campos que se versionan.
  DRAFT_FIELDS = TrackingTemplateVersion::VERSIONED_FIELDS

  # Tope del historial que viaja al modelo. La entrevista son siete pasos; más allá
  # de esto el contexto útil ya está en el borrador, no en la charla.
  HISTORY_LIMIT = 20

  belongs_to :account
  belongs_to :user
  belongs_to :tracking_template, optional: true

  validates :mode, inclusion: { in: MODES }

  scope :recent, -> { order(updated_at: :desc) }

  def append_message(role, content, extra = {})
    self.messages = messages + [{ 'role' => role, 'content' => content.to_s,
                                  'at' => Time.current.iso8601 }.merge(extra.stringify_keys)]
  end

  # Los últimos turnos, en el formato que espera la API de chat.
  def history_for_model
    messages.last(HISTORY_LIMIT).map { |m| { role: m['role'], content: m['content'] } }
  end

  # Mueve al borrador solo los campos que el usuario aceptó. Devuelve los aplicados.
  def apply_proposals!(fields)
    wanted  = Array(fields).map(&:to_s) & DRAFT_FIELDS
    applied = proposals.select { |p| wanted.include?(p['field']) }
    return [] if applied.empty?

    self.draft = draft.merge(applied.to_h { |p| [p['field'], p['value']] })
    self.proposals = proposals.reject { |p| wanted.include?(p['field']) }
    save!
    applied
  end

  # El borrador tal y como se guardaría, partiendo del agente existente si lo hay.
  # Es lo que se le pasa al linter y al probador: lo que de verdad quedaría.
  def merged_draft
    base = tracking_template ? tracking_template.attributes.slice(*DRAFT_FIELDS) : {}
    base.merge(draft.slice(*DRAFT_FIELDS))
  end
end
