# frozen_string_literal: true

# Motor 2.0 — la ficha 2.0 como la ve la pantalla (y como se guarda en una versión).
module Motor2::AgentJson
  COLUMNS = %w[id name customer_display_name objective ai_context inbox_id email_signature retry_interval_value
               retry_interval_unit calendar_event_duration timezone engine testing].freeze

  module_function

  def call(template)
    template.attributes.slice(*COLUMNS).merge(
      'motor2' => template.motor2.to_h,
      'whatsapp_templates' => Array(template.whatsapp_templates),
      'keyword_actions' => Array(template.keyword_actions),
      'calendar_integration_ids' => Array(template.calendar_integration_ids).map(&:to_i),
      'attempts' => template.follow_up_attempts,
      'file_rules' => template.file_rules,
      'attachments' => template.ai_agent_attachments.order(:name).map { |a| { id: a.id, name: a.name } },
      'inbox_name' => template.inbox&.name, 'updated_at' => template.updated_at
    )
  end

  # Lo editable (lo que restaura una versión).
  def snapshot(template)
    call(template).except('id', 'engine', 'testing', 'attachments', 'inbox_name', 'updated_at')
  end
end
