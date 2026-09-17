# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — MEJORAR LA REDACCIÓN DE LA DEFINICIÓN
# ================================================================================
# El Objetivo y el Contexto del agente, corregidos: ortografía, acentos, puntuación
# y una redacción más clara. Nada más.
#
# ⚠ POR QUÉ ESTE SERVICIO NO PUEDE "MEJORAR" EL CONTENIDO:
#   El Contexto entra al prompt del agente como BASE DE CONOCIMIENTO, y el agente lo
#   cita al cliente como si fuera cierto. Un modelo al que se le pide "mejorar" un
#   texto de negocio completa lo que le falta: le pone un horario verosímil, redondea
#   un precio, agrega una política que nadie escribió. Eso no sería una mejora de
#   redacción: sería hacerle decir al agente cosas falsas.
#   Por eso el prompt prohíbe agregar, quitar y cambiar datos, y la pantalla siempre
#   deja volver al original — la corrección se propone, no se impone.
#
# Devuelve también `notes`: qué cambió, en dos o tres renglones. Sin eso hay que
# comparar dos textos parecidos a ojo para saber qué se tocó.
# ================================================================================

class ContactTrackings::Assistant::Proofreader
  MAX_CHARS = 4000
  # Qué es cada campo, para que la corrección no le cambie la forma: el objetivo es
  # una frase y el contexto es una lista de datos.
  KINDS = {
    'objective' => 'el OBJETIVO del agente: una sola frase que dice para qué está. ' \
                   'Mantenelo en una frase.',
    'ai_context' => 'el CONTEXTO del agente: datos del negocio (horarios, versiones, precios, ' \
                    'políticas) que el agente le cita al cliente. Mantené la estructura: si son ' \
                    'renglones o una lista, siguen siendo renglones o una lista.'
  }.freeze

  def initialize(account, text:, kind:, inbox: nil)
    @text = text.to_s.strip
    @kind = KINDS.key?(kind.to_s) ? kind.to_s : 'objective'
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
  end

  def call
    return { error: :blank_text } if @text.blank?
    return { error: :too_long } if @text.length > MAX_CHARS

    respuesta = @chat.call([{ role: 'user', content: prompt }])
    return { error: :model_failed } if respuesta.blank?

    corregido = respuesta['texto'].to_s.strip
    return { error: :model_failed } if corregido.blank?

    { text: corregido, notes: Array(respuesta['cambios']).map(&:to_s).first(5), original: @text }
  end

  private

  def prompt
    <<~PROMPT
      Corregís la redacción de un campo que escribió quien administra un agente de atención
      al cliente. Es #{KINDS[@kind]}

      TEXTO:
      <<<TEXTO
      #{@text}
      TEXTO>>>

      Qué SÍ hacés: ortografía, acentos, puntuación, concordancia, y dejar las frases más
      claras y directas. Escribí en #{ContactTrackings::Assistant::Language.name_for}.

      Qué NO hacés, nunca:
        · agregar datos que el texto no dice —ni un horario, ni un precio, ni una política,
          ni un nombre—, aunque el texto parezca incompleto;
        · quitar datos, ni cambiar números, fechas, nombres propios, versiones ni montos;
        · cambiar el idioma, ni traducir;
        · cambiar el tono ni el largo: si el texto es de una frase, sigue siendo de una frase.
      Si no hay nada que corregir, devolvé el texto igual y "cambios": [].

      Respondé SOLO un JSON: {"texto": "...", "cambios": ["qué cambiaste, en pocas palabras"]}
    PROMPT
  end
end
