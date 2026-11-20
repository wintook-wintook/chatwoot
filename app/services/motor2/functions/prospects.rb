# frozen_string_literal: true

# Función «Atención a prospectos» — convierte lo que la empresa contestó en el asistente
# (motor2['answers']) en el prompt y las habilidades del motor 2.0. Viene de ReadyAgents::Prompt y
# ReadyAgents::Qualification (los agentes listos de antes), con las mismas respuestas:
#
#   objective          handoff | opportunity | collect | appointment   (qué hace al calificarlo)
#   tone               cercano | formal | directo
#   question_list      ['¿Qué auto buscas?', …]   las preguntas para calificarlo, en orden y tal cual se
#                      hacen (una sola lista: vienen unas de ejemplo que se quitan o cambian)
#   qualify / questions  (agentes de antes) preguntas armadas prendidas + preguntas propias en texto
#                      libre; se usan solo si no hay question_list
#   qualified_when / discard_when
#   objections         [{ objection, answer }]
#   required_contact   ['name', 'email', 'company', 'city']   datos a juntar antes de calificarlo
#   handoff_user_id / handoff_team_id     a quién se pasa
#   only_prospects + client_user_id / client_team_id   quien ya es cliente va con su responsable
#   case_type_id                          tipo de caso de la oportunidad
#   appointment_user_ids / appointment_minutes / appointment_kind / appointment_location
#   business_what / _who / _coverage / _why / _practical
#   price_source                          dónde están sus productos y precios (Motor2::Functions::ProspectPrices;
#                                         antes business_use_catalog)
#   doubts / not_found / off_topic        «Cómo platica» (Motor2::Functions::ProspectRules)
#   follow_up { nudges 0-2, templates [], template_days }   si deja de contestar (Motor2::FollowUp)
#   appointment_notice { on, template }   recordatorio de la cita y «¿otro horario?» si no llegó (Motor2::AppointmentNotice)
#   attend_hours                          en cuántas horas (hábiles) debe escribirle el vendedor; si no, aviso y escala
#
# Las indicaciones en texto libre van en motor2['instructions'] (las mismas que corrige el
# entrenador), no en answers.
class Motor2::Functions::Prospects
  include Motor2::Functions::ProspectPrices
  include Motor2::Functions::ProspectExtras
  KEY = 'prospects'
  OBJECTIVES = {
    'handoff' => 'pasárselo a una persona del equipo para que lo atienda',
    'opportunity' => 'crearle la oportunidad de venta y pasársela al equipo',
    'collect' => 'juntar sus datos y sus respuestas para que el equipo le dé seguimiento',
    'appointment' => 'agendarle una cita'
  }.freeze
  TONES = { 'cercano' => ['tu', 'cercano y amable'], 'formal' => ['usted', 'formal y respetuoso'],
            'directo' => ['tu', 'directo y práctico'],
            'empresa' => ['tu', 'el de ASÍ HABLA LA EMPRESA (si dice «de usted», de usted)'] }.freeze
  BUSINESS = { 'business_what' => 'Qué vende', 'business_who' => 'A quién le vende (cliente ideal)',
               'business_coverage' => 'Dónde da servicio', 'business_why' => 'Por qué elegirnos',
               'business_practical' => 'Precios desde, formas de pago y tiempos' }.freeze
  QUESTIONS = {
    'need' => { label: 'Qué necesita y para qué', ask: '¿Qué necesitas y para qué lo quieres?', on: true },
    'when' => { label: 'Para cuándo', ask: '¿Para cuándo lo necesitas?' },
    'budget' => { label: 'Presupuesto', ask: '¿Tienes un presupuesto aproximado?' },
    'decides' => { label: 'Quién decide', ask: '¿Tú decides la compra o alguien más?' },
    'location' => { label: 'Ubicación', ask: '¿En qué ciudad o zona estás?' },
    'quantity' => { label: 'Cantidad o tamaño', ask: '¿Qué cantidad o tamaño necesitas?' },
    'source' => { label: 'Cómo nos conoció', ask: '¿Cómo nos conociste?' }
  }.freeze
  CONTACT_FIELDS = { 'name' => 'nombre', 'email' => 'correo', 'company' => 'empresa', 'city' => 'ciudad' }.freeze
  CHECKS = {
    'name' => ->(c) { c.name.present? && !c.name.to_s.match?(/\A[+\d\s()-]+\z/) }, # el teléfono no es nombre
    'email' => ->(c) { c.email.present? },
    'company' => ->(c) { c.additional_attributes.to_h['company_name'].present? || c.try(:organization).present? },
    'city' => ->(c) { c.additional_attributes.to_h['city'].present? }
  }.freeze
  TEMPERATURES = %w[caliente tibio frio].freeze
  APPOINTMENT_KINDS = %w[llamada videollamada visita oficina].freeze
  MAX_OBJECTIONS = 15
  MAX_QUESTIONS = 10
  TEXTS = %w[objective tone questions qualified_when discard_when hot_when appointment_kind appointment_location price_source
             business_what business_who business_coverage business_why business_practical].freeze
  IDS = %w[handoff_user_id handoff_team_id client_user_id client_team_id case_type_id appointment_minutes].freeze
  BOOLEANS = %w[only_prospects business_use_catalog].freeze

  # Lo que manda el asistente, limpio (Motor2::Functions::ProspectAnswers).
  def self.sanitize(raw) = Motor2::Functions::ProspectAnswers.call(raw)

  attr_reader :config

  delegate :answers, to: :config

  def initialize(config)
    @config = config
  end

  def key = KEY

  def answer(name) = answers[name.to_s]

  def objective = OBJECTIVES.key?(answer(:objective)) ? answer(:objective) : 'handoff'

  def appointment? = objective == 'appointment'

  def tone = (TONES[answer(:tone)] || TONES['cercano']).first

  def only_prospects? = answer(:only_prospects) != false

  # Cuándo pasarlo a una persona (lo de «pide una persona» lo dice CÓMO PLATICAS).
  def handoff_when = 'pide hablar con una persona (como dice CÓMO PLATICAS), se molesta o ya es cliente'

  def human_now? = Motor2::Functions::ProspectRules.human_now?(answers)

  # «Cómo platica»: si no contesta dudas, no busca en ninguna fuente.
  def answers_doubts? = Motor2::Functions::ProspectRules.answers_doubts?(answers)

  def handoff_target = { user_id: answer(:handoff_user_id), team_id: answer(:handoff_team_id) }

  def client_target = { user_id: answer(:client_user_id), team_id: answer(:client_team_id) }

  # Lo que pasa cuando el agente decide (calificado, descartado, pasado, cita, ya es cliente).
  def outcomes(tracking, conversation) = Motor2::Functions::ProspectOutcomes.new(tracking, conversation, self)

  # Las habilidades que lleva (se juntan con lo que tenga motor2['skills'], que gana).
  def skills
    {
      'qualify' => { 'on' => true },
      'recommend' => { 'on' => answers_doubts? && price_source == 'catalog' },
      'quote' => { 'on' => quote_mode != 'off' },
      'knowledge' => { 'on' => answers_doubts? },
      'handoff' => { 'on' => true, 'when' => handoff_when }.merge(handoff_target.transform_keys(&:to_s)),
      'appointments' => { 'on' => appointment?, 'kind' => answer(:appointment_kind).presence_in(APPOINTMENT_KINDS) || 'llamada',
                          'location' => answer(:appointment_location).to_s, 'when' => 'ya califica',
                          'user_ids' => Array(answer(:appointment_user_ids)), 'minutes' => answer(:appointment_minutes) }
    }
  end

  # El puesto y lo que contestó la empresa, en el orden del agente listo de antes.
  def prompt(conversation = nil)
    blocks = [Motor2::Functions.puesto(KEY), business_block, ad_block(conversation), company_block, questions_block,
              objections_block, contact_block, appointment_block, Motor2::Functions::ProspectRules.block(answers)]
    blocks.map { |b| b.to_s.strip }.compact_blank.join("\n\n")
  end

  # [{ number:, ask:, condition: }] en orden: las de la lista del asistente, tal cual; en los agentes de antes,
  # las armadas prendidas (sin `qualify` guardado, la de «qué necesita») y sus preguntas propias.
  # «¿Cuántos empleados tienen? [solo si es empresa]» → condition 'es empresa' (Motor2::AnswerExtractor).
  def questions
    list = Array(answer(:question_list)).compact_blank
    list = legacy_questions if list.empty?
    list.each_with_index.map do |text, i|
      condition = text[CONDITION, 1]
      { number: i + 1, ask: text.sub(CONDITION, '').strip, condition: condition&.strip }.compact
    end
  end

  CONDITION = /\s*[\[(]\s*solo\s+si\s+([^\])]+)[\])]\s*\z/i

  def legacy_questions
    saved = Array(answer(:qualify)).index_by { |q| q['key'].to_s }
    QUESTIONS.filter_map do |k, base|
      row = saved[k]
      on = row ? ActiveModel::Type::Boolean.new.cast(row['on']) : base[:on]
      row&.dig('text').presence || base[:ask] if on
    end + [answer(:questions).to_s.strip.presence].compact
  end

  def objections
    Array(answer(:objections)).filter_map do |row|
      { objection: row['objection'].to_s.strip, answer: row['answer'].to_s.strip } if row['objection'].present? && row['answer'].present?
    end.first(MAX_OBJECTIONS)
  end

  # Lo que el agente ya trae en «Tu negocio»: no se repite del bloque de datos de la empresa.
  def business_values = BUSINESS.keys.map { |k| answer(k).to_s }

  def required_contact = Array(answer(:required_contact)).map(&:to_s) & CONTACT_FIELDS.keys

  # Los datos obligatorios que faltan, en palabras («correo», «empresa»). `noted` = lo que el
  # prospecto dio en este turno (actualizar_contacto), que en el chat de prueba no se guarda.
  def missing_contact(contact, noted = {})
    required_contact.reject { |f| noted[CONTACT_FIELDS[f]].present? || (contact.present? && CHECKS[f].call(contact)) }
                    .map { |f| CONTACT_FIELDS[f] }
  end

  private

  # Lo que la empresa contó de su negocio: para explicar y para descartar a quien está fuera.
  def business_block
    lines = BUSINESS.filter_map { |k, label| "- #{label}: #{answer(k)}" if answer(k).present? }
    lines << price_line
    return '' if lines.empty?

    "EL NEGOCIO (úsalo para explicar; si el prospecto está fuera de la zona o de lo que vendemos, es para descartar):\n" \
      "#{lines.join("\n")}"
  end

  def company_block
    style = (TONES[answer(:tone)] || TONES['cercano']).last
    <<~TEXT
      LO QUE PIDIÓ LA EMPRESA (si contradice lo anterior, gana esto):
      - Tono: #{style}.
      - Objetivo cuando califica: #{OBJECTIVES[objective]}.
      - Está calificado cuando: #{answer(:qualified_when).presence || 'dijo qué busca y quiere avanzar'}
      - Se descarta cuando: #{answer(:discard_when).presence || 'no le interesa o no es lo que vendemos'}
    TEXT
  end

  def questions_block
    lines = questions.map { |q| "#{q[:number]}. «#{q[:ask]}»" }
    lines << '1. «¿Qué buscas y para cuándo?»' if lines.empty?
    <<~TEXT
      PREGUNTAS PARA CALIFICARLO: hazlas TAL CUAL están escritas, en este orden y una por mensaje, al final de tu
      mensaje. No inventes otras preguntas para calificar. Si ya lo dijo en la plática, no la hagas: guarda su respuesta. Cada respuesta
      guárdala con guardar_respuesta y el número de la pregunta en ese mismo turno:
      #{lines.join("\n")}

      TEMPERATURA: al calificarlo (o pasarlo a una persona) di qué tan listo está:
      - caliente: #{answer(:hot_when).presence || 'lo necesita pronto (este mes) y tiene presupuesto o decide la compra'}.
      - tibio: le interesa, pero es para más adelante o falta saber el presupuesto o quién decide.
      - frio: solo está explorando o comparando, sin fecha.
    TEXT
  end

  def objections_block
    return '' if objections.empty?

    "OBJECIONES FRECUENTES (contesta con esta idea, con tus palabras; no ofrezcas descuentos que no estén aquí):\n" \
      "#{objections.map { |o| "- «#{o[:objection]}» → #{o[:answer]}" }.join("\n")}"
  end

  def contact_block
    fields = required_contact.map { |f| CONTACT_FIELDS[f] }
    return '' if fields.empty?

    "DATOS OBLIGATORIOS: cuando ya califique, si falta su #{fields.to_sentence(last_word_connector: ' y ', two_words_connector: ' y ')}, " \
      'pídelo con naturalidad ANTES de prospecto_calificado y antes de despedirte; cuando lo dé, guárdalo con ' \
      'actualizar_contacto y entonces califícalo.'
  end

  def appointment_block
    return '' unless appointment?

    'CITA: cuando califique, ofrécele 2 o 3 horarios de ver_horarios. Cuando elija uno, agendar_cita y confirma el día, la ' \
      'hora y con quién. No hace falta llamar prospecto_calificado: agendar la cita ya lo califica.'
  end
end
