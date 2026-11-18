# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — PASO 2 Y 3: LA IA PROPONE
# ================================================================================
# Para CUALQUIER cuenta: el prompt no sabe de qué negocio es. Decide por la FORMA de la
# respuesta (medidas en dev.wintook.com el 17/11/2026 sobre las 25 que pasaban el tope en
# 7 cuentas de giros distintos):
#
#   sections      ficha de un sujeto con secciones          → split por grupos de secciones
#   procedure     pasos en orden                            → split por etapas en orden, o condense
#   list          elementos parecidos (sucursales, planes…) → split por grupos de elementos
#   examples      frases de cliente de ejemplo              → split por subtema
#   instructions  órdenes para el bot («Eres…», «Debes…»)   → mark_prompt (no se divide)
#   single_topic  un solo tema                              → condense
#
# Reglas que valen para todos (las comprueba CannedResponses::Fix::Checks):
#   · cada parte nombra al SUJETO en su nombre y en su primera línea: sin eso, la sección
#     «Costos» de dos sujetos distintos se parece más entre sí que a su propio sujeto;
#   · el nombre empieza con los prefijos de grupo que usan los agentes (Fix::Groups);
#   · ningún dato duro se pierde (se le dan en la lista, Fix::HardData);
#   · cada parte mide hasta TARGET_CHARS contando «nombre: contenido».
#
# repair: segunda vuelta con los problemas que encontraron los candados.
# ================================================================================

class CannedResponses::Fix::Proposer
  MODEL = 'gpt-4o'
  TARGET_CHARS = 1900
  # Lo que se le pide a la IA: cuenta mal la longitud (medido en el banco de pruebas, una
  # parte pedida a 1,900 salió de 2,066), así que se le pide menos y se comprueba contra
  # TARGET_CHARS.
  PROMPT_CHARS = 1600
  SHAPES = %w[sections procedure list examples instructions single_topic].freeze
  ACTIONS = %w[split condense mark_prompt].freeze

  SYSTEM = <<~PROMPT
    Arreglas respuestas predefinidas demasiado largas. Un agente de IA busca la respuesta más
    parecida a la pregunta del cliente y recibe de cada una «nombre: contenido» hasta 2,000
    caracteres; lo que pasa de ahí casi no lo ve. Tu trabajo es que toda la información quepa
    sin perder NADA. Sirve para cualquier negocio: no supongas de qué trata.

    1) Identifica la FORMA (shape):
       sections      información de un mismo sujeto dividida en secciones o temas
       procedure     instrucciones paso a paso que se siguen en orden
       list          varios elementos parecidos (lugares, productos, planes, personas…)
       examples      frases o preguntas de ejemplo de clientes
       instructions  el texto le da órdenes al bot o asistente («Eres…», «Debes responder…»)
       single_topic  un solo tema que no se puede separar
    2) Identifica el SUJETO (subject): de qué o de quién trata, en pocas palabras, sacado del
       nombre y del principio del texto.
    3) Elige la ACCIÓN (action):
       split        si hay dos o más temas, etapas o grupos que alguien preguntaría por separado.
       condense     si es un solo tema (o se pasa por poco): quita SOLO lo necesario para caber
                    (repeticiones, relleno); conserva explicaciones, condiciones, advertencias y
                    ejemplos.
       mark_prompt  si shape = instructions. Si condensadas caben en una parte, una sola parte; si
                    no, divídelas por tema y cada parte sigue siendo instrucciones completas
                    para ese tema.

    Reglas de las partes (parts):
    - Cada parte mide como máximo {{target}} caracteres contando «nombre: contenido».
    - El nombre (short_code) de cada parte: {{prefix_rule}}«<sujeto> — <temas de la parte>», nombrando
      TODOS los temas que la parte contiene (p. ej. «— Costos, becas e inscripción»).
      Con condense, o mark_prompt en una sola parte: el mismo nombre de la original.
    - La primera línea del contenido de cada parte nombra al sujeto, para que se entienda sola.
    - Usa las palabras del texto; no inventes, no opines, no agregues saludos.
    - Conserva LITERALMENTE cada dato de la lista de datos obligatorios (montos, fechas,
      teléfonos, ligas, claves, cantidades, variables {{…}}). Cada uno tiene que aparecer en
      alguna parte, escrito igual.
    - Conserva el formato útil (listas, negritas, ligas en Markdown) y el idioma del original.
    - procedure + split: las partes van en orden; cada una empieza con «Parte N de M» y la que
      no es la última termina con «Continúa en: <nombre de la siguiente parte>».
    - examples + split: agrupa las frases por subtema; no cambies las frases.
    - Reparte por temas completos: no partas una sección ni un paso a la mitad.
    - Al dividir no se quita nada: cada frase del original queda en alguna parte (puedes
      quitar solo encabezados repetidos).

    Preguntas de prueba (questions): 2 por parte (máximo 10), como las escribiría un cliente que
    ya dijo de qué sujeto habla (inclúyelo en la pregunta), y que solo esa parte contesta.
    "part" es el índice (desde 0) de la parte que la contesta.

    Contesta SOLO este JSON:
    {"shape":"…","subject":"…","action":"split|condense|mark_prompt","reason":"una línea, en el idioma del original",
     "parts":[{"short_code":"…","content":"…"}],"questions":[{"text":"…","part":0}]}
  PROMPT

  attr_reader :last_error

  def initialize(account, api_key:)
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, api_key: api_key)
  end

  # name, content (ya limpio), hard_data: [{kind, text}], prefixes: [String]
  def call(name:, content:, hard_data:, prefixes:)
    ask(system(prefixes), user_message(name, content, hard_data))
  end

  # Segunda vuelta: la propuesta anterior y lo que falló.
  def repair(name:, content:, hard_data:, prefixes:, previous:, problems:)
    mensaje = "#{user_message(name, content, hard_data)}\n\n## Tu propuesta anterior\n#{previous.to_json}\n\n" \
              "## Problemas que tienes que corregir\n#{problems.map { |p| "- #{p}" }.join("\n")}\n\n" \
              'Devuelve la propuesta completa corregida, en el mismo JSON.'
    ask(system(prefixes), mensaje)
  end

  private

  def system(prefixes)
    regla = if prefixes.any?
              "empieza con #{prefixes.map { |p| "«#{p}»" }.join(' y ')} (lo usan los agentes para buscar), luego "
            else
              ''
            end
    SYSTEM.sub('{{target}}', PROMPT_CHARS.to_s).sub('{{prefix_rule}}', regla)
  end

  def user_message(name, content, hard_data)
    datos = hard_data.map { |d| "- #{d['text']}" }.join("\n").presence || '(ninguno)'
    "## Nombre de la respuesta\n#{name}\n\n## Contenido (#{content.size} caracteres)\n#{content}\n\n" \
      "## Datos obligatorios\n#{datos}"
  end

  def ask(system, user)
    out = @chat.call([{ role: 'system', content: system }, { role: 'user', content: user }],
                     max_tokens: 8000, temperature: 0.2, model: MODEL)
    @last_error = @chat.last_error
    clean(out)
  end

  def clean(out)
    return nil unless out.is_a?(Hash) && ACTIONS.include?(out['action'])

    partes = Array(out['parts']).filter_map do |p|
      next unless p.is_a?(Hash) && p['short_code'].present? && p['content'].present?

      { 'short_code' => p['short_code'].to_s.strip.first(255), 'content' => p['content'].to_s.strip }
    end
    return nil if partes.empty?

    preguntas = Array(out['questions']).filter_map do |q|
      next unless q.is_a?(Hash) && q['text'].present? && q['part'].to_i.between?(0, partes.size - 1)

      { 'text' => q['text'].to_s.strip, 'part' => q['part'].to_i }
    end
    { 'shape' => SHAPES.include?(out['shape']) ? out['shape'] : 'single_topic', 'subject' => out['subject'].to_s,
      'action' => out['action'], 'reason' => out['reason'].to_s, 'parts' => partes, 'questions' => preguntas.first(10) }
  end
end
