# frozen_string_literal: true

# Probador de agentes — el entrenador: al dar 👎 en una respuesta, decide con la traza, el
# prompt/ficha del agente y lo que esperaba el usuario dónde está el error:
#   prompt   el Entrenamiento (1.0) o las instrucciones/ficha (2.0) no lo cubren → qué cambiar
#   content  la fuente tenía el dato mal o no lo tenía → lo que dice hoy y qué debe decir
#   search   la fuente sí lo tenía pero la búsqueda no lo trajo (1.0) → qué agregarle para que llegue
#   model    estaba claro en el prompt y en la fuente y el modelo no lo siguió → probar uno mayor
#   engine   pide algo que el motor no hace o el motor no cumplió una regla → bitácora + reporte
#   question si no está seguro, una pregunta
# No cambia nada solo: el mismo usuario aplica lo de prompt y contenido (en el 2.0 con «Aplicar»;
# en el 1.0 en su Entrenamiento de siempre, que no se toca desde aquí). Todo queda en la bitácora.
class AgentTester::Trainer < Cases::Ai::BaseService
  KINDS = %w[prompt content search model engine].freeze
  MAX_PROMPT = 14_000

  SYSTEM = <<~TEXT
    Eres el entrenador de un agente de chat. El usuario lo probó, marcó una respuesta como mala y dijo qué esperaba.
    Decide DÓNDE está el error con la TRAZA (qué ruta/fuente/herramienta usó y qué trajo), el PROMPT del agente
    y sus HERRAMIENTAS. Tipos ("kind"):
    - "prompt": el prompt NO tiene escrita la indicación que el usuario espera (tono, qué decir, cuándo, qué no
      decir, un dato fijo). Da "where" (sección o campo donde va) y "text": la indicación NUEVA redactada a partir de
      lo que esperaba el usuario, corta y clara, en segunda persona (no copies texto que ya está en el prompt).
      %<prompt_extra>s
    - "content": el agente usó lo que trajo una fuente y la fuente está mal o no tenía el dato. "source" (nombre),
      "item" (código o título), "found" (lo que dice hoy, EXACTO de FRAGMENTOS; "" si no tenía), "should".
    - "search": el dato correcto SÍ está en EN_LA_BASE_PERO_NO_LLEGO y NO está en FRAGMENTOS: la búsqueda no lo trajo
      con lo que escribió el cliente. "item" (su título EXACTO), "arrived" (títulos que sí llegaron, de FRAGMENTOS) y
      "text": 1 o 2 preguntas como las escribiría un cliente para agregarlas al inicio de esa respuesta. Si el dato
      está ahí y no llegó, es "search", no "model" ni "prompt".
    - "model": la indicación YA está escrita en el prompt (o el dato correcto vino en la fuente) y la respuesta no
      lo siguió. Da "quote": la frase EXACTA del prompt o de los fragmentos que no siguió, "why" en una línea, y
      "where" + "text": la indicación que la reforzaría (redactada igual que en "prompt").
      Si la indicación no está escrita, es "prompt", no "model". Nunca des "prompt" y "model" sobre lo mismo.
    - "engine": pide HACER algo que el agente no tiene (mandar un archivo de otro sistema, consultar un sistema,
      cobrar…) o una regla que debe cumplir el motor (orden, límites, no repetir) no se cumplió. "type":
      "missing_skill" | "ignored"; "what" en una línea. Una indicación de texto NO le da herramientas que no tiene.
    Puede haber dos causas. Si no puedes saberlo, "causes": [] y una pregunta corta en "question".
    Responde en JSON: {"causes": [{"kind": "...", ...}], "question": ""}. Todo en español, cada causa con "kind".
  TEXT
  PROMPT_V2 = 'En agentes 2.0 usa además "field" ("instructions" | "never" | "welcome" | "business"), "find" ' \
              '(frase exacta a reemplazar o "" para agregar) y "replace" (= "text"); para business "label" y "value".'

  def initialize(template, user:)
    super(account: template.account)
    @template = template
    @user = user
    @v2 = Motor2.on?(template)
  end

  # input: messages: (la plática hasta la respuesta mala), reply:, feedback:, trace: (AgentTester::Trace.normalize),
  #        conversation_id:, message_id: (para la bitácora)
  def call(**input)
    @messages = input[:messages]
    @reply = input[:reply].to_s
    @feedback = input[:feedback].to_s.strip
    @trace = input[:trace].to_h
    @where = input.slice(:conversation_id, :message_id)
    data = diagnose
    return { messages: [{ kind: 'error', text: 'No pude revisar la respuesta en este momento.' }] } unless data.is_a?(Hash)

    remember(log(result_for(data)))
  end

  attr_reader :messages, :reply, :feedback, :trace

  private

  def model = Assistant::Settings.model_for(@account, :analysis)

  def diagnose
    chat(system: format(SYSTEM, prompt_extra: @v2 ? PROMPT_V2 : ''), user: context.to_json, json: true, max_tokens: 1200,
         temperature: 0.1)
  end

  def result_for(data)
    causes = checked(Array(data['causes']).map { |c| c.to_h.stringify_keys }.select { |c| kind_of(c) }).first(2)
    question = data['question'].to_s.strip
    return question_result(question) if causes.empty? && question.present?

    { messages: causes.map { |c| AgentTester::Verdict.new(@template, @user, with_facts(c.merge('kind' => kind_of(c)))).message(self) } }
  end

  # Lo que sí llegó sale de la traza, no de lo que diga el modelo (que copia el fragmento entero).
  def with_facts(cause)
    cause['kind'] == 'search' ? cause.merge('arrived' => arrived_titles) : cause
  end

  # Si el modelo no puso «kind», se deduce del primer campo que trae.
  GUESS = { 'text' => 'prompt', 'field' => 'prompt', 'source' => 'content', 'found' => 'content', 'what' => 'engine',
            'why' => 'model' }.freeze

  def kind_of(cause)
    return cause['kind'] if KINDS.include?(cause['kind'])

    GUESS.find { |key, _| cause[key].present? }&.last
  end

  # «Es del modelo» solo si cita textual lo que no siguió (del prompt o de lo que trajo la fuente). Sin
  # esa evidencia no se acepta: si no hay otra causa, se trata como falta de indicación en el prompt.
  def checked(causes)
    good = causes.reject { |c| kind_of(c) == 'model' && !quoted?(c['quote']) }
    return good if good.any? || causes.empty?

    rejected = causes.first
    [{ 'kind' => 'prompt', 'where' => rejected['where'].presence || 'las instrucciones',
       'text' => rejected['text'].presence || instruction_from_feedback, 'field' => 'instructions', 'find' => '' }]
  end

  # La indicación lista para pegar, redactada desde lo que esperaba el usuario: nunca se copia su
  # queja tal cual («Debería darme…» no le dice nada al agente).
  def instruction_from_feedback
    data = chat(system: INSTRUCTION, user: { respuesta_mala: @reply, lo_que_esperaba_el_usuario: @feedback }.to_json,
                json: true, max_tokens: 300, temperature: 0.1)
    (data.is_a?(Hash) && data['text'].to_s.strip.presence) || @feedback
  end

  INSTRUCTION = <<~TEXT
    Convierte lo que esperaba el usuario en una indicación para el prompt de un agente de chat: corta, clara, en
    segunda persona («Cuando…, haz…»), general (no solo para este mensaje). Responde en JSON: {"text": "..."}.
  TEXT

  def quoted?(quote)
    words = normalize(quote)
    words.length >= 12 && normalize([prompt_text.to_json, fragments.join(' ')].join(' ')).include?(words)
  end

  def normalize(text) = I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').squish

  def context
    { motor: @v2 ? '2.0' : '1.0', objetivo: @template.objective, prompt: prompt_text, herramientas: tools,
      platica: @messages, respuesta_mala: @reply, lo_que_esperaba_el_usuario: @feedback, traza: @trace,
      fragmentos: fragments, en_la_base_pero_no_llego: missed }
  end

  MISSED = 4

  # 1.0: lo que hay en la base sobre lo que esperaba el usuario y NO le llegó al agente (la búsqueda
  # se queda con 3). Sin esto, «el dato está pero no llegó» parecía del modelo o del prompt.
  def missed
    return [] if @v2

    vector = embed([last_customer_text, @feedback].compact_blank.join(' ').first(1000))
    return [] if vector.blank?

    found = @account.knowledge_items.search_by_embedding(vector, limit: MISSED + arrived_titles.size, threshold: 0.2)
    found.reject { |i| arrived_titles.include?(i.title) }.first(MISSED).map { |i| "#{i.title}: #{i.content.to_s.first(600)}" }
  rescue StandardError => e
    Rails.logger.warn("[AgentTester::Trainer] búsqueda de lo que no llegó: #{e.message}")
    []
  end

  def prompt_text
    return @template.complementary_prompt.to_s.first(MAX_PROMPT) unless @v2

    config = Motor2::Config.new(@template)
    { instrucciones: config.instructions, nunca: config.never, bienvenida: config.welcome, datos_del_agente: config.business,
      datos_de_la_empresa: AgentBase::BusinessData.lines(@account) }
  end

  def tools
    return 'Las del motor 1.0: rutas, búsqueda en fuentes, citas, casos y archivos según su Entrenamiento.' unless @v2

    runner = Motor2::Runner.new(Motor2::Config.new(@template), state: Motor2::State.new, history: [])
    Motor2::Skills.for(runner).flat_map(&:tools).map { |t| t.dig(:function, :name) }
  end

  # El 1.0 guarda en la traza solo los títulos: el texto se busca para poder enseñarlo.
  def fragments
    return Array(@trace['sources']).flat_map { |s| Array(s['found']) }.first(4) if @v2

    titles = Array(@trace['fragmentos']).pluck('titulo').compact_blank
    @account.knowledge_items.where(title: titles).limit(4).map { |i| "#{i.title}: #{i.content.to_s.first(600)}" }
  end

  def arrived_titles = @arrived_titles ||= Array(@trace['fragmentos']).pluck('titulo').compact_blank

  def last_customer_text = Array(@messages).reverse.find { |m| m['role'] == 'user' }&.dig('content')

  def question_result(question) = { messages: [{ kind: 'question', text: question }] }

  # Cada 👎 revisado queda como prueba en el lote del agente y del día («Pruebas · <agente> · 17 nov»).
  def remember(result)
    test_case = AgentTester::AutoCase.save(@template, messages: @messages, feedback: @feedback, bad_reply: @reply,
                                                      kinds: result[:messages].pluck(:kind))
    return result unless test_case

    AgentTestLog.where(id: result[:messages].pluck(:log_id).compact).update_all(agent_test_case_id: test_case.id) # rubocop:disable Rails/SkipsModelValidations
    result.merge(saved_in: test_case.batch.name)
  end

  def log(result)
    result[:messages].each do |msg|
      next if msg[:kind] == 'error'

      entry = AgentTestLog.create!(account: @account, tracking_template: @template, user: @user, engine: @v2 ? '2' : '1',
                                   kind: msg[:kind], feedback: @feedback, reply: @reply, diagnosis: msg,
                                   motor2_report_id: msg[:report_id], **@where)
      msg[:log_id] = entry.id
    end
    result
  end
end
