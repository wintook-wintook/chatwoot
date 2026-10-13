# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — ASIGNAR UN AGENTE IA A UNA CONVERSACIÓN
# ================================================================================
# Crea el ContactTracking del contacto de la conversación con los datos de la plantilla
# (objective, ai_context, complementary_prompt, whatsapp_templates…). Salió de
# ActionService#assign_tracking_template para que el banco de pruebas lo use con OTRO
# canal (docs/diagnostico_asistente_agentes_ia_plan.md, P1 → «Banco de pruebas con
# agentes de canal propio»).
#
# inbox_id: el canal del seguimiento. Sin él, el de la plantilla o el de la conversación
# (lo de siempre). ContactTracking exige que la conversación sea de ese canal: con un
# agente de canal propio en una conversación de otro canal, no se crea (D20, abierta).
#
# Devuelve el seguimiento, o nil con `error`:
#   :already_active        el contacto ya tiene uno activo en ese canal (no es una falla)
#   texto                  la validación o excepción que lo impidió
# ================================================================================

class ContactTrackings::TemplateAssignment
  ACTIVE_STATUSES = %w[pending scheduled active paused].freeze

  attr_reader :error

  def initialize(conversation, template, inbox_id: nil)
    @conversation = conversation
    @template = template
    @inbox_id = inbox_id || template.inbox_id || conversation.inbox_id
  end

  def call
    @error = nil
    return already_active if ContactTracking.exists?(contact_id: @conversation.contact_id, inbox_id: @inbox_id, status: ACTIVE_STATUSES)

    ContactTracking.create!(**attributes)
  rescue StandardError => e
    @error = e.message
    nil
  end

  private

  def already_active
    @error = :already_active
    nil
  end

  def attributes
    {
      account: @conversation.account, contact: @conversation.contact, conversation: @conversation, inbox_id: @inbox_id,
      objective: @template.objective,
      ai_context: @template.ai_context.presence || @template.objective,
      complementary_prompt: @template.complementary_prompt,
      whatsapp_templates: whatsapp_templates,
      keyword_actions: @template.keyword_actions.is_a?(Array) ? @template.keyword_actions : [],
      calendar_integration_ids: @template.calendar_integration_ids.is_a?(Array) ? @template.calendar_integration_ids : [],
      tracking_template_id: @template.id,
      max_attempts: whatsapp_templates.count(&:present?).clamp(1, 10)
    }.merge(schedule)
  end

  def whatsapp_templates
    @whatsapp_templates ||= @template.whatsapp_templates.is_a?(Array) ? @template.whatsapp_templates : []
  end

  # proyecto@automatizacion_tracking: el primer intento con el mismo intervalo que los siguientes.
  def schedule
    valor = @template.retry_interval_value.presence || 1
    unidad = @template.retry_interval_unit.presence || 'days'
    minutos = { 'minutes' => valor, 'hours' => valor * 60 }.fetch(unidad, valor * 1440)
    { scheduled_for: Time.current + minutos.minutes, retry_interval_value: valor, retry_interval_unit: unidad }
  end
end
