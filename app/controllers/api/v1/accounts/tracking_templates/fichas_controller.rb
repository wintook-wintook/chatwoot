# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LA FICHA DEL AGENTE
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md. Solo administradores (igual que el Asistente).
#
# Agente nuevo (sin id):
#   GET  tracking_templates/ficha_catalog?inbox_id=   las tarjetas para marcar
#   POST tracking_templates/ficha_preview             ofertas + Entrenamiento generado + comprobador
#   POST tracking_templates/ficha_create              crea el agente con todo eso (sin IA)
#   POST tracking_templates/ficha_suggest             ✨ objetivo y contexto propuestos con IA (1 llamada)
#   GET  tracking_templates/ficha_sheet/:source_id    columnas y primeras filas de una hoja
#   POST tracking_templates/ficha_test                probar antes de crear (job; turn_id) → 202
#   GET  tracking_templates/ficha_test/:turn_id       avance o resultado de la prueba
#     params: name, inbox_id, items[], skip[] (ofertas apagadas), objective, business, tone,
#             customer_display_name, files[] ({ name }: archivos que la pantalla sube al crear),
#             keyword_actions[] (Reglas), phrases ({ oferta => [frases] }), activate (crear y activar),
#             agenda ({ calendar_event_duration, timezone, slots_presentation, booking_calendar_ids }),
#             welcome (bienvenida), files[] ({ name, ask, welcome, attempts[] }),
#             retry_interval_value, retry_interval_unit, attempts, whatsapp_templates[], email_signature
#
# Agente que ya existe:
#   GET   tracking_templates/:id/ficha        tarjetas + lo marcado + cambios contra el prompt
#   PATCH tracking_templates/:id/ficha        guarda lo marcado (items) y devuelve los cambios
#   POST  tracking_templates/:id/ficha/apply  aplica al prompt add[] (ofertas), remove[] (rutas) y
#                                             phrases ({ ruta => [frases] }: se suman a su descripción)
#   POST  tracking_templates/:id/ficha/activate  crea la automatización que se lo asigna en su canal
#   POST  tracking_templates/:id/ficha/test      probar su Entrenamiento (job; resultado en ficha_test/:turn_id)
# ================================================================================

class Api::V1::Accounts::TrackingTemplates::FichasController < Api::V1::Accounts::BaseController
  INVALID = 'El Entrenamiento tiene errores que impiden guardarlo.'
  NO_AI = 'No se pudo proponer con IA: revisa que la cuenta tenga OpenAI activo.'
  ITEM_FIELDS = [:key, { parts: [], sheet: [:purpose, :search_by, { answer_with: [] }],
                         ticket: [:priority, { reasons: [], escalate_from: [] }] }].freeze
  NO_CHANNEL = 'Para activarlo, primero elige su canal en la Ficha de Agente IA.'

  before_action :check_authorization
  before_action :fetch_tracking_template, only: [:show, :update, :apply, :activate, :test_existing]

  def catalog
    render json: { cards: draft.cards }
  end

  # ✨ Para qué sirve una hoja y cómo buscar en ella (una llamada a OpenAI).
  def sheet_suggest
    hoja = Current.account.knowledge_sources.find_by!(id: params[:source_id], source_type: 'google_sheet')
    render_suggestion(analyzer.sheet(hoja))
  end

  # ✨ Preguntas para hacerle al cliente, una a la vez (una llamada a OpenAI).
  def questions_suggest
    render_suggestion(analyzer.questions(objective: params[:objective]))
  end

  # ✨ Motivos para levantar un tipo de ticket (una llamada a OpenAI).
  def ticket_suggest
    render_suggestion(analyzer.ticket(CaseType.where(account_id: Current.account.id).find(params[:case_type_id])))
  end

  # Lo que contiene una hoja (columnas y primeras filas), para decir qué hacer con ella.
  def sheet_preview
    hoja = Current.account.knowledge_sources.find_by!(id: params[:source_id], source_type: 'google_sheet')
    render json: ContactTrackings::Ficha::SheetUse.preview(hoja)
  end

  def preview
    render json: draft.result.merge(readiness: new_readiness.call)
  end

  # Probar antes de crear: ~20 llamadas en serie → job; la pantalla consulta test_result.
  # (No se llama `test`: pisaría Kernel#test.)
  def run_test
    ContactTrackings::Ficha::TestJob.perform_later(Current.account.id, Current.user.id, valid_turn_id, draft.params.to_h)
    render json: { turn_id: valid_turn_id }, status: :accepted
  end

  # Probar un agente que ya existe: su Entrenamiento tal cual (mismo job y mismo resultado).
  def test_existing
    ContactTrackings::Ficha::TestJob.perform_later(Current.account.id, Current.user.id, valid_turn_id,
                                                   { 'template_id' => @tracking_template.id })
    render json: { turn_id: valid_turn_id }, status: :accepted
  end

  def test_result
    resultado = ContactTrackings::Assistant::TurnProgress.read_result(Current.account, Current.user, params[:turn_id])
    return render json: { done: true, result: resultado } if resultado

    render json: { done: false, progress: ContactTrackings::Assistant::TurnProgress.read(Current.account, Current.user, params[:turn_id]) }
  end

  def activate
    regla = readiness_for(@tracking_template).activate!
    render json: ficha_json.merge(rule: regla.slice(:id, :name))
  rescue ArgumentError
    render json: { error: NO_CHANNEL }, status: :unprocessable_entity
  end

  def show
    render json: ficha_json
  end

  # ✨ Proponer objetivo y contexto con IA (una llamada a OpenAI; Ficha::Suggester).
  def suggest
    propuesta = ContactTrackings::Ficha::Suggester.new(
      account: Current.account, name: draft.name, offers: draft.offers, cards: draft.cards,
      business: params[:business], tone: params[:tone], display_name: params[:customer_display_name],
      welcome: params[:welcome], welcome_files: draft.welcome_files
    ).call(params[:field].to_s == 'welcome' ? :welcome : :fields)
    return render json: { error: NO_AI }, status: :unprocessable_entity if propuesta.nil?

    render json: propuesta
  end

  def create
    resultado = draft.result
    return render json: resultado.merge(error: INVALID), status: :unprocessable_entity unless resultado[:validation][:valid]

    template = Current.account.tracking_templates.create!(new_template_attributes(resultado))
    readiness_for(template).activate! if ActiveModel::Type::Boolean.new.cast(params[:activate]) && template.inbox
    render json: resultado.merge(id: template.id), status: :created
  end

  def update
    bloqueos = ContactTrackings::Ficha::Updater.new(@tracking_template, params, items: items).call
    return render json: { error: INVALID, validation: { blocking: bloqueos } }, status: :unprocessable_entity if bloqueos

    render json: ficha_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def apply
    texto = edited_prompt
    validacion = ContactTrackings::Assistant::ValidatorService.new(texto, account: Current.account).call
    return render json: { error: INVALID, validation: validacion.slice(:blocking) }, status: :unprocessable_entity unless validacion[:valid]

    @tracking_template.update!(complementary_prompt: texto, version_note: 'Cambios de la ficha')
    render json: ficha_json
  end

  private

  def new_template_attributes(resultado)
    { name: draft.name, inbox_id: draft.inbox&.id, user: Current.user, objective: resultado[:objective],
      ai_context: resultado[:ai_context].presence, complementary_prompt: resultado[:prompt],
      version_note: 'Creado desde la ficha', customer_display_name: params[:customer_display_name].presence }
      .merge(new_resources_attributes)
  end

  # Lo de Recursos: tarjetas, archivos, intentos, agenda, reglas y seguimiento.
  def new_resources_attributes
    integraciones = calendar_ids(draft.items)
    { resources: resources_for(draft.items).merge('files' => draft.file_rules).merge(settings.attempts),
      calendar_integration_ids: integraciones, keyword_actions: settings.keyword_actions || [] }
      .merge(settings.agenda(integraciones)).merge(settings.follow_up)
  end

  def settings = @settings ||= ContactTrackings::Ficha::Settings.new(params)

  def analyzer
    ContactTrackings::Ficha::Analyzer.new(Current.account, agent_name: params[:name], offers: draft.offers)
  end

  def render_suggestion(resultado)
    return render json: { error: NO_AI }, status: :unprocessable_entity if resultado.nil?

    render json: resultado
  end

  # El prompt con lo que la persona aceptó: add[] = ofertas de la ficha, remove[] = rutas.
  def edited_prompt
    ContactTrackings::Ficha::PromptEditor.new(@tracking_template.complementary_prompt, name: @tracking_template.name)
                                         .apply(add: Array(params[:add]).map(&:to_s), remove: Array(params[:remove]).map(&:to_s),
                                                phrases: route_phrases, offers: template_offers)
                                         .text
  end

  # { 'agendar_cita' => ['¿a qué hora atienden?'] }
  def route_phrases
    crudo = params[:phrases]
    crudo = crudo.to_unsafe_h if crudo.respond_to?(:to_unsafe_h)
    return {} unless crudo.is_a?(Hash)

    crudo.to_h { |ruta, frases| [ruta.to_s, Array(frases).map(&:to_s)] }
  end

  def template_offers
    cards = catalog_for(@tracking_template.inbox, @tracking_template).call
    ContactTrackings::Ficha::Offers.new(cards, current_items).call.index_by { |o| o[:key] }
  end

  # El turn_id lo genera la pantalla; si no sirve para TurnProgress, uno nuevo.
  def valid_turn_id
    @valid_turn_id ||= begin
      pedido = params[:turn_id].to_s
      pedido.match?(ContactTrackings::Assistant::TurnProgress::TURN_ID_RE) ? pedido : "ficha-#{SecureRandom.hex(8)}"
    end
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:tracking_template_id])
  end

  def catalog_for(bandeja, template = nil)
    ContactTrackings::Ficha::Catalog.new(Current.account, inbox: bandeja, template: template)
  end

  # [{ 'key' => 'google_sheet:12' }, { 'key' => 'canned_response', 'parts' => ['PATITAS'] }]
  def items
    lista = Array(params[:items]).map { |item| item_from(item) }
    lista.select { |i| i['key'].present? }
  end

  def item_from(item)
    h = item.respond_to?(:permit) ? item.permit(*ITEM_FIELDS).to_h : item.to_h
    { 'key' => h['key'].to_s, 'parts' => Array(h['parts']).map(&:to_s).presence, 'sheet' => h['sheet'].presence,
      'ticket' => h['ticket'].presence }.compact
  end

  def current_items
    ContactTrackings::Ficha::Changes.new(@tracking_template).items
  end

  def resources_for(lista)
    { 'items' => lista, 'confirmed_at' => Time.current.iso8601 }
  end

  def calendar_ids(lista)
    lista.filter_map { |i| i['key'][/\Acalendar:(\d+)\z/, 1]&.to_i }
  end

  # Lo capturado en la ficha de un agente NUEVO, armado (ver Ficha::Draft).
  def draft = @draft ||= ContactTrackings::Ficha::Draft.new(Current.account, params)

  def new_readiness
    ContactTrackings::Ficha::Readiness.new(Current.account, offers: draft.active_offers, inbox: draft.inbox,
                                                            ai_context: draft.result[:ai_context])
  end

  def readiness_for(template)
    cards = catalog_for(template.inbox, template).call
    ofertas = ContactTrackings::Ficha::Offers.new(cards, ContactTrackings::Ficha::Changes.new(template, cards: cards).items).call
    ContactTrackings::Ficha::Readiness.new(Current.account, offers: ofertas, template: template)
  end

  def ficha_json
    ContactTrackings::Ficha::Presenter.new(@tracking_template.reload).call
  end
end
