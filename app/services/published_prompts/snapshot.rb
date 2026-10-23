# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts — LA FOTO QUE SE PUBLICA DE UN AGENTE IA
# ================================================================================
# Arma los atributos de PublishedPrompt a partir de un TrackingTemplate, con SOLO lo que
# puede viajar a otra cuenta. Lo atado a la cuenta del autor se queda fuera a propósito:
#
#   inbox_id, user_id, kbase_hook_id, calendar_integration_ids, booking_calendar_ids,
#   whatsapp_templates, tags, ai_agent_attachments
#
# training_structure tampoco viaja: TrackingTemplate la regenera del texto al guardar.
# Plan (tabla "Qué viaja y qué no"): docs/publicar_prompts_plan.md
# ================================================================================

class PublishedPrompts::Snapshot
  # Ajustes del agente que no dependen de la cuenta.
  SETTINGS = %w[retry_interval_value retry_interval_unit slots_presentation calendar_event_duration timezone].freeze

  def initialize(template)
    @template = template
  end

  def attributes
    {
      objective: @template.objective,
      ai_context: @template.ai_context,
      prompt: @template.complementary_prompt.to_s,
      keyword_actions: Array(@template.keyword_actions),
      settings: @template.attributes.slice(*SETTINGS).compact_blank,
      requirements: PublishedPrompts::Requirements.detect(@template.complementary_prompt, @template.ai_context)
    }
  end
end
