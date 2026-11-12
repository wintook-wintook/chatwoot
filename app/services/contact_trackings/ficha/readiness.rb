# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — ¿LISTO PARA ATENDER?
# ================================================================================
# Idea 2 de «más facilidad» (09/11/2026). Crear un agente no es lo mismo que atender: un
# agente sin OpenAI, sin canal o sin nadie que se lo asigne a las conversaciones no
# contesta nunca, y quien empieza no sabe por qué. Esta lista lo dice, cada cosa con
# cómo arreglarla:
#
#   ✓ OpenAI activo                      ✗ → Integraciones
#   ✓ Canal: WhatsApp Ventas             ⚠ → elegirlo en la Ficha de Agente IA
#   ⚠ PATITAS: 2 sin vectorizar          → Respuestas predefinidas
#   ⚠ Sin datos del negocio              → ✨ Proponer con IA
#   ✓ Lo asigna «Agente IA: Ventas»      ⚠ → [Activar en WhatsApp Ventas]
#
# activate!: crea la automatización (conversación nueva en esa bandeja → Asignar Agente
# IA). Solo con el OK de la persona: desde ahí contesta a clientes reales.
# ================================================================================

class ContactTrackings::Ficha::Readiness
  ACTION = 'assign_tracking_template'

  # template: el agente (nil si todavía no existe). options: inbox: (el canal elegido),
  # ai_context: (lo capturado, para un agente nuevo).
  def initialize(account, offers:, template: nil, **options)
    @account = account
    @offers = offers
    @template = template
    @inbox = options[:inbox] || template&.inbox
    @ai_context = options.key?(:ai_context) ? options[:ai_context] : template&.ai_context
  end

  # [{ key:, status: 'ok' | 'warn' | 'error', label:, fix: }]
  def call
    [openai, channel, *resources, context, assignment].compact
  end

  def ready? = call.none? { |i| i[:status] == 'error' }

  # La automatización que le asigna ESTE agente a las conversaciones (o nil).
  def rule
    return nil if @template.nil?

    @account.automation_rules.where(active: true).find do |regla|
      Array(regla.actions).any? { |a| a['action_name'] == ACTION && Array(a['action_params']).map(&:to_s).include?(@template.id.to_s) }
    end
  end

  def activate!
    raise ArgumentError, 'sin agente o sin canal' if @template.nil? || @inbox.nil?
    return rule if rule

    @account.automation_rules.create!(
      name: "Agente IA: #{@template.name}".first(255), event_name: 'conversation_created', active: true,
      description: 'Creada desde la ficha del Agente IA: cada conversación nueva de esta bandeja la atiende el agente.',
      conditions: [{ 'values' => [@inbox.id], 'attribute_key' => 'inbox_id', 'filter_operator' => 'equal_to',
                     'custom_attribute_type' => '' }],
      actions: [{ 'action_name' => ACTION, 'action_params' => [@template.id] }]
    )
  end

  private

  def item(key, status, label, fix = nil) = { key: key, status: status, label: label, fix: fix }

  def openai
    return item('openai', 'ok', 'OpenAI activo') if @account.hooks.exists?(app_id: 'openai', status: 'enabled')

    item('openai', 'error', 'Falta activar OpenAI: sin eso el agente no puede contestar', 'integrations')
  end

  def channel
    return item('channel', 'ok', "Canal: #{@inbox.name}") if @inbox

    item('channel', 'warn', 'Sin canal: elige por dónde va a atender', 'channel')
  end

  def resources
    @offers.select { |o| o[:warning].present? }.map do |o|
      item("resource:#{o[:key]}", 'warn', "«#{o[:name]}»: #{o[:warning]}", o[:kind] == 'canned' ? 'canned' : 'knowledge_sources')
    end
  end

  def context
    return item('context', 'ok', 'Tiene datos del negocio') if @ai_context.present?

    item('context', 'warn', 'Sin datos del negocio (horario, dirección…): el agente no los sabrá', 'context')
  end

  def assignment
    return item('assignment', 'warn', 'Al crearlo podrás activarlo en su canal', 'activate') if @template.nil?

    regla = rule
    return item('assignment', 'ok', "Atiende en su canal (automatización «#{regla.name}»)") if regla

    item('assignment', 'warn', 'Todavía no atiende: nadie se lo asigna a las conversaciones', 'activate')
  end
end
