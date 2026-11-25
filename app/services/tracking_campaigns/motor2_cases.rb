# frozen_string_literal: true

# Campaña con IA — «Casos»: las pruebas que se arman solas con lo que tiene la campaña (como la lista de
# «validación antes de publicar» de un entrenamiento): «sí me interesa», una duda concreta, la palabra clave,
# «no puedo esta vez», «no me manden nada», algo que no es de la campaña, un «gracias», la liga que no le llegó…
# Cada caso corre la plática en el chat de prueba (Motor2::Probe: no manda ni guarda nada) y revisa lo que hizo la
# IA con sus herramientas (y, si aplica, que la respuesta traiga la liga exacta).
#
#   cases = TrackingCampaigns::Motor2Cases.new(agent, answers, opener: '…')
#   cases.list       → [{ key:, title:, message: }]
#   cases.run('keyword') → { key:, ok:, reply:, tools: [], reason: }
class TrackingCampaigns::Motor2Cases
  CAMPAIGN_TOOLS = %w[enviar_informacion reenviar_informacion mandar_liga le_interesa ya_lo_hizo confirmar_asistencia no_esta_vez futuras
                      no_contactar no_le_interesa mas_adelante guardar_respuesta].freeze

  def initialize(agent, answers, opener: nil)
    @agent = agent
    @answers = answers
    @opener = opener.to_s.strip.presence || 'Hola 👋 Te escribimos de parte de la empresa. ¿Te gustaría conocer más?'
  end

  def list = cases.map { |c| c.slice(:key, :title, :message) }

  def run(key)
    item = cases.find { |c| c[:key] == key.to_s }
    return { key: key, ok: false, reason: 'Ese caso ya no aplica a la campaña.' } unless item

    result = Motor2::Probe.new(@agent, messages: item[:messages], state: item[:state] || {}, answers: @answers).call
    return { key: key, ok: false, reason: result[:error].to_s } if result[:error]

    tools = Array(result.dig(:trace, 'tools')).select { |t| t['ok'] }.pluck('name')
    ok, reason = verdict(item, tools, result[:reply].to_s)
    { key: key, ok: ok, reply: result[:reply].to_s, tools: tools, reason: reason }
  end

  private

  def function = @function ||= Motor2::Config.new(@agent, answers: @answers).function

  def content? = function.content.present?

  def package = function.content.to_s

  # Lo que se le dijo antes (la apertura y, si ya se mandó, la información completa).
  def talk(*turns, after_package: false)
    base = [{ role: 'assistant', content: @opener }]
    base += [{ role: 'user', content: 'Sí, cuéntame' }, { role: 'assistant', content: package }] if after_package && content?
    base + turns.each_slice(2).flat_map { |user, bot| [{ role: 'user', content: user }, bot && { role: 'assistant', content: bot }].compact }
  end

  def state_after_package = content? ? { 'content_sent' => true } : {}

  def cases
    @cases ||= (function.survey? ? survey_cases : sale_cases).compact
  end

  def sale_cases
    [interest_case, question_case, keyword_case, not_done_case, confirm_case, not_now_case, future_case, opt_out_case,
     off_topic_case, thanks_case, *link_cases, later_case]
  end

  # opts: expect: { any: [herramientas], none: [herramientas], url: }, messages:, state:, after_package:
  def make(key, title, message, **opts)
    after = opts[:after_package]
    { key: key, title: title, message: message, expect: opts[:expect] || {},
      state: opts[:state] || (after ? state_after_package : {}), messages: opts[:messages] || talk(message, after_package: after) }
  end

  def interest_case
    expect = if content? then { any: %w[enviar_informacion] }
             elsif %w[relay appointment].include?(function.goal) then { any: %w[le_interesa] }
             else
               { none: %w[ya_lo_hizo confirmar_asistencia no_contactar] }
             end
    make('interest', 'Contesta «sí, me interesa»', 'Sí, me interesa', expect: expect)
  end

  def question_case
    question = Array(function.answer(:campaign_objections)).first&.dig('objection').presence || fact_question
    make('question', 'Hace una pregunta concreta', question,
         expect: { none: %w[enviar_informacion mandar_liga ya_lo_hizo confirmar_asistencia no_contactar no_esta_vez] })
  end

  def fact_question
    { 'invite' => '¿A qué hora es y cuánto cuesta?', 'renew' => '¿Cuándo me vence?', 'reactivate' => '¿Qué hay de nuevo?' }[function.purpose] ||
      '¿Cuánto cuesta?'
  end

  def keyword_case
    return nil unless function.goal == 'external'

    make('keyword', "Escribe «#{function.keyword}»", function.keyword, expect: { any: %w[ya_lo_hizo] }, after_package: true)
  end

  def not_done_case
    return nil unless %w[external done].include?(function.goal)

    make('not_done', '«Me interesa, ahorita lo hago» todavía no cuenta', 'Me interesa, ahorita lo hago',
         expect: { none: %w[ya_lo_hizo] }, after_package: true)
  end

  def confirm_case
    return nil unless function.goal == 'confirm'

    make('confirm', 'Confirma que va', 'Sí voy, ahí estaré', expect: { any: %w[confirmar_asistencia] }, after_package: true)
  end

  def not_now_case
    return nil unless function.asks_future?

    make('not_now', '«No puedo esta vez» (no es una baja)', 'No puedo esta vez, tengo otro compromiso',
         expect: { any: %w[no_esta_vez confirmar_asistencia], none: %w[no_contactar] })
  end

  def future_case
    return nil unless function.asks_future?

    messages = talk('No puedo esta vez', function.reply_text('not_now'), 'Sí, invítenme la próxima')
    make('future_yes', 'Acepta que le escriban la próxima', 'Sí, invítenme la próxima',
         expect: { any: %w[futuras] }, messages: messages, state: { 'asked_future' => true })
  end

  def opt_out_case
    make('opt_out', '«No me manden nada» (baja inmediata)', 'No me manden nada, por favor', expect: { any: %w[no_contactar] })
  end

  def off_topic_case
    make('off_topic', 'Pregunta algo que no es de la campaña', '¿Y qué otros servicios tienen?',
         expect: { none: %w[enviar_informacion ya_lo_hizo confirmar_asistencia no_contactar no_esta_vez] })
  end

  def thanks_case
    make('thanks', 'Solo dice «gracias»', 'Gracias 👍', expect: { none: CAMPAIGN_TOOLS }, after_package: true)
  end

  def link_cases
    links = Array(function.links)
    problem = links.find { |l| l['use'] == 'problem' }
    main = links.find { |l| l['use'] == 'package' }
    [problem && make('problem_link', "No le llegó el correo → «#{problem['name']}»", 'Ya me registré pero no me llegó el correo',
                     expect: { url: problem['url'] }, after_package: true),
     main && make('resend_link', "Pide la liga otra vez → solo «#{main['name']}»", '¿Me pasas otra vez la liga?',
                  expect: { url: main['url'], none: %w[reenviar_informacion] }, after_package: true)].compact
  end

  def later_case
    return nil unless function.purpose == 'renew'

    make('later', 'Pide tiempo («dame hasta el viernes»)', '¿Me das hasta el viernes?', expect: { any: %w[mas_adelante] })
  end

  def survey_cases
    first = function.survey_questions.first.to_s
    [make('survey_yes', '«Sí» todavía no es una respuesta', 'Sí, claro', expect: { none: %w[guardar_respuesta] }),
     make('survey_answer', 'Contesta la primera pregunta', '9', expect: { any: %w[guardar_respuesta] },
                                                                messages: talk('Sí, claro', first, '9')),
     opt_out_case]
  end

  # [ok, motivo]
  def verdict(item, tools, reply)
    expect = item[:expect]
    if expect[:any] && !expect[:any].intersect?(tools)
      return [false, "Se esperaba que usara #{expect[:any].join(' o ')}#{tools.any? ? "; usó #{tools.join(', ')}" : '; no usó ninguna'}."]
    end

    wrong = Array(expect[:none]) & tools
    return [false, "No debía usar #{wrong.join(', ')}."] if wrong.any?
    return [false, 'La respuesta no trae la liga exacta.'] if expect[:url] && reply.exclude?(expect[:url])

    [true, 'Bien.']
  end
end
