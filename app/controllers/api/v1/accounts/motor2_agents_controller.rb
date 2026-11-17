# frozen_string_literal: true

# Motor 2.0 — la ficha de un agente 2.0 (comparte la lista y las tablas de Agentes a medida).
# GET    /motor2_agents/options             lo que la cuenta le puede dar a un agente (bandejas, fuentes, agendas…)
# GET    /motor2_agents/:id                 la ficha
# POST   /motor2_agents                     crear { agent: {...} }
# PATCH  /motor2_agents/:id                 guardar (deja versión)
# GET    /motor2_agents/:id/readiness       ¿listo para atender?
# POST   /motor2_agents/:id/activate        crea la automatización que le asigna las conversaciones de su bandeja
# GET    /motor2_agents/:id/versions        historial
# POST   /motor2_agents/:id/restore         { version_id } vuelve a esa versión (deja una nueva)
# Solo administradores.
class Api::V1::Accounts::Motor2AgentsController < Api::V1::Accounts::BaseController
  ROLES = %w[user assistant].freeze

  before_action :require_admin
  before_action :set_template, except: %i[options create test]
  MAX_TEST_MESSAGES = 30

  def options
    render json: Motor2::Options.new(Current.account, inbox: Current.account.inboxes.find_by(id: params[:inbox_id])).call
  end

  def show
    render json: agent_json
  end

  def create
    @template = Motor2::AgentForm.new(Current.account, params[:agent], user: current_user).save
    render json: agent_json, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    Motor2::AgentForm.new(Current.account, params[:agent], user: current_user, template: @template, note: params[:note]).save
    render json: agent_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # Chat de prueba con lo que hay en la pantalla (sin guardar ni mandar nada).
  # { agent: {...}, id: (si ya existe), messages: [{ role, content }], state: {} }
  def test
    template = Current.account.tracking_templates.find_by(id: params[:id], engine: Motor2::ENGINE) if params[:id].present?
    draft = Motor2::AgentForm.new(Current.account, params[:agent], user: current_user, template: template).build
    render json: Motor2::Probe.new(draft, messages: test_messages, state: Motor2::Sanitizer.plain(params[:state])).call
  end

  def readiness
    render json: { items: readiness_service.call }
  end

  def activate
    rule = readiness_service.activate!
    render json: { items: readiness_service.call, rule: rule.slice(:id, :name) }
  rescue ArgumentError
    render json: { error: 'Primero elige la bandeja del agente.' }, status: :unprocessable_entity
  end

  def versions
    render json: Motor2Version.where(tracking_template_id: @template.id).ordered.limit(50).map { |v| version_json(v) }
  end

  def restore
    version = Motor2Version.find_by!(tracking_template_id: @template.id, id: params[:version_id])
    Motor2::AgentForm.new(Current.account, version.snapshot, user: current_user, template: @template, source: 'restore',
                                                             note: "Volvió a la versión #{version.version}").save
    render json: agent_json
  end

  private

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def set_template
    @template = Current.account.tracking_templates.find_by!(id: params[:id], engine: Motor2::ENGINE)
  end

  def agent_json = Motor2::AgentJson.call(@template.reload)

  def readiness_service = @readiness_service ||= Motor2::Options.readiness(@template)

  def test_messages
    Array(params[:messages]).last(MAX_TEST_MESSAGES).filter_map do |m|
      role = m[:role].to_s
      { role: role, content: m[:content].to_s.first(2000) } if ROLES.include?(role) && m[:content].present?
    end
  end

  def version_json(version)
    { id: version.id, version: version.version, source: version.source, note: version.note, created_at: version.created_at,
      author: version.user&.available_name || version.user&.name, snapshot: version.snapshot }
  end
end
