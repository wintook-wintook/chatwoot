# Plan-Roles-Permisos P3 — Ajustes › Roles: los 4 roles editables de la cuenta
# (el Administrador es fijo). Cada empresa los edita directo y puede
# «Restaurar como venía». Solo administradores.
class Api::V1::Accounts::AccessRolesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :set_role, only: %i[update restore]

  def index
    render json: { access_roles: AccessRole.for_account(Current.account).map { |role| role_json(role) },
                   area_levels: AccessRole::AREA_LEVELS, actions: AccessRole::ACTIONS }
  end

  def update
    @role.update!(areas: @role.areas.merge(permitted_areas), actions: @role.actions.merge(permitted_actions))
    render json: { access_role: role_json(@role) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def restore
    @role.restore!
    render json: { access_role: role_json(@role) }
  end

  private

  def set_role
    @role = AccessRole.for_account(Current.account).find { |role| role.id == params[:id].to_i }
    render json: { error: 'Rol no encontrado' }, status: :not_found unless @role
  end

  def permitted_areas
    params.fetch(:areas, {}).permit(*AccessRole::AREAS).to_h
  end

  def permitted_actions
    params.fetch(:actions, {}).permit(*AccessRole::ACTIONS).to_h
          .transform_values { |value| ActiveModel::Type::Boolean.new.cast(value) || false }
  end

  def customized?(role)
    defaults = AccessRole::DEFAULTS[role.key]
    role.areas != defaults['areas'] || role.actions != defaults['actions']
  end

  # Un agente sin rol cuenta como Supervisor.
  def role_json(role)
    agents = Current.account.account_users.agent
    agents = role.key == AccessRole::DEFAULT_KEY ? agents.where(access_role_id: [role.id, nil]) : agents.where(access_role: role)
    {
      id: role.id,
      key: role.key,
      areas: AccessRole::AREAS.index_with { |area| role.area_level(area) },
      actions: AccessRole::ACTIONS.index_with { |action| role.action?(action) },
      customized: customized?(role),
      agents_count: agents.count
    }
  end
end
