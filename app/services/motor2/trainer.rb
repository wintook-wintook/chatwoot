# frozen_string_literal: true

# Motor 2.0 — el entrenador: al dar 👎 el usuario dice qué estuvo mal y el entrenador decide, con
# la traza del turno (qué fuente consultó y qué le regresó, qué herramienta usó) y la ficha, dónde
# está el error (plan §11.11):
#   agent   las instrucciones o la ficha del agente → lo corrige solo (versión, deshacer, antes corre
#           las pruebas que pasaban; si rompe alguna, no lo aplica)
#   source  la fuente tenía el dato mal o no lo tenía → enseña lo que dice y ofrece arreglarlo
#   engine  falta una habilidad o el motor no obedeció → «búscalo con tu Kontrolya» y reporte
#   question  si no está seguro, una sola pregunta
# Puede haber dos causas. Cada 👎 resuelto queda como prueba.
class Motor2::Trainer < Cases::Ai::BaseService
  FIELDS = %w[instructions never welcome business].freeze

  SYSTEM = <<~TEXT
    Eres el entrenador de un agente de chat de una empresa. El usuario probó al agente, marcó una
    respuesta como mala y dijo qué esperaba. Decide DÓNDE está el error usando la TRAZA (qué buscó
    el agente y qué le regresó cada fuente), la FICHA (sus instrucciones y datos) y sus HERRAMIENTAS.

    Tipos de causa:
    - "agent": lo que el usuario espera no está cubierto en la ficha (tono, qué decir, cuándo, qué no
      decir, un dato fijo del negocio). Se arregla escribiendo una indicación. Da el cambio:
      field: "instructions" | "never" | "welcome" | "business";
      para texto: "find" (solo si una frase EXACTA de ese campo contradice lo que se espera; para agregar una
      indicación nueva deja "find" vacío) y
      "replace" (texto nuevo, corto y claro, en segunda persona: «Cuando…, …»);
      para business: "label" y "value". "summary": qué cambiaste, en una línea.
    - "agent" con field "skill": lo esperado lo hace una HABILIDAD que existe pero está apagada o sin datos
      (ver HABILIDADES). Da "skill" (su clave) y en "summary" qué prender o llenar. No escribas indicaciones para eso.
    - "source": el agente contestó con lo que le dio una fuente y la fuente está mal o le falta el
      dato. "source": nombre de la fuente; "item": código o título; "found": lo que dice HOY, copiado
      EXACTO de la traza (vacío si no tenía nada); "should": lo que debería decir; "missing": true si
      no lo tenía.
    - "engine": (a) pide HACER algo (mandar un archivo de otro sistema, consultar un sistema, cobrar…) que no está en
      sus HERRAMIENTAS ni en las HABILIDADES ("type": "missing_skill"): una indicación de texto NO le da al agente una
      herramienta que no tiene; o (b) la
      indicación ya estaba escrita en la ficha o la fuente sí traía el dato correcto y el agente no lo
      siguió ("type": "ignored"). "what": qué no pudo hacer, en una línea.
    Si no puedes saberlo, deja "causes" vacío y haz UNA pregunta corta en "question".
    Responde en JSON. Cada causa lleva SIEMPRE "kind". Ejemplo:
    {"causes": [{"kind": "agent", "field": "instructions", "find": "", "replace": "Cuando…, …", "summary": "…"}], "question": ""}
    Todo en español.
  TEXT

  def initialize(template, user:)
    super(account: template.account)
    @template = template
    @user = user
  end

  # messages: la plática hasta la respuesta mala (incluida); trace: la traza de esa respuesta.
  def call(messages:, reply:, feedback:, trace: {})
    @messages = messages
    @reply = reply
    @feedback = feedback.to_s.strip
    @trace = trace.to_h
    data = diagnose
    return { messages: [{ kind: 'error', text: 'No pude revisar la respuesta en este momento.' }] } unless data.is_a?(Hash)

    question = data['question'].to_s.strip
    causes = Array(data['causes']).map { |c| c.to_h.stringify_keys }
    return { messages: [{ kind: 'question', text: question }] } if causes.empty? && question.present?

    respond(causes)
  end

  private

  # Clasificar el error es análisis: el modelo de análisis de la cuenta (si eligió uno).
  def model = Assistant::Settings.model_for(@account, :analysis)

  def diagnose
    chat(system: SYSTEM, user: context.to_json, json: true, max_tokens: 1200, temperature: 0.1)
  end

  def context
    config = Motor2::Config.new(@template)
    runner = Motor2::Runner.new(config, state: Motor2::State.new, history: [])
    tools = Motor2::Skills.for(runner).flat_map(&:tools).map { |t| "#{t.dig(:function, :name)}: #{t.dig(:function, :description)}" }
    { ficha: { objetivo: config.objective, instrucciones: config.instructions, nunca: config.never, bienvenida: config.welcome,
               datos_del_negocio: config.business },
      herramientas: tools, habilidades: skills_status(config), platica: @messages, respuesta_mala: @reply, lo_que_esperaba_el_usuario: @feedback,
      traza: @trace.slice('tools', 'sources', 'events') }
  end

  def skills_status(config)
    Motor2::Skills::CATALOG.to_h do |key, what|
      [key, { hace: what, prendida: key == 'files' ? @template.ai_agent_attachments.exists? : config.skill_on?(key) }]
    end
  end

  def respond(causes)
    out = causes.first(2).filter_map { |cause| handle(cause) }
    test = save_test
    { messages: out.pluck(:message), agent: out.filter_map { |o| o[:agent] }.last, test_id: test&.id }
  end

  def handle(cause)
    case kind_of(cause)
    when 'agent' then Motor2::Trainer::AgentFix.new(@template, @user, cause).call
    when 'source' then { message: source_message(cause) }
    when 'engine' then { message: engine_message(cause) }
    end
  end

  # Si el modelo no puso «kind», se deduce de lo que sí puso.
  def kind_of(cause)
    return cause['kind'] if %w[agent source engine].include?(cause['kind'])
    return 'agent' if cause['field'].present?
    return 'source' if cause['source'].present? || cause.key?('found')

    'engine' if cause['what'].present?
  end

  def source_message(cause)
    canned = cause['source'].to_s.casecmp?('Respuestas predefinidas') &&
             @account.canned_responses.find_by(short_code: cause['item'].to_s.split(':').first.to_s.strip)
    { kind: 'source', source: cause['source'], item: cause['item'], found: cause['found'], should: cause['should'],
      missing: cause['missing'] == true, can_fix: canned.present?, canned_id: canned&.id, text: source_text(cause) }
  end

  def source_text(cause)
    return "Tu fuente «#{cause['source']}» no tiene ese dato." if cause['missing']

    "El agente contestó con lo que dice tu fuente «#{cause['source']}»; lo que está mal es la fuente."
  end

  def engine_message(cause)
    report = Motor2::Reporter.new(@template, @user).call(kind: cause['type'] == 'ignored' ? 'ignored' : 'missing_skill',
                                                         turns: @messages, reply: @reply, expected: @feedback,
                                                         diagnosis: cause['what'], trace: @trace)
    { kind: 'engine', report_id: report.id,
      text: "Esto no lo puede hacer el motor todavía (#{cause['what']}). No es algo que tú puedas corregir: búscalo con tu " \
            'Kontrolya. Ya les mandé el reporte con esta plática, así que no tienes que explicarlo de nuevo.' }
  end

  def save_test
    Motor2Test.create!(account: @account, tracking_template: @template, origin: 'correction',
                       name: @feedback.first(80).presence || 'Corrección', turns: @messages, expected: @feedback)
  rescue ActiveRecord::RecordInvalid
    nil
  end
end
