# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ENTREVISTA, REDACCIÓN Y EDICIÓN
# ================================================================================
# UNA sola conversación con el modelo: entrevista y, cuando tiene lo que necesita,
# escribe el Entrenamiento. Si lo que escribió no pasa el comprobador, vuelve al
# MISMO hilo con el diagnóstico y lo corrige.
#
# POR QUÉ UNA CONVERSACIÓN Y NO AGENTES ENCADENADOS:
#   Un entrevistador que le pasa el objetivo a un generador, y ese a un auditor, es
#   más caro y peor: cada salto re-serializa el contexto y pierde el matiz de la
#   entrevista ("no sabía bien qué quería, terminamos en soporte + cobranza"). Y el
#   auditor-LLM es la pieza a ELIMINAR, no a encadenar: un modelo auditando sintaxis
#   opina; el parser verifica. Acá el auditor es ValidatorService, que no gasta
#   tokens y no puede alucinar.
#
# LOS BUCLES, en este orden:
#   1. edición   ¿tocó sin declarar algo destructivo del Entrenamiento que había?
#   2. gramática ¿se ejecuta? (ValidatorService) — hasta MAX_REPAIRS vueltas
#   3. ruteo     ¿cada rama se elige a sí misma? (RouteSelfCheck) — una vuelta
#   Cada uno le devuelve al mismo hilo un diagnóstico CONCRETO. Medido el 08/09/2026:
#   con un veredicto pelado se reparaba 1 de 3 veces; nombrando lo que falta, 3 de 3.
#
# EDITAR, NO REESCRIBIR (fase A de PROMPT STUDIO):
#   Hasta el 15/09/2026 el modelo NUNCA veía el Entrenamiento: el cliente mandaba solo
#   la conversación. "Agrega una rama" se resolvía reescribiendo todo de memoria, y un
#   agente cargado con "Arreglarlo acá" se reemplazaba por uno nuevo sin haberlo leído.
#   Ahora recibe el que está en pantalla —con las ediciones a mano incluidas— y lo
#   devuelve completo cambiando solo lo pedido. Medido sobre el v6.11 (17.066
#   caracteres, 30 piezas): una regla nueva en [ESTILO] volvió con 1 línea distinta.
#
#   Y si lo nuevo no ejecuta y lo que había sí, se conserva lo que había: una
#   modificación fallida nunca le cuesta a nadie el Entrenamiento que funcionaba.
#
# CONTRATO DE SALIDA:
#   Se pide JSON para que el bucle sea determinista: hace falta saber si el modelo
#   preguntó o entregó, y con texto libre eso habría que adivinarlo.
#     { "mensaje": "lo que se le muestra a la persona",
#       "entrenamiento": "el Entrenamiento completo, o null si todavía pregunta",
#       "toca": [...], "cambios": [...]   ← solo al editar }
# ================================================================================

class ContactTrackings::Assistant::InterviewService
  RepairPrompts = ContactTrackings::Assistant::RepairPrompts
  API_URL = ContactTrackings::Assistant::OpenaiChat::API_URL
  # Vueltas de corrección antes de mostrarle los errores a la persona.
  MAX_REPAIRS = 3
  # Vueltas para arreglar el RUTEO (ver RouteSelfCheck). Solo una: cada vuelta
  # cuesta una clasificación por rama, y si con el cruce señalado de frente no lo
  # arregla, una segunda vuelta tampoco — mejor entregarlo con el aviso a la vista.
  MAX_ROUTE_REPAIRS = 1
  # Tiempo total de un turno, con todas sus vueltas. Editando el v6.11 cada llamada
  # tarda 40–52 s (medido), y el proxy de develop corta a los 300: con tres
  # correcciones y la del ruteo, un turno se pasaría y la persona vería un error
  # aunque el Entrenamiento hubiera salido bien. Pasado este tope no se abre otra
  # vuelta: se entrega lo que hay, con sus hallazgos a la vista.
  TURN_BUDGET_SECONDS = 200
  # Los dos comportamientos posibles del agente. "responde" consulta una fuente y
  # escala si no resuelve; "deriva" abre el caso siempre, sin intentar contestar.
  # Cuál de los dos es NO se puede deducir del pedido —"un agente que junte
  # información para abrir un ticket" se lee de las dos maneras— así que el modelo
  # tiene que haberlo preguntado, y decirlo. Medido: si no se le exige, elige solo.
  MODES = %w[responde deriva].freeze
  # Tope de turnos de entrevista. Más que esto no es una entrevista, es un chat: a
  # partir de acá el contrato le exige redactar con lo que tenga y marcar lo que
  # falte como <PENDIENTE:>.
  #
  # Estaba en 5 y la entrevista pasó a tener CUATRO pasos (ramas+modo, las frases del
  # cliente por rama, fuente y escalamiento, etiquetas): con 5 no quedaba ni un turno
  # de margen para una respuesta a medias, y el paso que se caía era el de las frases
  # —el único que no se puede deducir del inventario—.
  MAX_INTERVIEW_TURNS = 6

  Result = ContactTrackings::Assistant::InterviewResult

  # Lo que va y viene entre vueltas de corrección.
  Turn = Struct.new(:history, :message, :draft, :declared, :summary, :conflict, keyword_init: true)

  # one_shot: sin entrevista. Es el modo del botón "generar" que vive dentro de la
  # ficha del Agente IA: ahí no hay una conversación donde preguntar, hay un campo y
  # alguien esperando que se llene. Se redacta con lo que haya y lo que falte se marca
  # <PENDIENTE:>, en vez de devolver una pregunta que nadie va a poder contestar.
  #
  # drafts:
  #   current    el Entrenamiento que la persona tiene en pantalla, tal cual —con sus
  #              ediciones a mano—. Con él, el turno es una EDICIÓN.
  #   delivered  lo que entregó el asistente la última vez (ver ManualEdits). La
  #              diferencia con `current` es lo que la persona editó a mano.
  #   building   la entrevista sigue abierta: lo que devolvió el turno anterior en
  #              `building` (ver TurnOutcome#building?).
  def initialize(account, messages:, inbox: nil, one_shot: false, drafts: {})
    @account = account
    @inbox = inbox
    @messages = Array(messages)
    @one_shot = one_shot
    @current_draft = one_shot ? nil : drafts[:current].to_s.presence
    @manual = ContactTrackings::Assistant::ManualEdits.new(delivered: drafts[:delivered], current: @current_draft)
    @outcome = ContactTrackings::Assistant::TurnOutcome.new(account: account, current_draft: @current_draft,
                                                            manual: @manual, building: drafts[:building],
                                                            said: user_texts)
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
  end

  # Quien quiera saber en qué etapa está el turno (ver TurnProgress). Recibe la etapa
  # y datos sueltos: progress.call(:repairing, round: 2, of: 3).
  def with_progress(callable)
    @progress = callable
    self
  end

  def call
    return Result.new(error: :no_api_key) if @chat.api_key.blank?

    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    progress(:writing, editing: editing? && !building?)
    reply = ContactTrackings::Assistant::ReplyParser.with_extras(ask(conversation))
    return Result.new(error: :unavailable) if reply.nil?

    handle(reply)
  end

  private

  attr_reader :account, :inbox, :messages, :one_shot, :current_draft

  delegate :editing?, :building?, :validate, to: :@outcome

  def handle(reply)
    draft = reply['entrenamiento'].presence
    return questions(reply) if draft.blank?
    return partial(reply, draft) if @outcome.partial?(reply, draft)
    # Entregar sin haber preguntado no es un error de sintaxis, así que el
    # comprobador no lo caza: es el modelo decidiendo por la persona. Se rechaza
    # acá y se lo devuelve al mismo hilo, igual que un hallazgo del comprobador.
    #
    # Al EDITAR no se exige: el comportamiento ya está escrito en el Entrenamiento que
    # había, y preguntar "¿contesta o deriva?" para agregar una regla de estilo sería
    # hacer perder un turno.
    #
    # Tampoco en la redacción de una sola vez: su contrato no trae "modo" y nadie
    # puede contestar la pregunta. Medido el 24/09/2026 con unas instrucciones
    # iniciales que ya decían «CÓMO ATIENDE: responde»: se preguntaba igual, el modelo
    # devolvía la pregunta y el Entrenamiento salía vacío.
    return ask_missing_mode(reply, draft) if !one_shot && @outcome.building? && MODES.exclude?(reply['modo'])

    finish(reply, draft, ContactTrackings::Assistant::ReplyParser.proposal(reply))
  end

  # El modelo solo preguntó: no hay Entrenamiento que comprobar. Si fue un pedido de
  # análisis, la respuesta lleva la lista del comprobador y el botón de corregir
  # (ver AnalysisTurn).
  def questions(reply)
    Result.new(reply: analysis.reply(reply['mensaje']), draft: nil, repairs: 0,
               options: ContactTrackings::Assistant::ReplyParser.options(reply) || analysis.fix_offer)
  end

  # La corrección del botón no toca las rutas que no tenían un aviso corregible. Va al
  # final, después de las reparaciones: la de gramática también las cambiaba.
  def guard_fix(turn, validation)
    return validation unless analysis.fix_request?

    turn.draft = analysis.guard(current_draft, turn.draft)
    validate(turn.draft)
  end

  def analysis
    @analysis ||= ContactTrackings::Assistant::AnalysisTurn.new(account, draft: current_draft, said: user_texts.last,
                                                                         editing: editing?, building: building?)
  end

  # ── fase C: el borrador de cada turno (ver TurnOutcome) ─────────────────────
  def partial(reply, draft)
    @outcome.partial(new_turn(reply, draft), ContactTrackings::Assistant::ReplyParser.options(reply))
  end

  def new_turn(reply, draft, history: nil)
    Turn.new(history: history, message: reply['mensaje'], draft: draft, declared: Array(reply['toca']),
             summary: ContactTrackings::Assistant::ReplyParser.changes(reply))
  end

  # El modelo redactó sin preguntar. Se descarta el borrador y se le devuelve al
  # mismo hilo la pregunta que le faltó: es más barato que entregar un agente que
  # se comporta distinto de lo que la persona pidió, sin que nadie lo note.
  def ask_missing_mode(reply, draft)
    progress(:mode_check)
    history = conversation + [
      { role: 'assistant', content: { mensaje: reply['mensaje'], entrenamiento: draft }.to_json },
      { role: 'user', content: RepairPrompts.t('repair.missing_mode') }
    ]

    corrected = ask(history)
    return Result.new(reply: reply['mensaje'], draft: nil, repairs: 0) if corrected.nil?

    nuevo = corrected['entrenamiento'].presence
    return Result.new(reply: corrected['mensaje'], draft: nil, repairs: 0) if nuevo.blank?

    finish(corrected, nuevo, ContactTrackings::Assistant::ReplyParser.proposal(corrected))
  end

  def finish(reply, draft, proposal)
    turn = new_turn(reply, draft, history: conversation)

    repair_edit(turn)
    validation, repairs = repair_grammar(turn)
    validation, cruces = repair_routing(turn, validation)
    validation = guard_fix(turn, validation)

    @outcome.delivery(turn, validation, repairs, cruces, proposal)
  end

  # ── la vuelta de corrección, una sola forma para los tres bucles ────────────
  # Le muestra al modelo lo que entregó, le dice qué encontró, y se queda con lo
  # nuevo. Devuelve false si no hubo respuesta usable: el turno sigue con lo anterior.
  def resend(turn, prompt)
    turn.history += [{ role: 'assistant', content: { mensaje: turn.message, entrenamiento: turn.draft }.to_json },
                     { role: 'user', content: prompt }]

    reply = ask(turn.history)
    return false if reply.nil? || reply['entrenamiento'].blank?

    turn.message = reply['mensaje']
    turn.draft = reply['entrenamiento']
    turn.declared |= Array(reply['toca'])
    turn.summary = ContactTrackings::Assistant::ReplyParser.changes(reply).presence || turn.summary
    true
  end

  def progress(stage, **info)
    @progress&.call(stage, **info)
  end

  def within_budget?
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at < TURN_BUDGET_SECONDS
  end

  # ── 1 · edición ─────────────────────────────────────────────────────────────
  # Solo lo DESTRUCTIVO y no declarado vuelve al modelo (ver DraftDiff). Una línea
  # de más en [ETIQUETAS] se muestra en los cambios; una sección borrada que nadie
  # pidió borrar se le devuelve.
  def repair_edit(turn)
    # Sobre un borrador, reescribir ramas marcadas es justamente completarlas.
    return if building?

    peligrosos = @outcome.diff(turn).undeclared(turn.declared).select(&:destructive?)
    return if peligrosos.empty? || !within_budget?

    progress(:edit_repair)
    resend(turn, RepairPrompts.edit(peligrosos))
  end

  # ── 2 · gramática ───────────────────────────────────────────────────────────
  def repair_grammar(turn)
    repairs = 0
    progress(:checking)
    validation = validate(turn.draft)

    while repairable(validation).any? && repairs < MAX_REPAIRS && within_budget?
      repairs += 1
      progress(:repairing, round: repairs, of: MAX_REPAIRS)
      break unless resend(turn, RepairPrompts.grammar(repairable(validation)))

      validation = validate(turn.draft)
    end

    [validation, repairs]
  end

  # ── 3 · ruteo: que cada rama se elija a sí misma ────────────────────────────
  # El comprobador dice si el Entrenamiento se ejecuta. Esto dice si rutea, que es
  # lo que ningún parser puede contestar — y es donde el Asistente fallaba: escribió
  # dos ramas con la misma descripción, y "a como esta el dolar hoy" dentro de la
  # rama comercial teniendo una rama fuera_de_alcance.
  #
  # Recién con el Entrenamiento EJECUTABLE: un texto con bloqueantes no clasifica nada.
  #
  # Al editar, solo se corrigen los cruces de las ramas que se TOCARON. Un cruce que el
  # Entrenamiento ya traía se muestra, pero no justifica reescribir una rama que la
  # persona no pidió cambiar.
  # Las marcas pendientes NO vuelven al modelo: son datos que tiene la persona, y
  # pedirle que las "corrija" es pedirle que los invente.
  # Al editar un agente que ya existe, lo que depende de la cuenta (una fuente, un tipo
  # de caso) no se repara solo: medido el 24/09/2026, una hoja que no existía en la
  # cuenta de prueba terminó cambiada por el foro de otra empresa. Queda en rojo y lo
  # decide la persona. Al crear, sí: ahí el modelo elige del inventario.
  def repairable(validation)
    fijos = editing? && !building? ? ContactTrackings::Assistant::CheckerSection::ACCOUNT_BOUND : []
    validation[:blocking].reject { |finding| finding[:code] == :pending_marker || fijos.include?(finding[:code]) }
  end

  def repair_routing(turn, validation)
    return [validation, []] if repairable(validation).any?

    progress(:routing)
    cruces = route_mismatches(turn.draft)
    corregibles = correctable(turn, cruces)
    return [validation, cruces] if corregibles.empty? || !within_budget?

    MAX_ROUTE_REPAIRS.times do
      progress(:routing_repair)
      break unless resend(turn, RepairPrompts.routing(corregibles))

      nueva = validate(turn.draft)
      # Si la corrección del ruteo rompió la gramática, manda el comprobador: un
      # Entrenamiento que no ejecuta es peor que uno que rutea flojo.
      return [nueva, []] if nueva[:blocking].any?

      validation = nueva
      cruces = route_mismatches(turn.draft)
    end

    [validation, cruces]
  end

  def correctable(turn, cruces)
    return cruces if building?

    tocadas = @outcome.diff(turn).changes.select(&:route).map(&:key)
    cruces.select { |c| tocadas.include?("@ruta(#{c.route})") }
  end

  def route_mismatches(draft)
    ContactTrackings::Assistant::RouteSelfCheck.new(account, draft: draft, inbox: inbox).call
  rescue StandardError => e
    # Que no se pueda probar el ruteo no debe costarle el Entrenamiento a nadie:
    # se entrega lo que ya pasó el comprobador.
    Rails.logger.warn "[Asistente] no se pudo probar el ruteo: #{e.message}"
    []
  end

  # Lo que escribió la persona: las etiquetas de un borrador solo valen si salen de acá.
  def user_texts
    messages.select { |m| m['role'] == 'user' }.map { |m| m['content'].to_s }
  end

  def ask(history)
    @chat.call(history)
  end

  # ── el prompt ───────────────────────────────────────────────────────────────
  def conversation
    [{ role: 'system', content: system_prompt }] + messages.map { |m| m.slice('role', 'content').symbolize_keys }
  end

  # El contrato fijo, el inventario de ESTA cuenta, cómo trabajar, lo que ya marcó el
  # comprobador (CheckerSection) y —si hay— el Entrenamiento que se está editando. Va al final: es lo que el modelo tiene que
  # tener más presente al contestar.
  def system_prompt
    @system_prompt ||= [
      ContactTrackings::Assistant::Contract.call,
      inventory_section,
      ContactTrackings::Assistant::Instructions.call(one_shot: one_shot, max_turns: MAX_INTERVIEW_TURNS),
      (ContactTrackings::Assistant::CheckerSection.call(current_draft, account: account, result: analysis.result) if editing?),
      (if editing?
         ContactTrackings::Assistant::EditingInstructions.call(current_draft, manual: @manual.labels,
                                                                              building: building?)
       end)
    ].compact.join("\n\n")
  end

  def inventory_section
    inventory = ContactTrackings::Assistant::InventoryService.new(account, inbox: inbox).call
    ContactTrackings::Assistant::InventoryPrompt.call(inventory)
  end
end
