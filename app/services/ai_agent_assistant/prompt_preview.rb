# frozen_string_literal: true

# ================================================================================
# proyecto@ai_agent_assistant - F3
# ================================================================================
# Servicio: AiAgentAssistant::PromptPreview
# Descripción: El «Ver prompt» del probador. Ensambla, para un Agente IA y un
#              número de intento, el system prompt EXACTO que recibiría el modelo
#              en cada una de las dos rutas.
#
# No llama a OpenAI, no crea seguimientos, no toca la base. Construye un
# ContactTracking en memoria a partir del Agente IA —igual que hacen las cuatro
# vías de creación reales, que copian estos campos— y se lo pasa al PromptBuilder,
# el mismo que usa el motor.
#
# Es la primera vez que se puede VER lo que de verdad recibe el modelo. Por eso
# devuelve también el presupuesto: un prompt de 8 000 caracteres entrando en una
# caja de 150 tokens se explica solo.
# ================================================================================

class AiAgentAssistant::PromptPreview
  SIMULATED_CONTACT_NAME = 'Juan Pérez'
  SIMULATED_MESSAGE = 'Hola, ¿me puedes dar más información?'

  def initialize(template, attempt: 1, contact_name: nil, message: nil)
    @template = template
    @attempt = [attempt.to_i, 1].max
    @contact_name = contact_name.presence || SIMULATED_CONTACT_NAME
    @message = message.presence || SIMULATED_MESSAGE
  end

  def call
    { scheduled: scheduled, conversational: conversational }
  end

  private

  attr_reader :template, :attempt, :contact_name, :message

  # Seguimiento en memoria con los campos que las vías reales copian del Agente IA.
  def simulated_tracking
    @simulated_tracking ||= ContactTracking.new(
      account: template.account,
      inbox: template.inbox,
      objective: template.objective,
      ai_context: template.ai_context,
      complementary_prompt: template.complementary_prompt,
      attempt_count: attempt - 1,
      max_attempts: max_attempts,
      scheduled_for: Time.current
    )
  end

  def max_attempts
    default = ContactTracking.column_defaults['max_attempts'] || 3
    [default.to_i, attempt].max
  end

  def scheduled
    system = AiAgentAssistant::PromptBuilder.scheduled_system(
      simulated_tracking, contact_name: contact_name
    )
    task = AiAgentAssistant::PromptBuilder.scheduled_task(
      simulated_tracking, template_content: whatsapp_template_for_attempt
    )

    section(:scheduled, system, task, notes: scheduled_notes)
  end

  def conversational
    clean_cp = AiAgentAssistant::PromptBuilder.clean_complementary_prompt(template.complementary_prompt)
    system = AiAgentAssistant::PromptBuilder.conversational_system(
      simulated_tracking,
      appointment_state: 'El contacto no tiene ninguna cita agendada.',
      next_contact: I18n.l(1.day.from_now, format: :short),
      attachment_directive: clean_cp.match?(ContactTrackingResponseAnalyzerJob::ATTACHMENT_DIRECTIVE)
    )
    user = AiAgentAssistant::PromptBuilder.conversational_user(contact_name.split.first, message)

    section(:conversational, system, user, notes: conversational_notes(clean_cp))
  end

  def section(purpose, system, user, notes:)
    {
      system: system,
      user: user,
      model: AiAgentAssistant::EngineConfig.model_for(template.inbox, purpose),
      max_tokens: AiAgentAssistant::EngineConfig.max_tokens_for(purpose),
      system_chars: system.length,
      notes: notes
    }
  end

  # Avisos que solo tienen sentido viendo el prompt ensamblado.
  def scheduled_notes
    notes = []
    notes << :uses_whatsapp_template if whatsapp_template_for_attempt.present?
    notes
  end

  def conversational_notes(clean_cp)
    notes = []
    notes << :prompt_discarded if template.complementary_prompt.present? && clean_cp.blank?
    notes << :context_truncated if template.ai_context.to_s.length > AiAgentAssistant::Linter::AI_CONTEXT_BUDGET
    notes
  end

  # El intento n usa la plantilla n-ésima, si el canal es WhatsApp y hay plantillas.
  def whatsapp_template_for_attempt
    templates = Array(template.whatsapp_templates)
    return nil if templates.empty?

    entry = templates[attempt - 1] || templates.last
    entry.is_a?(Hash) ? entry['body'].presence || entry['name'] : entry
  end
end
