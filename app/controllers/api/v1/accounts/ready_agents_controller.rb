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
# ready_agent.sources: las fuentes que marcó en «Qué sabe» (llaves de Motor2::SourceMap); el índice
# trae `sources` con todas las de la cuenta y qué hay en cada una.
# Solo administradores.
class Api::V1::Accounts::ReadyAgentsController < Api::V1::Accounts::BaseController
  SETTINGS = %w[objective questions qualified_when discard_when tone instructions handoff_user_id handoff_team_id
                client_user_id client_team_id only_prospects case_type_id appointment_minutes appointment_kind
                appointment_location business_what business_who business_coverage business_why business_practical
                business_use_catalog doubts not_found off_topic].freeze
  LISTS = { appointment_user_ids: [], required_contact: [], qualify: %i[key on text], objections: %i[objection answer] }.freeze
  MAX_TEST_MESSAGES = 30
  ROLES = %w[user assistant].freeze

  before_action :require_admin
  before_action :set_agent, only: %i[update destroy]

  def index
    render json: { catalog: catalog, agents: function_agents.order(:id).map { |t| Motor2::Functions::AgentJson.call(t) },
                   inboxes: inboxes, calendar_users: calendar_users, sources: Motor2::SourceMap.new(Current.account).available }
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
    Current.account.tracking_templates.where(agent_function: Motor2::Functions::CLASSES.keys, archived_at: nil)
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
    permitted = raw.permit(:kind, :name, :display_name, :enabled, inbox_ids: [], sources: []).to_h
    permitted[:inbox_ids] ||= [] if raw.key?(:inbox_ids)
    permitted[:sources] ||= [] if raw.key?(:sources)
    return permitted unless raw[:settings].respond_to?(:permit)

    permitted.merge(settings: raw[:settings].permit(*SETTINGS, **LISTS).to_h)
  end

  # Lo que hay en el asistente, sin guardar (sobre una copia del agente si ya existe).
  def test_draft
    template = function_agents.find_by(id: params[:id]) if params[:id].present?
    Motor2::Functions::Form.new(Current.account, agent_params, user: current_user, template: template&.dup).build
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

  # Con quién se puede agendar: quien tiene Google Calendar conectado.
  def calendar_users
    UserCalendarIntegration.where(account_id: Current.account.id).includes(:user)
                           .filter_map { |i| i.user && { id: i.user.id, name: i.user.name } }
  end
end
