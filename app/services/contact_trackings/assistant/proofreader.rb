# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — MEJORAR LA REDACCIÓN DE UN CAMPO
# ================================================================================
# Un texto que escribió quien arma el agente, corregido: ortografía, acentos,
# puntuación y una redacción más clara. Nada más. Lo usan los campos de texto de la
# Estructura del Agente: Objetivo, Contexto, las frases del cliente y el alcance de
# una rama, y las instrucciones de una sección.
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
# ⚠ LAS FRASES DEL CLIENTE NO SE FORMALIZAN:
#   La descripción de una rama es LO ÚNICO con lo que el clasificador elige, y la
#   compara contra mensajes reales de clientes. "no me deja entrar" funciona;
#   "El cliente reporta problemas de acceso" no. Así que en ese campo la corrección
#   solo arregla lo que se lee mal, y deja el registro del cliente como está.
#
# ⚠ LA SINTAXIS DEL MOTOR NO SE TOCA — Y NO SE LE CREE AL MODELO QUE NO LA TOCÓ:
#   Una sección puede traer directivas (@buscar_articulo, {{doc:X}}), etiquetas
#   (#soporte) y marcas <PENDIENTE: …>. El motor las lee con patrones exactos: una
#   tilde agregada o un espacio de más las apaga en silencio. El prompt pide no
#   tocarlas, y además se COMPRUEBA: si la corrección perdió una directiva, una
#   etiqueta, una marca o un número del original, se descarta entera. Un corrector
#   de redacción que cambia un monto no se puede entregar "casi bien".
# ================================================================================

class ContactTrackings::Assistant::Proofreader
  MAX_CHARS = 6000

  # Qué es cada campo y qué forma tiene que conservar.
  KINDS = {
    'objective' => 'el OBJETIVO del agente: una sola frase que dice para qué está. ' \
                   'Mantenlo en una frase.',
    'ai_context' => 'el CONTEXTO del agente: datos del negocio (horarios, versiones, precios, ' \
                    'políticas) que el agente le cita al cliente. Mantén la estructura: si son ' \
                    'renglones o una lista, siguen siendo renglones o una lista.',
    'route_phrases' => 'las FRASES DEL CLIENTE de un tema: una lista separada por comas de cosas ' \
                       'que escribe un cliente real. Son lo único con lo que un clasificador decide ' \
                       'el tema, comparándolas con mensajes reales. NO LAS FORMALICES: siguen siendo ' \
                       'frases de cliente, cortas, en su registro —"no me deja entrar", no "el ' \
                       'cliente reporta un problema de acceso"—. Solo corrige lo que se lee mal. ' \
                       'Sigue siendo una lista separada por comas, sin punto final y sin paréntesis.',
    'route_scope' => 'QUÉ ATIENDE UN TEMA, en palabras del agente: una sola línea. Mantenla en ' \
                     'una sola línea, sin saltos.',
    'section_body' => 'las INSTRUCCIONES de una sección del prompt de un agente de atención. ' \
                      'Mantén los renglones, las viñetas y el orden de las reglas: no juntes ni ' \
                      'separes reglas, no cambies lo que una regla pide.'
  }.freeze

  # La sintaxis que el motor lee con patrones exactos, y los números: nada de esto
  # puede cambiar en una corrección de redacción.
  PROTECTED_RE = /
    @[a-z_]+(?:\([^)\n]*\))? |   # directivas: @buscar_articulo, @crear_ticket(tipo=X)
    \{\{[^}\n]+\}\} |            # {{doc:X}}, {{hoja:X}}, adjuntos {{nombre}}
    \#[a-z0-9_]+ |               # etiquetas
    <\s*(?:PENDIENTE|PENDING)[^>]*> |
    \d+(?:[.,:]\d+)*             # números, horas, versiones, montos
  /xi

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
    return { error: :changed_protected, lost: lost_tokens(corregido) } if lost_tokens(corregido).any?

    { text: corregido, notes: Array(respuesta['cambios']).map(&:to_s).first(5), original: @text }
  end

  private

  # Lo protegido del original que no aparece en la corrección (se cuenta: dos veces
  # el mismo número en el original tienen que ser dos veces en la corrección).
  def lost_tokens(corregido)
    quedan = corregido.scan(PROTECTED_RE).tally
    @text.scan(PROTECTED_RE).tally.flat_map do |token, veces|
      faltan = veces - quedan.fetch(token, 0)
      faltan.positive? ? [token] : []
    end
  end

  def prompt
    <<~PROMPT
      Corriges la redacción de un campo que escribió quien administra un agente de atención
      al cliente. Es #{KINDS[@kind]}

      TEXTO:
      <<<TEXTO
      #{@text}
      TEXTO>>>

      Qué SÍ haces: ortografía, acentos, puntuación, concordancia, y dejar las frases más
      claras y directas. Escribe en #{ContactTrackings::Assistant::Language.name_for}.

      Qué NO haces, nunca:
        · agregar datos que el texto no dice —ni un horario, ni un precio, ni una política,
          ni un nombre—, aunque el texto parezca incompleto;
        · quitar datos, ni cambiar números, fechas, nombres propios, versiones ni montos;
        · tocar lo que empieza con @, lo que va entre {{ }}, lo que empieza con # ni las
          marcas <PENDIENTE: …>: van EXACTAMENTE igual, letra por letra;
        · cambiar el idioma, ni traducir;
        · cambiar el tono ni el largo.
      Si no hay nada que corregir, devuelve el texto igual y "cambios": [].

      Responde SOLO un JSON: {"texto": "...", "cambios": ["qué cambiaste, en pocas palabras"]}
    PROMPT
  end
end
