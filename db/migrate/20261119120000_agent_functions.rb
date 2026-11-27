# frozen_string_literal: true

# Motor 2.0 — agentes por función (Plan-Motor-Agentes.md §11.14). Cada agente de la lista sabe de
# qué función es («Atención a prospectos»…) y se edita con el asistente de esa función. Los campos
# especiales de cada función van en motor2['answers'] (lo que se contestó en el asistente).
#   agent_function    'prospects' | … | 'custom' (a medida 2.0); nil en los 1.0
#   attending         atiende a quien escribe a sus bandejas (prendido / apagado)
#   attend_inbox_ids  las bandejas que atiende sin automatización (un agente principal por bandeja)
#
# Y pasa los agentes listos de antes (ready_agents) a la lista: cada uno queda como agente 2.0 de
# «Atención a prospectos» con su nombre, bandejas, respuestas y prendido o apagado; sus pláticas
# vivas siguen con el agente nuevo. El agente listo de antes se apaga y guarda a dónde pasó
# (settings.moved_to); sus tablas se quedan de respaldo.
class AgentFunctions < ActiveRecord::Migration[7.0]
  class OldAgent < ApplicationRecord
    self.table_name = 'ready_agents'
  end

  class OldSession < ApplicationRecord
    self.table_name = 'ready_agent_sessions'
  end

  LIVE = %w[active paused].freeze

  def up
    add_column :tracking_templates, :agent_function, :string
    add_column :tracking_templates, :attending, :boolean, null: false, default: false
    add_column :tracking_templates, :attend_inbox_ids, :bigint, array: true, null: false, default: []
    add_index :tracking_templates, :attend_inbox_ids, using: :gin
    execute("UPDATE tracking_templates SET agent_function = 'custom' WHERE engine = '2'")
    TrackingTemplate.reset_column_information
    ContactTracking.reset_column_information
    move_ready_agents
  end

  def down
    remove_index :tracking_templates, :attend_inbox_ids
    remove_column :tracking_templates, :attend_inbox_ids
    remove_column :tracking_templates, :attending
    remove_column :tracking_templates, :agent_function
  end

  private

  def move_ready_agents
    OldAgent.where(kind: 'prospects').find_each do |old|
      next if old.settings.to_h['moved_to'].present?

      template = move_agent(old)
      move_sessions(old, template)
      old.update_columns(enabled: false, settings: old.settings.to_h.merge('moved_to' => template.id)) # rubocop:disable Rails/SkipsModelValidations
    rescue StandardError => e
      say("Agente listo ##{old.id} (#{old.name}) no se pasó: #{e.class}: #{e.message}")
    end
  end

  def move_agent(old)
    settings = old.settings.to_h
    data = { 'answers' => Motor2::Functions::Prospects.sanitize(settings), 'instructions' => settings['instructions'].to_s.strip }
    template = TrackingTemplate.new(agent_attributes(old).merge(motor2: data))
    minutes = data.dig('answers', 'appointment_minutes').to_i
    template.calendar_event_duration = minutes if minutes.positive?
    template.save!
    template
  end

  def agent_attributes(old)
    { account_id: old.account_id, user_id: old.created_by_id, name: free_name(old), customer_display_name: old.name.to_s.first(30),
      objective: Motor2::Functions.entry('prospects')['objective'], engine: Motor2::ENGINE, agent_function: 'prospects',
      attending: old.enabled, attend_inbox_ids: Array(old.inbox_ids), inbox_id: Array(old.inbox_ids).first }
  end

  # El nombre de la lista es único por cuenta: si ya hay un agente con ese nombre, se le agrega la función.
  def free_name(old)
    names = TrackingTemplate.where(account_id: old.account_id).pluck(:name).map(&:downcase)
    [old.name, "#{old.name} (Atención a prospectos)", "#{old.name} (#{old.id})"]
      .map { |n| n.to_s.first(100) }.find { |n| names.exclude?(n.downcase) }
  end

  def move_sessions(old, template)
    OldSession.where(ready_agent_id: old.id, status: LIVE).find_each do |session|
      conversation = Conversation.find_by(id: session.conversation_id)
      next unless conversation

      state = { 'answers' => session.answers.to_h }
      state['appointment'] = { 'meeting_id' => session.case_meeting_id } if session.case_meeting_id
      ContactTracking.create!(
        account_id: conversation.account_id, contact_id: conversation.contact_id, conversation_id: conversation.id,
        inbox_id: conversation.inbox_id, tracking_template_id: template.id, objective: template.objective,
        ai_context: template.objective, status: session.status, max_attempts: 1,
        scheduled_for: Motor2::InboxRouter::NO_ATTEMPTS.from_now, motor2_state: state
      )
    rescue ActiveRecord::RecordInvalid => e
      say("Plática ##{session.id} no se pasó: #{e.message}")
    end
  end
end
