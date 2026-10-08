# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA PILA DE PRUEBAS: CALIFICAR (M5 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Una respuesta real del agente contra lo que tenía que cumplir: la «Verificación» de la
# regla (o la ruta esperada) y, siempre, el [ESTILO] y el [PROHIBIDO] del Entrenamiento.
# En la pila a mano de ADAM eso fue lo que se miró: usted o tú, una sola pregunta, sin
# precios, sin prometer acciones que no hace.
#
# La ruta no la califica la IA: la dice la #etiqueta con la que cerró (código).
# ================================================================================

class ContactTrackings::Assistant::TestBatteryJudge
  SECTION_RE = ->(nombre) { /^\[#{nombre}\]\s*\n(.*?)(?=^\[[A-ZÁÉÍÓÚÑ ]+\]\s*$|\z)/m }
  TAG_RE = /#([a-z0-9_]+)/i

  PROMPT = <<~PROMPT
    Calificas UNA respuesta de un agente de IA que atiende clientes por chat. Recibes lo que
    escribió el cliente, lo que contestó el agente, lo que esa prueba tenía que cumplir y las
    reglas de estilo y prohibiciones del agente. Sé estricto y concreto: una falla es algo que
    la respuesta hace o deja de hacer, citando la parte.
    Contesta SOLO el JSON: {"cumple": true|false, "fallas": ["…"], "motivo": "una línea"}
  PROMPT

  def initialize(account, training:)
    @account = account
    @estilo = training.to_s[SECTION_RE.call('ESTILO'), 1].to_s.strip
    @prohibido = training.to_s[SECTION_RE.call('PROHIBIDO'), 1].to_s.strip
  end

  # { cumple:, fallas: [], motivo:, ruta_ok: true|false|nil } — nil si no hubo respuesta.
  def call(scenario, reply)
    return { cumple: false, fallas: ['No contestó.'], motivo: 'Sin respuesta del agente.' } if reply.blank?

    raw = ask(scenario, reply)
    { cumple: raw.is_a?(Hash) ? raw['cumple'] == true : nil, fallas: Array(raw.is_a?(Hash) ? raw['fallas'] : nil).map(&:to_s),
      motivo: raw.is_a?(Hash) ? raw['motivo'].to_s : 'No se pudo calificar.', ruta_ok: route_ok(scenario, reply) }
  end

  attr_reader :usage

  private

  def ask(scenario, reply)
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    raw = chat.call([{ role: 'system', content: PROMPT }, { role: 'user', content: <<~TXT }], max_tokens: 600, temperature: 0.0)
      CLIENTE: #{scenario.message}
      AGENTE: #{reply}
      TENÍA QUE CUMPLIR: #{scenario.check}
      ESTILO DEL AGENTE:
      #{@estilo.presence || '(no tiene)'}
      PROHIBIDO PARA EL AGENTE:
      #{@prohibido.presence || '(no tiene)'}
    TXT
    @usage = chat.last_usage
    raw
  end

  # La etiqueta con la que cerró dice la ruta. Solo en las pruebas de ruta con etiqueta.
  def route_ok(scenario, reply)
    return nil if scenario.kind != 'ruta' || scenario.tag.blank?

    reply.scan(TAG_RE).flatten.map(&:downcase).include?(scenario.tag.downcase)
  end
end
