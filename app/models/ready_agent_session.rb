# frozen_string_literal: true

# rubocop:disable Layout/LineLength -- la anotación del índice parcial (generada) pasa de 150
# == Schema Information
#
# Table name: ready_agent_sessions
#
#  id              :bigint           not null, primary key
#  answers         :jsonb            not null
#  last_error      :text
#  log             :jsonb            not null
#  outcome         :text
#  status          :string           default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint
#  conversation_id :bigint           not null
#  ready_agent_id  :bigint           not null
#
# Indexes
#
#  index_ready_agent_sessions_live_per_conversation  (conversation_id) UNIQUE WHERE ((status)::text = ANY ((ARRAY['active'::character varying, 'paused'::character varying])::text[]))
#  index_ready_agent_sessions_on_account_id          (account_id)
#  index_ready_agent_sessions_on_contact_id          (contact_id)
#  index_ready_agent_sessions_on_conversation_id     (conversation_id)
#  index_ready_agent_sessions_on_ready_agent_id      (ready_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (ready_agent_id => ready_agents.id)
#
# rubocop:enable Layout/LineLength

# La plática de un agente listo en una conversación: activa mientras atiende, pausada si una
# persona entró, y al final con su resultado (calificado y pasado, oportunidad, descartado,
# era cliente…). answers: lo que el prospecto contestó a las preguntas.
class ReadyAgentSession < ApplicationRecord
  LIVE = %w[active paused].freeze
  FINISHED = %w[qualified handed_off discarded client].freeze
  STATUSES = (LIVE + FINISHED).freeze
  MAX_LOG = 60

  belongs_to :account
  belongs_to :ready_agent
  belongs_to :conversation
  belongs_to :contact, optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :live, -> { where(status: LIVE) }

  # Los mensajes que este agente mandó (AiFollowUp.message_attr_sql lee content_attributes).
  def messages
    conversation.messages.where("#{AiFollowUp.message_attr_sql('ready_agent_session_id')} = ?", id.to_s)
  end

  def active? = status == 'active'
  def live? = LIVE.include?(status)

  def add_log(kind, text = nil)
    entry = { 'at' => Time.current.iso8601, 'kind' => kind.to_s, 'text' => text.to_s.first(500).presence }.compact
    self.log = (Array(log) + [entry]).last(MAX_LOG)
  end

  def pause!(by: nil)
    return false unless active?

    add_log(:paused, by&.name)
    update!(status: 'paused')
  end

  def resume!(by: nil)
    return false unless status == 'paused'

    add_log(:resumed, by&.name)
    update!(status: 'active')
  end

  def finish!(status, text)
    add_log(status, text)
    update!(status: status, outcome: text)
  end
end
