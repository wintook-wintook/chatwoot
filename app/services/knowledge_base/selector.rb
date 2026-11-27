# frozen_string_literal: true

# ================================================================================
# proyecto@predefinidas_que_contestan — ESCOGER (paso 2 de buscar y escoger)
# ================================================================================
# Ver KnowledgeBase::Selection. Una IA chica lee las candidatas que juntó
# KnowledgeBase::Candidates y escoge hasta MAX_CHOSEN que SÍ contestan, o ninguna. De cada
# una ve lo justo para decidir sin leer 30 textos completos: tipo, nombre, primera línea y
# el pedazo donde coincidió la pregunta.
#
# Estricta a propósito: una ficha de otro sujeto, una objeción cuando el cliente no objeta
# o «lo más parecido» que no trae el dato no se escogen. «Ninguna» es una respuesta útil:
# el agente dice que no tiene el dato en vez de inventarlo.
#
# Devuelve nil si la llamada falla: quien llama vuelve a la búsqueda de siempre.
#
#   KnowledgeBase::Selector.new(account).call(question:, conversation:, subjects:, candidates:)
#   → { chosen: [Candidate, …], reasons: { item_id => 'por qué' }, none: false, missing: '' }
# ================================================================================
class KnowledgeBase::Selector
  # Se puede cambiar sin desplegar (KBASE_SELECTOR_MODEL) mientras se mide cuál conviene.
  # gpt-4.1-mini: medido el 18/11/2026 contra gpt-4o-mini y gpt-4o con las preguntas que fallaban;
  # fue el que no escogió datos de otra cosa («¿cuánto cuesta el envío?» → ninguna).
  MODEL = ENV.fetch('KBASE_SELECTOR_MODEL', 'gpt-4.1-mini')
  MAX_CHOSEN = 3
  FIRST_LINE = 160
  SNIPPET = 220

  SYSTEM = <<~PROMPT.freeze
    Escoges qué respuestas predefinidas de una empresa sirven para contestar el último mensaje de un cliente.
    Recibes candidatas encontradas por parecido: muchas NO sirven. De cada una ves su número, su tipo, su nombre, su
    primera línea, las secciones que trae y el pedazo donde coincidió con la pregunta.

    Tipos:
    - general: vale igual para todos.
    - ficha: información de UN sujeto (producto, servicio, plan, sucursal, curso…); el sujeto es su nombre.
    - objecion: cómo contestar un pretexto del cliente («está caro», «lo pienso», «no tengo tiempo»).

    Reglas:
    - Escoge SOLO las que traen el dato que el cliente pide. Si una basta, escoge una; agrega otra solo si trae algo que
      falta para contestar ESTA pregunta. Máximo #{MAX_CHOSEN}, la más útil primero. Nada de «podría ser útil».
    - Si hay un sujeto en curso, no escojas nada cuyo NOMBRE sea de otro sujeto (aunque su tipo diga general), salvo que
      el cliente nombre ese otro sujeto. Si el dato del sujeto en curso no está, no lo tomes de otro.
    - Una objecion solo si el cliente está poniendo un pretexto u objetando; nunca para una pregunta de información.
    - Un mensaje corto o de seguimiento («¿y cuánto cuesta?», «¿dónde me inscribo?») sigue el tema de la conversación:
      busca el dato en las secciones de la ficha del sujeto en curso. Si esa ficha toca el tema pero no trae lo que pide
      (pide las opciones y la ficha solo trae el costo), escoge también la general que sí lo trae.
    - El dato tiene que ser de LO MISMO que pregunta el cliente. Fíjate en de qué habla cada pedazo: los costos de un
      producto no contestan el costo de un envío, un «descuento» de un trámite no es la promoción de un producto, y una
      dirección no es una liga para inscribirse.
    - Si ninguna trae lo que pide, contesta ninguna = true. Si para escogerla tendrías que decir «no trae…» o «podría»,
      no la escojas.

    Contesta SOLO este JSON:
    {"elegidas":[{"n":1,"por_que":"una línea"}],"ninguna":false,"falta":"si ninguna: qué dato no está, en pocas palabras"}
  PROMPT

  def initialize(account, api_key: nil)
    @account = account
    @api_key = api_key
  end

  def call(question:, candidates:, conversation: '', subjects: [])
    return { chosen: [], reasons: {}, none: true, missing: '' } if candidates.empty?

    @question = question
    @subjects = Array(subjects)
    terms = KnowledgeBase::Candidates.terms(question)
    lista = candidates.each_with_index.map { |c, i| describe(c, i + 1, terms) }
    out = chat.call([{ role: 'system', content: SYSTEM },
                     { role: 'user', content: user_message(question, conversation, subjects, lista) }],
                    max_tokens: 400, temperature: 0.0, model: MODEL)
    @last_usage = chat.last_usage
    parse(out, candidates)
  rescue StandardError => e
    Rails.logger.warn "[KBase] ⚠️ Selector: #{e.class}: #{e.message}"
    nil
  end

  attr_reader :last_usage

  private

  def chat
    @chat ||= ContactTrackings::Assistant::OpenaiChat.new(account: @account, api_key: @api_key)
  end

  def user_message(question, conversation, subjects, lista)
    [
      ("## Conversación reciente\n#{conversation}" if conversation.present?),
      ("## Sujeto en curso\n#{subjects.join(', ')}" if subjects.any?),
      "## Último mensaje del cliente\n#{question.to_s.truncate(500)}",
      "## Candidatas\n#{lista.join("\n")}"
    ].compact.join("\n\n")
  end

  def describe(candidate, number, terms)
    item = candidate.item
    linea = "#{number}. [#{KnowledgeBase::Selection.item_kind(item)}] #{item.title.to_s.truncate(150)}"
    inicio = first_line(item)
    pedazo = snippet(item.content, terms)
    secciones = headings(item.content)
    linea += "\n   Inicio: #{inicio}" if inicio.present?
    linea += "\n   Secciones: #{secciones.join(' · ')}" if secciones.size > 1
    linea += "\n   Donde coincide: «#{pedazo}»" if pedazo.present? && inicio.to_s.exclude?(pedazo.delete('…').strip.first(40))
    linea
  end

  # La primera línea con texto del contenido, sin el «nombre: » con que se vectoriza.
  def first_line(item)
    texto = item.content.to_s.delete_prefix("#{item.title}:").strip
    texto.lines.map(&:strip).find(&:present?).to_s.truncate(FIRST_LINE)
  end

  # Los encabezados de sus secciones (renglones cortos en mayúsculas, o que terminan en «:»),
  # para saber qué trae aunque el pedazo que coincidió no lo muestre.
  HEADING_RE = /\A[^a-záéíóúñ]{3,60}\z|\A.{3,40}:\z/

  def headings(content)
    content.to_s.lines.map(&:strip).select { |l| l.match?(HEADING_RE) && l.match?(/\p{L}{3}/) }
           .map { |l| l.delete_suffix(':') }.uniq.first(MAX_HEADINGS)
  end
  MAX_HEADINGS = 8

  # ~SNIPPET caracteres alrededor de la primera palabra de la pregunta que aparece en el texto.
  def snippet(content, terms)
    texto = content.to_s.gsub(/\s+/, ' ')
    plano = I18n.transliterate(texto).downcase
    pos = terms.filter_map { |t| plano.index(t) }.min
    return nil if pos.nil?

    inicio = [pos - (SNIPPET / 3), 0].max
    pedazo = texto[inicio, SNIPPET].to_s.strip
    "#{'…' if inicio.positive?}#{pedazo}#{'…' if inicio + SNIPPET < texto.size}"
  end

  def parse(out, candidates)
    return nil unless out.is_a?(Hash)

    picks = valid_picks(out['elegidas'], candidates)
    chosen = picks.keys.reject { |c| other_subject?(c.item) }.first(MAX_CHOSEN)
    { chosen: chosen, reasons: chosen.to_h { |c| [c.item.id, picks[c]] }, none: chosen.empty?,
      missing: out['falta'].to_s.truncate(200) }
  end

  # Candado fijo, por si la IA no lo respetó: una FICHA de otro sujeto no pasa mientras haya
  # sujeto en curso, salvo que el cliente lo nombre en este mensaje.
  def other_subject?(item)
    return false if @subjects.blank? || KnowledgeBase::Selection.item_kind(item) != 'ficha'
    return false if @subjects.any? { |s| KnowledgeBase::Selection.same_subject?(item.title, s) }

    sujeto = KnowledgeBase::Selection.key(KnowledgeBase::Selection.subject_of(item.title))
    " #{KnowledgeBase::Selection.key(@question)} ".exclude?(" #{sujeto} ")
  end

  # { candidata => por qué }, en el orden de la IA, sin repetir ni números que no existen.
  def valid_picks(elegidas, candidates)
    Array(elegidas).each_with_object({}) do |e, acc|
      n = e.is_a?(Hash) ? e['n'].to_i : 0
      next unless n.between?(1, candidates.size)

      acc[candidates[n - 1]] ||= e['por_que'].to_s.truncate(200)
    end
  end
end
