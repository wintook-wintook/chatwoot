# frozen_string_literal: true

# ================================================================================
# proyecto@auditoria_predefinidas — LO QUE DECIDE LA IA
# ================================================================================
# Dos preguntas, cada una con su prompt:
#
#   pair(a, b)       ¿dos vecinas son la misma, se solapan o son distintas? ¿se
#                    contradicen? Una llamada por par.
#   writing(lista)   ¿cada una está bien escrita? Hasta WRITING_BATCH por llamada.
#
# Solo transporte y prompt: devuelve lo que contestó el modelo ya limpio (o nil si la
# llamada falló). Quien guarda los hallazgos es CannedResponses::Audit::Runner.
#
# Las citas («quote») tienen que ser frases EXACTAS del texto: se comprueban y una cita
# que no aparece se descarta, para no enseñar en pantalla algo que la predefinida no dice.
# ================================================================================

class CannedResponses::Audit::Reviewer
  MODEL = 'gpt-4o'
  # Lo que se le da de cada predefinida. Más que el tope del agente (2,000): una
  # contradicción puede estar justo en lo que el agente no ve.
  MAX_CHARS = 4000
  WRITING_BATCH = 6
  RETRIES = 3
  RELATIONS = %w[duplicate overlap distinct].freeze
  WRITING_TYPES = %w[ortografia incompleta confusa numeracion tono].freeze

  PAIR_PROMPT = <<~PROMPT
    Auditas la base de respuestas predefinidas que un agente de IA usa para contestar a
    clientes. El agente busca por parecido y recibe las 3 más cercanas a la pregunta.
    Compara dos respuestas, A y B. PRIMERO di de qué cosa concreta trata cada una (el producto, programa,
    servicio, sucursal o trámite, según su nombre y su texto) y si es la MISMA cosa.
    Contesta SOLO este JSON:
    {"subject_a":"…","subject_b":"…","same_subject":true|false,
     "repeats_info":true|false,"relation":"duplicate|overlap|distinct","reason":"una línea","suggestion":"qué hacer, una línea",
     "contradictions":[{"topic":"de qué","quote_a":"frase EXACTA de A","quote_b":"frase EXACTA de B",
                        "same_item":true|false,"can_both_be_true":true|false,"why":"una línea"}]}

    relation:
    - duplicate: una no aporta nada que la otra no diga (aunque cambie el orden, el título o la redacción).
    - Si same_subject es false, relation es SIEMPRE distinct: que dos productos, programas o
      sucursales distintos compartan información (precios, políticas, contacto) es normal.
    - overlap: REPITEN la misma información (los mismos párrafos, datos o explicación) y además cada una
      tiene algo que la otra no; conviene unirlas o separar bien los temas.
      Dos textos del mismo sujeto que cubren aspectos DISTINTOS (p. ej. costos en una y plan de estudios
      en la otra) NO se solapan: son distinct.
    repeats_info: true solo si las dos repiten información (no basta con que tengan el mismo sujeto).
    - distinct: hablan de cosas distintas, aunque tengan la misma estructura. Dos fichas de carreras, productos o
      servicios distintos son distinct, no duplicate.
    contradictions: si same_subject es false, SIEMPRE []. Solo datos INCOMPATIBLES sobre la MISMA cosa (mismo producto, carrera, servicio o trámite):
    precio, duración, requisitos, horarios, teléfonos, ligas, cantidades, condiciones. Datos distintos de cosas
    distintas NO son contradicción. Una lista en otro orden NO es contradicción. Que una tenga un paso,
    una opción o un detalle que la otra no tiene NO es contradicción (pueden ser procedimientos o
    variantes distintas). Solo es contradicción si las dos afirmaciones no pueden ser ciertas a la vez.
    Por cada una di si las dos citas hablan del MISMO dato (same_item: el mismo concepto, no p. ej.
    inscripción contra titulación) y si las dos pueden ser ciertas a la vez (can_both_be_true).
    Si no hay, [].
    Las citas se copian letra por letra del texto, sin resumir.
    Es normal que una respuesta empiece con preguntas de cliente de ejemplo (sirven para la búsqueda).
    Escribe en español.
  PROMPT

  WRITING_PROMPT = <<~PROMPT
    Revisas la redacción de respuestas predefinidas que un agente de IA usa como información para contestar a
    clientes. Marca SOLO problemas reales que confundirían al cliente o al agente:
    - ortografia: faltas de ortografía o acentos que cambian el sentido o se ven mal.
    - incompleta: frase cortada, dato sin cerrar («ver liga» sin liga, «cuesta $» sin cantidad, «llamar al» sin número).
    - confusa: algo que se puede entender de dos maneras.
    - numeracion: una lista numerada con números saltados, repetidos o un punto sin número entre numerados.
    - tono: la MISMA respuesta trata al cliente de tú (tienes, quieres, te) y también de usted (tiene, quiere, le).
      Si usa solo una de las dos formas, no es problema. Cita la frase con la forma que desentona.
    No marques estilo ni gustos, ni el formato Markdown, ni variables como {{nombre}}. Es normal que una respuesta
    empiece con preguntas de cliente de ejemplo (sirven para la búsqueda): no las marques.
    Si una respuesta está bien, issues: [].
    Contesta SOLO este JSON, con todas las respuestas que recibiste:
    {"reviews":[{"id":123,"issues":[{"type":"ortografia|incompleta|confusa|numeracion|tono",
      "quote":"frase EXACTA del texto","suggestion":"cómo debería decir"}]}]}
    Las citas se copian letra por letra. Escribe en español.
  PROMPT

  attr_reader :calls

  def initialize(account, api_key: nil)
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, api_key: api_key)
    @calls = 0
  end

  def available? = @chat.api_key.present?

  # { relation:, reason:, suggestion:, contradictions: [{ topic:, quote_a:, quote_b:, why: }] } o nil
  def pair(first, second)
    out = ask(PAIR_PROMPT, "A (id #{first.id})\n#{text(first)}\n\n---\n\nB (id #{second.id})\n#{text(second)}", 900)
    return nil unless out.is_a?(Hash) && RELATIONS.include?(out['relation'])

    # La regla «datos distintos de cosas distintas no se contradicen» estaba en el prompt y
    # el modelo la ignoraba con dos fichas de la misma plantilla (17/11/2026, cuenta 1: los
    # costos de titulación de dos maestrías, y la propia explicación decía «diferentes para
    # cada maestría»). Ahora dice primero de qué trata cada una y aquí se hace cumplir.
    distinto = out['same_subject'] == false
    # Mismo sujeto, aspectos distintos no es solaparse (17/11/2026, cuenta 1: «Costos, becas e
    # inscripción» y «Prácticas, titulación y costos» de la misma maestría, con reason «cubren
    # diferentes aspectos»).
    out['relation'] = 'distinct' if out['relation'] == 'overlap' && out['repeats_info'] == false
    # Sujetos distintos que comparten información (la misma tabla de costos de titulación en
    # Derecho, Trabajo Social y Relaciones Internacionales, cuenta 1, 17/11/2026) no se solapan
    # ni se duplican: cada uno tiene que traer lo suyo aunque coincida. Unirlas o quitarle la
    # tabla a una sería el error.
    out['relation'] = 'distinct' if distinto
    contradicciones = if distinto
                        []
                      else
                        Array(out['contradictions']).filter_map do |c|
                          next unless c.is_a?(Hash) && quoted?(first, c['quote_a']) && quoted?(second, c['quote_b'])
                          # Lo mismo, por cada contradicción: «costo de inscripción $0.00» contra «precio de
                          # titulación $35,272» salía con why «no son contradictorios».
                          next if c['same_item'] == false || c['can_both_be_true'] == true

                          { 'topic' => c['topic'].to_s, 'quote_a' => c['quote_a'].to_s, 'quote_b' => c['quote_b'].to_s, 'why' => c['why'].to_s }
                        end
                      end
    { 'relation' => out['relation'], 'reason' => out['reason'].to_s, 'suggestion' => out['suggestion'].to_s,
      'contradictions' => contradicciones, 'subjects' => [out['subject_a'].to_s, out['subject_b'].to_s],
      'same_subject' => !distinto }
  end

  # { id => [{ type:, quote:, suggestion: }] } o nil
  def writing(responses)
    cuerpo = responses.map { |r| "### id #{r.id}\n#{text(r)}" }.join("\n\n")
    out = ask(WRITING_PROMPT, cuerpo, 600 + (300 * responses.size))
    return nil unless out.is_a?(Hash)

    por_id = responses.index_by(&:id)
    Array(out['reviews']).each_with_object({}) do |review, acc|
      r = por_id[review.is_a?(Hash) ? review['id'].to_i : nil]
      next unless r

      acc[r.id] = Array(review['issues']).filter_map do |i|
        next unless i.is_a?(Hash) && WRITING_TYPES.include?(i['type']) && quoted?(r, i['quote'])

        { 'type' => i['type'], 'quote' => i['quote'].to_s, 'suggestion' => i['suggestion'].to_s }
      end
    end
  end

  private

  # Con 429 por velocidad (no por créditos) se espera y se reintenta, hasta RETRIES veces.
  def ask(system, user, max_tokens)
    mensajes = [{ role: 'system', content: system }, { role: 'user', content: user }]
    (RETRIES + 1).times do |intento|
      @calls += 1
      out = @chat.call(mensajes, max_tokens: max_tokens, temperature: 0.0, model: MODEL)
      return out if out || last_error_code != 'rate_limit' || intento == RETRIES

      sleep(2**(intento + 1))
    end
  end

  public

  # Por qué falló la última llamada: no_credits | rate_limit | other (nil si no falló).
  def last_error_code
    error = @chat.last_error.to_s
    return nil if error.empty?
    return 'no_credits' if error.match?(/insufficient_quota|credit_balance|billing/)
    return 'rate_limit' if error.start_with?('HTTP 429')

    'other'
  end

  private

  def text(response) = response.agent_text.truncate(MAX_CHARS)

  # La cita está en el texto (sin distinguir espacios repetidos ni mayúsculas).
  def quoted?(response, quote)
    cita = normalize(quote)
    cita.size >= 3 && normalize(response.agent_text).include?(cita)
  end

  def normalize(texto) = texto.to_s.downcase.gsub(/\s+/, ' ').strip
end
