# frozen_string_literal: true

# Agentes listos — los puestos empaquetados que la empresa activa en sus bandejas.
# GET    /ready_agents          catálogo (con «Próximamente»), los agentes de la cuenta y las bandejas
# POST   /ready_agents          activar uno { ready_agent: { kind, name, enabled, inbox_ids, settings } }
# PATCH  /ready_agents/:id      cambiarlo, prenderlo o apagarlo
# DELETE /ready_agents/:id
# POST   /ready_agents/test     chat de prueba con lo que hay en el formulario (sin guardar ni mandar nada)
#                               { ready_agent: {...}, messages: [{ role: user|assistant, content }] }
# Solo administradores.
class Api::V1::Accounts::ReadyAgentsController < Api::V1::Accounts::BaseController
  SETTINGS = %w[objective questions qualified_when discard_when tone instructions handoff_user_id handoff_team_id
                client_user_id client_team_id only_prospects case_type_id appointment_minutes appointment_kind
                appointment_location business_what business_who business_coverage business_why business_practical
                business_use_catalog].freeze
  LISTS = { appointment_user_ids: [], required_contact: [], qualify: %i[key on text], objections: %i[objection answer] }.freeze
  BOOLEANS = %w[only_prospects business_use_catalog].freeze
  MAX_TEST_MESSAGES = 30

  before_action :require_admin
  before_action :set_agent, only: %i[update destroy]

  def index
    render json: { catalog: ReadyAgents::Catalog.all, agents: Current.account.ready_agents.order(:id).map { |a| agent_json(a) },
                   inboxes: inboxes, calendar_users: calendar_users }
  end

  def create
    agent = Current.account.ready_agents.new(agent_params.merge(created_by: current_user))
    return render json: { error: agent.errors.full_messages.to_sentence }, status: :unprocessable_entity unless agent.save

    render json: { agent: agent_json(agent) }, status: :created
  end

  def update
    @agent.assign_attributes(agent_params)
    return render json: { error: @agent.errors.full_messages.to_sentence }, status: :unprocessable_entity unless @agent.save

    render json: { agent: agent_json(@agent) }
  end

  def destroy
    @agent.destroy!
    head :ok
  end

  def test
    agent = Current.account.ready_agents.new(agent_params.merge(created_by: current_user))
    result = ReadyAgents::Runner.new(agent, history: test_history).test
    return render json: result, status: :unprocessable_entity if result[:error]

    render json: result
  end

  private

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def set_agent
    @agent = Current.account.ready_agents.find(params[:id])
  end

  # Sin `settings` en el pedido (p. ej. el interruptor de prender/apagar de la lista) no se
  # tocan: antes se guardaban vacías y el agente perdía toda su configuración.
  def agent_params
    raw = params.require(:ready_agent)
    permitted = raw.permit(:kind, :name, :enabled, inbox_ids: []).to_h
    return permitted unless raw[:settings].respond_to?(:permit)

    settings = raw[:settings].permit(*SETTINGS, **LISTS).to_h
    BOOLEANS.each { |key| settings[key] = boolean(settings[key]) if settings.key?(key) }
    settings['qualify']&.each { |q| q['on'] = boolean(q['on']) }
    permitted.merge(settings: settings)
  end

  def boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def test_history
    Array(params[:messages]).last(MAX_TEST_MESSAGES).filter_map do |m|
      role = m[:role] == 'assistant' ? 'assistant' : 'user'
      content = m[:content].to_s.strip.first(1500)
      { role: role, content: content } if content.present?
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

  def agent_json(agent)
    live = agent.sessions.live.count
    agent.slice(:id, :kind, :name, :enabled, :inbox_ids, :settings, :created_at)
         .merge(live_sessions: live, finished: agent.sessions.where.not(status: ReadyAgentSession::LIVE).group(:status).count)
  end
end
