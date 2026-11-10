# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — ✨ PROPONER EL OBJETIVO Y EL CONTEXTO CON IA
# ================================================================================
# Pedido del usuario (09/11/2026): «¿se puede generar el contexto IA y el objetivo con lo
# que se va capturando?». UNA llamada a OpenAI por clic (gpt-4o: gpt-4o-mini no respeta
# las reglas, medido en KBase), con lo que la persona ya marcó y escribió:
#
#   nombre · lo que podrá hacer (ofertas) · qué tiene cada recurso · tono · notas del negocio
#
# Regresa { objective:, ai_context:, missing: [...] }. El contexto lleva SOLO datos que
# salen de lo capturado: lo que falte (horario, dirección…) va en `missing` para que la
# pantalla lo pida, nunca como <PENDIENTE:> dentro del texto (al agente no le debe llegar
# un hueco). nil si no hay llave de OpenAI o la llamada falla.
# ================================================================================

class ContactTrackings::Ficha::Suggester
  MODEL = 'gpt-4o'
  MAX_OBJECTIVE = 500
  MAX_CONTEXT = 800
  MAX_MISSING = 5

  PROMPT = <<~TXT
    Eres quien configura un Agente IA que atiende clientes por chat (WhatsApp, web, correo) en
    español de México. Con los datos que te paso escribe dos campos de su ficha:

    "objective": para qué es el agente, en 1 o 2 frases (máximo 400 caracteres), empezando con
    un verbo («Atender…», «Cotizar…»). Menciona lo que de verdad puede hacer con sus recursos.

    "ai_context": lo que el agente debe saber del negocio, UN dato por línea, en frases cortas
    (máximo 700 caracteres en total). Solo datos que estén en NOTAS DEL NEGOCIO o que salgan
    de los recursos (qué vende, qué servicios, qué información consulta). NUNCA inventes
    teléfonos, direcciones, horarios, precios, nombres ni promociones. NO describas cómo
    trabaja el agente ni sus herramientas (hojas, agenda, tickets, respuestas predefinidas):
    eso ya está en su Entrenamiento. Habla del NEGOCIO: qué es, qué ofrece, a quién atiende,
    dónde, y los datos útiles que se ven en el contenido de sus recursos.

    "missing": hasta 5 datos que un cliente suele preguntar y que NO están (por ejemplo
    "horario de atención", "dirección", "formas de pago"), en minúsculas y cortos.

    Escribe en tú, sin «Chatwoot» y sin mencionar directivas ni nombres técnicos.
    Responde SOLO con JSON: {"objective": "...", "ai_context": "...", "missing": ["..."]}
  TXT

  # options: cards: (Catalog#call), business:, tone:
  def initialize(account:, name:, offers:, **options)
    @account = account
    @name = name.to_s.squish.presence || 'el negocio'
    @offers = offers
    @cards = Array(options[:cards])
    @business = options[:business].to_s.strip
    @tone = options[:tone].to_s
    @display_name = options[:display_name].to_s.squish
    @welcome = options[:welcome].to_s.strip
    @welcome_files = Array(options[:welcome_files]).map(&:to_s).compact_blank
  end

  # mode: :fields (objetivo + contexto) | :welcome (mensaje de bienvenida)
  def call(mode = :fields)
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    return nil if chat.api_key.blank?

    sistema, usuario = mode == :welcome ? [WELCOME_PROMPT, welcome_datos] : [PROMPT, datos]
    respuesta = chat.call([{ role: 'system', content: sistema }, { role: 'user', content: usuario }],
                          model: MODEL, max_tokens: 700, temperature: 0.3)
    return nil if respuesta.nil?

    mode == :welcome ? { welcome: welcome_text(respuesta['welcome']) } : clean(respuesta)
  end

  # La bienvenida la manda el motor TAL CUAL en el primer mensaje (WelcomeMessage).
  WELCOME_PROMPT = <<~TXT
    Escribe el MENSAJE DE BIENVENIDA de un Agente IA que atiende por chat (WhatsApp, web) en
    español de México, de tú. Es lo primero que lee el cliente y se manda tal cual.

    - Máximo 3 líneas cortas. Saluda, di quién eres (con el nombre que ve el cliente, si hay)
      y de qué negocio, menciona en pocas palabras lo que puedes hacer y termina con una
      pregunta abierta para que el cliente diga qué necesita.
    - Si te dan un TEXTO ACTUAL, mejóralo: respeta su intención y sus datos, hazlo más claro y
      cálido; no inventes datos nuevos (precios, horarios, promociones, teléfonos).
    - Si van ARCHIVOS con la bienvenida, menciónalos con naturalidad («te comparto nuestro
      catálogo»), sin escribir llaves ni nombres técnicos.
    - Un emoji como máximo. Sin «Chatwoot», sin firmas.
    Responde SOLO con JSON: {"welcome": "..."}
  TXT
  MAX_WELCOME = 600

  private

  def datos
    [
      "NOMBRE DEL AGENTE: #{@name}",
      "TONO: #{@tone.presence || 'cercano'}",
      "LO QUE PODRÁ HACER:\n#{offer_lines}",
      "QUÉ TIENEN SUS RECURSOS:\n#{resource_lines.presence || '- (sin detalle)'}",
      "NOTAS DEL NEGOCIO (escritas por la persona):\n#{@business.presence || '(ninguna)'}"
    ].join("\n\n")
  end

  # Lo que hay dentro de cada recurso usado: columnas, títulos, temas de los grupos.
  def resource_lines
    usadas = @offers.pluck(:key).map { |k| k.to_s.split(':').first(2).join(':') }
    @cards.select { |c| usadas.any? { |k| k.start_with?(c[:key].to_s) || c[:key].to_s.start_with?(k) } }
          .first(15).map { |c| "- #{c[:name]}: #{[c[:summary], *Array(c[:examples]).first(2)].compact.join(' | ').truncate(220)}" }
          .join("\n")
  end

  def welcome_datos
    archivos = @welcome_files.map { |f| f.tr('_-', '  ') }.join(', ')
    [
      "NEGOCIO / AGENTE: #{@name}",
      "NOMBRE QUE VE EL CLIENTE: #{or_none(@display_name)}",
      "TONO: #{@tone.presence || 'cercano'}",
      "LO QUE PUEDE HACER:\n#{offer_lines}",
      "ARCHIVOS QUE VAN CON LA BIENVENIDA: #{or_none(archivos)}",
      "TEXTO ACTUAL:\n#{@welcome.presence || '(vacío: propón uno)'}"
    ].join("\n\n")
  end

  def or_none(texto) = texto.presence || '(ninguno)'

  def offer_lines = @offers.map { |o| "- #{public_label(o)}" }.join("\n").presence || '- (nada marcado)'

  # Sin nombres de personas: «Agenda de José Luis» no es algo que el cliente deba leer.
  def public_label(oferta) = oferta[:kind] == 'calendar' ? 'Agendar citas' : oferta[:label]

  # Sin llaves (el sistema agrega {{archivo}}) ni marcas de pendiente.
  def welcome_text(texto)
    texto.to_s.gsub(/\{\{[^}]*\}\}/, '').lines.map(&:rstrip).grep_v(/<\s*PENDIENTE/i).join("\n").strip.first(MAX_WELCOME)
  end

  def clean(respuesta)
    {
      objective: respuesta['objective'].to_s.squish.truncate(MAX_OBJECTIVE, omission: '…'),
      ai_context: context(respuesta['ai_context']),
      missing: Array(respuesta['missing']).map { |m| m.to_s.squish.downcase }.compact_blank.first(MAX_MISSING)
    }
  end

  # Un dato por línea, sin marcas de pendiente, hasta lo que el motor alcanza a leer.
  def context(texto)
    # Un párrafo se parte por frases: el modelo a veces no respeta «uno por línea».
    lineas = texto.to_s.split(/\n|(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡])/).map(&:strip).compact_blank.grep_v(/<\s*PENDIENTE/i)
    lineas.join("\n").first(MAX_CONTEXT)
  end
end
