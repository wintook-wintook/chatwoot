# «Compartir mi calendario» (fix/calendario_google F3c): cada agente decide, con SU conexión de
# Google, qué ve cada compañero de la cuenta. Son las mismas reglas de acceso (ACL) de
# calendar.google.com: lo que se cambie aquí se ve allá y al revés.
#
# Solo se muestran y tocan reglas de compañeros de la cuenta; las demás (otras personas,
# dominio, público) se dejan como están. Una regla «owner» (Administrar) dada desde Google
# tampoco se toca desde aquí.
class Api::V1::Accounts::GoogleCalendar::SharingRulesController < Api::V1::Accounts::BaseController
  ROLE_BY_LEVEL = { 'free_busy' => 'freeBusyReader', 'details' => 'reader', 'schedule' => 'writer' }.freeze
  LEVEL_BY_ROLE = ROLE_BY_LEVEL.invert.merge('owner' => 'owner').freeze
  LEVELS = (ROLE_BY_LEVEL.keys + ['none']).freeze

  before_action :require_integration
  before_action :build_service

  # GET /google_calendar/sharing_rules
  def index
    roles = roles_by_email
    rows = coworker_users.map { |user| row_for(user, roles) }
    render json: { sharing_rules: rows, google_email: @integration.google_email }
  rescue StandardError => e
    render json: { error: google_message(e) }, status: :unprocessable_entity
  end

  # PUT /google_calendar/sharing_rules/:id   { level: none | free_busy | details | schedule }
  def update
    coworker = coworker_users.find { |u| u.id == params[:id].to_i }
    return render json: { error: 'not_found' }, status: :not_found unless coworker

    error = validate_update(coworker)
    return render json: { error: error }, status: :unprocessable_entity if error

    apply_level(integrations_by_user[coworker.id].google_email, params[:level])
    GoogleCalendarCoworkerService.clear_cache_for(@integration.google_email)
    render json: row_for(coworker, roles_by_email)
  rescue StandardError => e
    render json: { error: google_message(e) }, status: :unprocessable_entity
  end

  private

  def require_integration
    @integration = current_user.user_calendar_integrations.find_by(account: Current.account)
    render json: { error: 'Google Calendar not connected' }, status: :unprocessable_entity unless @integration
  end

  def build_service
    @service = GoogleCalendarService.new(@integration)
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarSharingRules] user #{current_user.id}: #{e.message}"
    render json: { error: 'reconnect' }, status: :unprocessable_entity
  end

  def validate_update(coworker)
    integration = integrations_by_user[coworker.id]
    return 'invalid_level' unless LEVELS.include?(params[:level])
    return 'not_connected' unless integration
    return 'same_google' if same_google?(integration)
    return 'owner_rule' if roles_by_email[integration.google_email.downcase] == 'owner'

    nil
  end

  def apply_level(email, level)
    if level == 'none'
      @service.delete_acl_rule(email)
    else
      @service.upsert_acl_rule(email, ROLE_BY_LEVEL.fetch(level))
    end
    @roles_by_email = nil
  end

  def row_for(user, roles)
    integration = integrations_by_user[user.id]
    return { agent_id: user.id, level: 'none', status: 'not_connected' } unless integration
    return { agent_id: user.id, level: 'none', status: 'same_google' } if same_google?(integration)

    level = LEVEL_BY_ROLE.fetch(roles[integration.google_email.downcase], 'none')
    { agent_id: user.id, level: level, status: level == 'owner' ? 'owner_rule' : 'editable' }
  end

  # { correo en minúsculas => role } solo de reglas de personas (scope type user).
  def roles_by_email
    @roles_by_email ||= @service.list_acl
                                .select { |rule| rule.dig('scope', 'type') == 'user' }
                                .to_h { |rule| [rule.dig('scope', 'value').to_s.downcase, rule['role']] }
  end

  def coworker_users
    @coworker_users ||= Current.account.users.where.not(id: current_user.id).order(:name).to_a
  end

  def integrations_by_user
    @integrations_by_user ||= UserCalendarIntegration.where(account: Current.account, user_id: coworker_users.map(&:id))
                                                     .index_by(&:user_id)
  end

  def same_google?(integration)
    integration.google_email.to_s.casecmp?(@integration.google_email.to_s)
  end

  # Motivo legible de Google (p. ej. Workspace que no deja compartir hacia fuera).
  def google_message(error)
    json = error.message[/\{.*\}/m]
    (json && JSON.parse(json).dig('error', 'message')) || error.message
  rescue JSON::ParserError
    error.message
  end
end
