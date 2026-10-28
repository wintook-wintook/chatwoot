# Plan-Roles-Permisos — el candado por área en el servidor.
#
# Cada controlador de cuenta pertenece a un área del menú (AREA_BY_CONTROLLER).
# Si el rol del usuario no entra a esa área, la API contesta 403 aunque se
# llegue por URL; con nivel «view» solo se permite leer.
#
# Algunos controladores se leen desde otras pantallas (p. ej. la conversación
# carga los tableros o las plantillas), así que de esos solo se protege la
# escritura (WRITE_ONLY_AREAS): leer sigue abierto para no romper nada.
#
# Además expone `access_grant` y `account_case_tickets` (los casos que le tocan
# al usuario) para que los controladores no armen el alcance por su cuenta.
module AccessAreaGuard
  extend ActiveSupport::Concern

  # 'cases' = Ventas o Servicio (la clase de cada caso decide; ver Access::Grant).
  AREA_BY_CONTROLLER = {
    'conversations' => %w[conversations conversations/assignments conversations/labels conversations/messages
                          conversations/participants conversations/draft_messages conversations/direct_uploads],
    'clients' => %w[contacts contacts/conversations contacts/contact_inboxes contacts/labels contacts/notes contacts/owners contacts/summaries
                    organizations],
    'cases' => %w[case_tickets case_notes case_events case_conversations case_ticket_relations case_project_children
                  case_work_order_items case_tasks case_meetings case_meeting_series case_notices case_service_reports field_visits],
    'agenda' => %w[case_tasks_index],
    'campaigns' => %w[campaigns tracking_campaigns]
  }.transform_values { |names| names.map { |name| "api/v1/accounts/#{name}" } }.freeze

  WRITE_ONLY_AREAS = {
    'sales' => %w[conversations/kanban],
    'ai_agents' => %w[tracking_templates knowledge_base],
    'settings' => %w[case_types case_type_columns case_type_fields case_type_column_tasks case_categories case_services
                     case_sla_policies case_portals case_settings case_folio_configs case_outcome_reasons case_rules
                     case_ai_configs kanban_processes kanban_type_processes access_roles]
  }.transform_values { |names| names.map { |name| "api/v1/accounts/#{name}" } }.freeze

  included do
    before_action :enforce_access_area
  end

  private

  def access_grant
    @access_grant ||= Access::Grant.for(Current.account_user)
  end

  def account_case_tickets
    access_grant.case_tickets(Current.account.case_tickets)
  end

  def enforce_access_area
    return if access_grant.admin? || report_metrics_request?

    area, strict = controller_area
    render_access_denied if area && !area_permits_request?(area, strict)
  end

  # Estricta: hay que tener el área. Siempre: para escribir hay que poder escribir.
  def area_permits_request?(area, strict)
    return false if strict && !area_allowed?(area)

    request.get? || area_writable?(area)
  end

  # [área, estricta?] del controlador actual; nil si no pertenece a ninguna.
  def controller_area
    strict = AREA_BY_CONTROLLER.find { |_, paths| paths.include?(controller_path) }&.first
    return [strict, true] if strict

    [WRITE_ONLY_AREAS.find { |_, paths| paths.include?(controller_path) }&.first, false]
  end

  def area_allowed?(area)
    area == 'cases' ? access_grant.case_area_allowed? : access_grant.allowed?(area)
  end

  def area_writable?(area)
    return access_grant.writable?(area) unless area == 'cases'

    access_grant.writable?(:sales) || access_grant.writable?(:service)
  end

  # El Dashboard de servicio sale de case_tickets#metrics; también es de Informes.
  def report_metrics_request?
    controller_path == 'api/v1/accounts/case_tickets' && action_name == 'metrics' && access_grant.allowed?(:reports)
  end

  # Casos para dashboards: quien ve todos los Informes ve la cuenta completa.
  def report_case_tickets
    return Current.account.case_tickets if %w[all view].include?(access_grant.level(:reports))

    account_case_tickets
  end

  def render_access_denied
    render json: { error: I18n.t('access_roles.denied') }, status: :forbidden
  end
end
