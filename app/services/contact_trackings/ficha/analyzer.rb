# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — ✨ ANALIZAR UNA HOJA O UN TIPO DE TICKET CON IA
# ================================================================================
# Pedido del usuario (10/11/2026): «el botón para que analice el archivo para que la IA
# genere el texto de ¿Para qué la usa el agente?» y «usar la IA para ¿Cuándo se levanta
# un ticket?». Una llamada a gpt-4o por clic (como Ficha::Suggester).
#   sheet(hoja)        → { purpose:, search_by:, answer_with: [] }   (solo columnas reales)
#   ticket(tipo)       → { reasons: [] }                             (en palabras del cliente)
# nil si no hay OpenAI o falla.
# ================================================================================

class ContactTrackings::Ficha::Analyzer
  MODEL = 'gpt-4o'
  SAMPLE_ROWS = 12

  SHEET_PROMPT = <<~TXT
    Te paso una hoja de cálculo que un Agente IA (chat con clientes, español de México) va a
    consultar. Decide para qué le sirve al agente y cómo buscar en ella:
    - "purpose": en 1 o 2 frases (máx. 200 caracteres), qué contiene y qué contesta el agente
      con ella («Lista de precios de grúas por zona: contestar el precio exacto»).
    - "search_by": la columna por la que se busca lo que pide el cliente (un nombre, un
      producto, un código); EXACTAMENTE como viene en COLUMNAS.
    - "answer_with": 1 a 3 columnas con que se contesta (precio, existencia, fecha…);
      EXACTAMENTE como vienen en COLUMNAS y distintas de search_by.
    No inventes columnas. Responde SOLO JSON: {"purpose": "...", "search_by": "...", "answer_with": ["..."]}
  TXT

  TICKET_PROMPT = <<~TXT
    Un Agente IA (chat con clientes, español de México) puede levantar un ticket de un tipo
    para que lo atienda una persona. Escribe de 3 a 6 MOTIVOS por los que el agente lo
    levantaría, en palabras del cliente y en tercera persona corta («reporta una falla en
    el sistema», «quiere hablar con una persona», «pide una cotización formal»). Usa el
    nombre del tipo, los datos que pide y lo que hace el agente. Sin paréntesis ni comas
    dentro de un motivo. Responde SOLO JSON: {"reasons": ["...", "..."]}
  TXT

  QUESTIONS_PROMPT = <<~TXT
    Un Agente IA (chat con clientes, español de México, de tú) necesita hacer algunas
    preguntas, UNA A LA VEZ, para atender bien (calificar, cotizar, agendar). Propón de 2 a
    5 preguntas cortas en el orden en que conviene hacerlas. Para cada una:
    - "text": la pregunta tal como se le escribe al cliente.
    - "var": nombre en MAYÚSCULAS donde se guarda la respuesta (SISTEMA, CIUDAD, USUARIOS).
    - "options": las respuestas posibles si son pocas y fijas (["Sí","No"], ["CONTPAQi","Aspel","Otro"]);
      [] si la respuesta es libre (un nombre, una fecha, una cantidad).
    No preguntes lo que el agente ya sabe por sus recursos. Responde SOLO JSON:
    {"questions": [{"text": "...", "var": "...", "options": []}]}
  TXT

  def initialize(account, agent_name: nil, offers: [])
    @account = account
    @agent_name = agent_name.to_s.squish
    @offers = Array(offers)
  end

  def sheet(hoja)
    filas = hoja.google_sheet_rows.order(:row_index).limit(SAMPLE_ROWS).map(&:data)
    columnas = filas.first&.keys || []
    return nil if columnas.empty?

    respuesta = ask(SHEET_PROMPT, sheet_data(hoja, columnas, filas))
    config = respuesta && ContactTrackings::Ficha::SheetUse.clean(respuesta, columnas)
    config&.merge('answer_with' => Array(config['answer_with']))
  end

  def ticket(tipo)
    campos = tipo.case_type_fields.map(&:label).compact_blank
    datos = "AGENTE: #{agent}\nTIPO DE TICKET: #{tipo.name}\n" \
            "DATOS QUE PIDE: #{campos.join(', ').presence || '(ninguno)'}\n" \
            "LO QUE HACE EL AGENTE:\n#{@offers.map { |o| "- #{o[:label]}" }.join("\n").presence || '- (nada marcado)'}"
    respuesta = ask(TICKET_PROMPT, datos)
    respuesta && ContactTrackings::Ficha::TicketUse.clean('reasons' => respuesta['reasons'])
  end

  def questions(objective: nil)
    datos = "AGENTE: #{agent}\nOBJETIVO: #{objective.presence || '(sin objetivo)'}\n" \
            "LO QUE HACE EL AGENTE:\n#{@offers.map { |o| "- #{o[:label]}" }.join("\n").presence || '- (nada marcado)'}"
    respuesta = ask(QUESTIONS_PROMPT, datos)
    respuesta && { 'questions' => ContactTrackings::Ficha::Questions.clean(respuesta['questions']) }
  end

  private

  def agent = @agent_name.presence || '(sin nombre)'

  def sheet_data(hoja, columnas, filas)
    renglones = filas.map { |d| columnas.map { |c| d[c].to_s.truncate(40) }.join(' | ') }
    "AGENTE: #{agent}\nHOJA: #{hoja.name}\nCOLUMNAS: #{columnas.join(' | ')}\nFILAS:\n#{renglones.join("\n")}"
  end

  def ask(sistema, datos)
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    return nil if chat.api_key.blank?

    chat.call([{ role: 'system', content: sistema }, { role: 'user', content: datos }], model: MODEL, max_tokens: 500, temperature: 0.3)
  end
end
