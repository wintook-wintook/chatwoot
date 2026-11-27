# frozen_string_literal: true

# Agentes listos — el catálogo de funciones (Atención a prospectos, Atención a clientes…) y los
# agentes que la empresa creó con el asistente de cada una. Desde el 2026-11-19 (Plan-Motor-Agentes
# §11.14.5) cada agente es un tracking_template 2.0 de la lista de agentes (agent_function), con el
# motor 2.0: se usa en campañas, automatizaciones, asignación masiva, Delegar y Dali.
# GET    /ready_agents          catálogo (con «Próximamente»), los agentes de función de la cuenta y las bandejas
# POST   /ready_agents          crear uno { ready_agent: { kind, name, display_name, enabled, inbox_ids, settings } }
# PATCH  /ready_agents/:id      cambiarlo, prenderlo o apagarlo
# DELETE /ready_agents/:id      se borra; si está en uso (pláticas, campañas, automatizaciones), se archiva
# POST   /ready_agents/test     chat de prueba con lo que hay en el asistente (motor 2.0, sin guardar ni mandar)
#                               { ready_agent: {...}, id:, messages: [{ role, content }], state: {} }
# POST   /ready_agents/matrix   «Atención a clientes» › Probar la matriz: los ejemplos sí/no de cada área por el
#                               clasificador → { rows: [{ example, area, kind, got, ok }] }
# ready_agent.sources: las fuentes que marcó en «Qué sabe» (llaves de Motor2::SourceMap); el índice
# trae `sources` con todas las de la cuenta y qué hay en cada una.
# Solo administradores.
class Api::V1::Accounts::ReadyAgentsController < Api::V1::Accounts::BaseController
  SETTINGS = %w[objective questions qualified_when discard_when tone instructions handoff_user_id handoff_team_id
                client_user_id client_team_id only_prospects case_type_id appointment_minutes appointment_kind
                appointment_location business_what business_who business_coverage business_why business_practical
                business_use_catalog doubts not_found off_topic welcome price_source not_client human user_id team_id
                purpose offer_what offer_details offer_goal event_id low_score relay hot_when voice_mode
                business_mode attend_hours payment_info send_hour remind_before_days every_days max_per_day min_balance
                outreach_on weekdays_only].freeze
  LISTS = { question_list: [], appointment_user_ids: [], required_contact: [], qualify: %i[key on text],
            objections: %i[objection answer], areas: {}, survey_questions: [],
            # Los de Motor2::Functions::Extras (cada función los limpia al guardar).
            quote: {}, follow_up: {}, voice: {}, appointment_notice: {}, templates: {} }.freeze
  CHANNEL = [:inbox_id, :retry_value, :retry_unit, :attempts, :email_signature, { whatsapp_templates: [] }].freeze
  MAX_TEST_MESSAGES = 30
  ROLES = %w[user assistant].freeze

  before_action :require_admin
  before_action :set_agent, only: %i[update destroy metrics]

  def index
    render json: { catalog: catalog, agents: function_agents.order(:id).map { |t| Motor2::Functions::AgentJson.call(t) },
                   inboxes: inboxes, calendar_users: calendar_users, sources: Motor2::SourceMap.new(Current.account).available,
                   case_types: Current.account.case_types.active.order(:name).map { |c| { id: c.id, name: c.name, case_class: c.case_class } },
                   events: upcoming_events }
  end

  def create
    template = Motor2::Functions::Form.new(Current.account, agent_params, user: current_user).save
    render json: { agent: Motor2::Functions::AgentJson.call(template) }, status: :created
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: error_text(e) }, status: :unprocessable_entity
  end

  def update
    Motor2::Functions::Form.new(Current.account, agent_params, user: current_user, template: @agent).save
    render json: { agent: Motor2::Functions::AgentJson.call(@agent.reload) }
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: error_text(e) }, status: :unprocessable_entity
  end

  # En uso (pláticas vivas, campañas, automatizaciones) o con historia (versiones, pruebas) no se
  # puede borrar: se archiva (deja de atender y sale de las listas).
  def destroy
    @agent.in_use? ? archive : @agent.destroy!
    head :ok
  rescue ActiveRecord::InvalidForeignKey
    archive
    head :ok
  end

  def matrix
    function = Motor2::Config.new(test_draft).function
    raise ArgumentError, 'Solo para «Atención a clientes».' unless function.respond_to?(:areas)

    render json: { rows: Motor2::TriageMatrix.new(Current.account, function.areas).call }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Ejemplos por área («Atención a clientes») o preguntas para calificar («Atención a prospectos») según su negocio.
  def suggest
    # Con «Usar los de la empresa» no vienen: se toman de «Cómo habla tu empresa».
    company = AgentBase::BusinessData.get(Current.account)['fixed']
    business = { what: params[:business_what].presence || company['what'], who: params[:business_who].presence || company['who'] }
               .transform_values { |v| v.to_s.first(1000) }
    render json: Motor2::BusinessSuggestions.new(account: Current.account)
                                            .call(kind: params[:kind], business: business, areas: Array(params[:areas]).map(&:to_s))
  end

  # «Cómo le va» de cualquiera de los tres agentes (Motor2::AgentMetrics).
  def metrics
    render json: Motor2::AgentMetrics.new(@agent).call
  end

  def test
    result = Motor2::Probe.new(test_draft, messages: test_history, state: Motor2::Sanitizer.plain(params[:state])).call
    return render json: result, status: :unprocessable_entity if result[:error]

    render json: result.merge(tools: Array(result.dig(:trace, 'tools')))
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def archive
    @agent.reload.update!(archived_at: Time.current, attending: false)
  end

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def function_agents
    Current.account.tracking_templates.listable.where(agent_function: Motor2::Functions::CLASSES.keys, archived_at: nil)
  end

  def set_agent
    @agent = function_agents.find(params[:id])
  end

  def catalog
    Motor2::Functions.all.map { |e| e.except(:key).merge(kind: e[:key]) }
  end

  # Sin `settings` en el pedido (p. ej. el interruptor de prender/apagar de la lista) no se tocan.
  def agent_params
    raw = params.require(:ready_agent)
    permitted = raw.permit(:kind, :name, :display_name, :enabled, inbox_ids: [], sources: [], channel: CHANNEL, files: {}).to_h
    permitted[:inbox_ids] ||= [] if raw.key?(:inbox_ids)
    permitted[:sources] ||= [] if raw.key?(:sources)
    return permitted unless raw[:settings].respond_to?(:permit)

    permitted.merge(settings: raw[:settings].permit(*SETTINGS, **LISTS).to_h)
  end

  # Lo que hay en el asistente, sin guardar (sobre una copia del agente si ya existe).
  def test_draft
    template = function_agents.find_by(id: params[:id]) if params[:id].present?
    draft = template&.dup&.tap { |copy| copy.draft_of = template.id }
    Motor2::Functions::Form.new(Current.account, agent_params, user: current_user, template: draft).build
  end

  def error_text(error)
    error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def test_history
    Array(params[:messages]).last(MAX_TEST_MESSAGES).filter_map do |m|
      role = m[:role].to_s
      content = m[:content].to_s.strip.first(1500)
      { role: role, content: content } if ROLES.include?(role) && content.present?
    end
  end

  def inboxes
    Current.account.inboxes.where.not(channel_type: 'Channel::Internal').order(:name)
           .map { |i| { id: i.id, name: i.name, channel_type: i.channel_type } }
  end

  # «Vendedor de campaña» › Invitar: los eventos que todavía no pasan.
  def upcoming_events
    Current.account.events.where(closed_at: nil).where('starts_at > ?', 1.day.ago).order(:starts_at).limit(50)
           .map { |e| { id: e.id, name: e.name, starts_at: e.starts_at } }
  end

  # Con quién se puede agendar: quien tiene Google Calendar conectado.
  def calendar_users
    UserCalendarIntegration.where(account_id: Current.account.id).includes(:user)
                           .filter_map { |i| i.user && { id: i.user.id, name: i.user.name } }
  end
end
