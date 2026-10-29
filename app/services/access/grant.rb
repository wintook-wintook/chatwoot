# Plan-Roles-Permisos — lo que un usuario puede ver y hacer en una cuenta, según
# su rol. Es EL lugar que decide el alcance: los controladores, buscadores y
# reportes le preguntan a este objeto en vez de mirar el rol por su cuenta.
#
#   grant = Access::Grant.for(account_user)
#   grant.level(:sales)                  # => 'own'
#   grant.can?(:reassign)                # => false
#   grant.case_tickets(account.case_tickets)  # solo los que le tocan
#
# Administrador (o sin account_user, p. ej. un bot): todo.
class Access::Grant
  CASE_AREAS = { 'commercial' => 'sales' }.freeze # el resto de las clases son Servicio
  WRITE_LEVELS = %w[own all].freeze

  attr_reader :account_user, :role

  def self.for(account_user)
    return new(nil, nil) if account_user.nil? || account_user.administrator?

    new(account_user, account_user.access_role || AccessRole.default_for(account_user.account))
  end

  def initialize(account_user, role)
    @account_user = account_user
    @role = role
  end

  def admin?
    role.nil?
  end

  def role_key
    admin? ? 'administrator' : role.key
  end

  def level(area)
    admin? ? 'all' : role.area_level(area)
  end

  def allowed?(area)
    level(area) != 'none'
  end

  def own?(area)
    level(area) == 'own'
  end

  def writable?(area)
    WRITE_LEVELS.include?(level(area))
  end

  def can?(action)
    admin? || role.action?(action)
  end

  def user_id
    account_user&.user_id
  end

  # ── Casos ──────────────────────────────────────────────────────────────────
  def self.area_for_case_class(case_class)
    CASE_AREAS.fetch(case_class.to_s, 'service')
  end

  def case_area_allowed?
    allowed?(:sales) || allowed?(:service)
  end

  # Ventas = clase Comercial; Servicio = el resto (y los casos sin tipo). Usa
  # subconsultas, no JOIN (Trampas #21).
  def case_tickets(scope)
    return scope if admin?

    parts = []
    parts << own_filter(scope.commercial, :sales, :assignee_id) if allowed?(:sales)
    parts << own_filter(scope.non_commercial, :service, :assignee_id) if allowed?(:service)
    return scope.none if parts.empty?

    parts.reduce { |acc, part| acc.or(part) }
  end

  # Catálogo (Plan-Catalogo-Cotizaciones): lo consulta quien tiene Ventas o
  # Servicio (el técnico busca refacciones); lo edita Ventas con «Todo».
  def catalog_readable?
    case_area_allowed?
  end

  def catalog_writable?
    level(:sales) == 'all'
  end

  # Cotizaciones: con Ventas en «Todo»/«Ver» todas; si no, las suyas y las que
  # salieron de un caso que puede ver (p. ej. el técnico que cotiza en sitio).
  def quotes(scope)
    return scope if admin? || %w[all view].include?(level(:sales))
    return scope.none unless case_area_allowed?

    visible_cases = case_tickets(account_user.account.case_tickets)
    scope.where(assignee_id: user_id).or(scope.where(origin_ticket_id: visible_cases.select(:id)))
  end

  def quote_amounts_visible?(quote)
    can?(:see_amounts) || quote.assignee_id == user_id
  end

  def case_writable?(ticket)
    writable?(self.class.area_for_case_class(ticket.case_type&.case_class || 'support'))
  end

  # ── Conversaciones y contactos ─────────────────────────────────────────────
  def conversations(scope)
    return scope if admin? || level(:conversations) == 'all' || level(:conversations) == 'view'

    # feat/chat_interno: «Interno» no es de clientes ni tiene asignado; ahí manda
    # InternalChannel::Access (solo sus participantes), no «solo lo suyo».
    internal = scope.where(inbox_id: InternalChannel::Access.internal_inbox_ids(account_user.account))
    return internal unless allowed?(:conversations)

    own_filter(scope, :conversations, :assignee_id).or(internal)
  end

  def conversation_visible?(conversation)
    return true if admin? || !own?(:conversations)
    return true if conversation.assignee_id == user_id
    return true if conversation.assignee_id.nil? && can?(:take_unassigned)

    conversation.conversation_participants.exists?(user_id: user_id)
  end

  # Un contacto es «suyo» si tiene una conversación o un caso asignado a él.
  def contacts(scope)
    return scope if admin? || !own?(:clients)

    mine = Conversation.where(assignee_id: user_id).select(:contact_id)
    cases = CaseTicket.where(assignee_id: user_id).select(:contact_id)
    owned_orgs = Organization.where(owner_id: user_id).select(:id) # Plan-Organizaciones O3
    scope.where(id: mine).or(scope.where(id: cases)).or(scope.where(owner_id: user_id))
         .or(scope.where(organization_id: owned_orgs))
  end

  # ── Asignación ─────────────────────────────────────────────────────────────
  # ¿Puede dejar `current_assignee_id` → `new_assignee_id`? Sin «reasignar» solo
  # puede quedarse con algo (si es suyo o si puede tomar no asignadas).
  def assignment_allowed?(current_assignee_id, new_assignee_id)
    return true if can?(:reassign)
    return true if current_assignee_id.presence&.to_i == new_assignee_id.presence&.to_i
    return false unless new_assignee_id.to_i == user_id

    current_assignee_id.nil? ? can?(:take_unassigned) : current_assignee_id.to_i == user_id
  end

  # Lo que se manda al front (perfil del usuario).
  def to_h
    {
      role: role_key,
      areas: AccessRole::AREAS.index_with { |area| level(area) },
      actions: AccessRole::ACTIONS.index_with { |action| can?(action) }
    }
  end

  private

  def own_filter(scope, area, column)
    return scope unless own?(area)

    mine = scope.where(column => user_id)
    can?(:take_unassigned) ? mine.or(scope.where(column => nil)) : mine
  end
end
