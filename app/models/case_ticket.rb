# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tickets
#
#  id                         :bigint           not null, primary key
#  assignee_type              :integer          default("bot"), not null
#  closed_at                  :datetime
#  closure_cause              :text
#  closure_solution           :text
#  closure_type               :integer
#  custom_attributes          :jsonb            not null
#  customer_confirmed         :boolean          default(FALSE), not null
#  description                :text
#  escalation_level           :integer          default(0), not null
#  first_response_at          :datetime
#  first_response_time_target :integer
#  folio                      :string
#  impact                     :integer
#  metadata                   :jsonb            not null
#  origin                     :integer          default("whatsapp"), not null
#  priority                   :integer          default("medium"), not null
#  resolution_time_target     :integer
#  resolved_at                :datetime
#  sla_paused_minutes         :integer          default(0), not null
#  sla_paused_since           :datetime
#  sla_status                 :integer          default("on_time"), not null
#  status                     :integer          default("open"), not null
#  ticket_kind                :integer          default("service_request"), not null
#  title                      :string           not null
#  urgency                    :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  affected_service_id        :bigint
#  assignee_id                :bigint
#  case_type_id               :bigint
#  category_id                :bigint
#  contact_id                 :bigint           not null
#  contact_tracking_id        :bigint
#  conversation_id            :bigint
#  kb_article_id              :bigint
#  team_id                    :bigint
#
# Indexes
#
#  index_case_tickets_on_account_and_folio            (account_id,folio) UNIQUE WHERE (folio IS NOT NULL)
#  index_case_tickets_on_account_id_and_case_type_id  (account_id,case_type_id)
#  index_case_tickets_on_account_id_and_contact_id    (account_id,contact_id)
#  index_case_tickets_on_account_id_and_sla_status    (account_id,sla_status)
#  index_case_tickets_on_account_id_and_status        (account_id,status)
#  index_case_tickets_on_account_id_and_ticket_kind   (account_id,ticket_kind)
#  index_case_tickets_on_affected_service_id          (affected_service_id)
#  index_case_tickets_on_category_id                  (category_id)
#  index_case_tickets_on_kb_article_id                (kb_article_id)
#  index_case_tickets_on_metadata                     (metadata) USING gin
#

class CaseTicket < ApplicationRecord
  # @tickets_cases 2A: state machine ITIL ampliado a 13 estados.
  # 'open' se etiqueta "Nuevo" en la UI; los valores enteros 0–8 no cambian, 9–12 son nuevos.
  VALID_TRANSITIONS = {
    'open'                   => %w[classified cancelled],
    'classified'             => %w[assigned cancelled],
    'assigned'               => %w[in_diagnosis in_progress cancelled],
    'in_diagnosis'           => %w[in_progress waiting_on_customer waiting_on_third_party waiting_on_internal escalated cancelled],
    'in_progress'            => %w[waiting_on_customer waiting_on_third_party waiting_on_internal escalated resolved cancelled],
    'waiting_on_customer'    => %w[in_progress cancelled],
    'waiting_on_third_party' => %w[in_progress cancelled],
    'waiting_on_internal'    => %w[in_progress cancelled],
    'escalated'              => %w[in_progress in_diagnosis cancelled],
    'resolved'               => %w[validating closed in_progress],
    'validating'             => %w[closed in_progress cancelled],
    'closed'                 => [],
    'cancelled'              => []
  }.freeze

  SLA_BY_PRIORITY = {
    'low'    => { first_response_time_target: 2880, resolution_time_target: 7200 },
    'medium' => { first_response_time_target: 480,  resolution_time_target: 2880 },
    'high'   => { first_response_time_target: 120,  resolution_time_target: 480  },
    'urgent' => { first_response_time_target: 30,   resolution_time_target: 120  }
  }.freeze

  # @tickets_cases 2D — escalation_level: 0 = N1, 1 = N2, 2 = N3.
  MAX_ESCALATION_LEVEL = 2

  # @tickets_cases 2I — estados en los que el reloj de SLA se pausa.
  WAITING_STATUSES = %w[waiting_on_customer waiting_on_third_party waiting_on_internal].freeze

  # @tickets_cases 2F — campos específicos por naturaleza ITIL, persistidos en custom_attributes.
  PROBLEM_FIELDS = %w[workaround root_cause].freeze
  # approval_status se controla solo vía set_change_approval! (auditado), no por update libre.
  CHANGE_FIELDS  = %w[risk_level requires_approval rollback_plan scheduled_window].freeze
  CHANGE_APPROVAL_STATUSES = %w[pending approved rejected].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :conversation,      optional: true
  belongs_to :contact_tracking,  optional: true
  belongs_to :assignee,          class_name: 'User', optional: true
  belongs_to :team,              optional: true
  belongs_to :case_type,         optional: true # @tickets_cases: tipo configurable por cuenta
  belongs_to :affected_service,  class_name: 'CaseService',  optional: true # @tickets_cases 2B
  belongs_to :category,          class_name: 'CaseCategory', optional: true # @tickets_cases 2B
  belongs_to :kb_article,        class_name: 'Article', optional: true # @tickets_cases 2H
  has_many   :case_events,       dependent: :destroy
  # @tickets_cases 2E — relaciones dirigidas (este ticket como origen y como destino).
  has_many   :ticket_relations,        class_name: 'CaseTicketRelation', foreign_key: :ticket_id,         dependent: :destroy, inverse_of: :ticket
  has_many   :inverse_ticket_relations, class_name: 'CaseTicketRelation', foreign_key: :related_ticket_id, dependent: :destroy, inverse_of: :related_ticket

  enum origin:       { whatsapp: 0, web: 1, email: 2, bot: 3, manual: 4 }
  enum priority:     { low: 0, medium: 1, high: 2, urgent: 3 }
  enum status:       { open: 0, classified: 1, in_progress: 2, waiting_on_customer: 3,
                       waiting_on_internal: 4, escalated: 5, resolved: 6, closed: 7, cancelled: 8,
                       assigned: 9, in_diagnosis: 10, waiting_on_third_party: 11, validating: 12 }
  enum assignee_type: { bot: 0, agent: 1, team: 2, system: 3 }, _prefix: :assignee
  enum sla_status:   { on_time: 0, at_risk: 1, overdue: 2 }
  # @tickets_cases 2B — clasificación ITIL del ticket (eje distinto al case_type/área).
  enum ticket_kind:  { incident: 0, service_request: 1, problem: 2, change: 3, query: 4 }, _prefix: :kind
  # impact/urgency comparten valores low/medium/high con priority → prefijo obligatorio.
  enum impact:       { low: 0, medium: 1, high: 2 }, _prefix: :impact
  enum urgency:      { low: 0, medium: 1, high: 2 }, _prefix: :urgency
  # @tickets_cases 2G — tipo de cierre documentado. Prefijo obligatorio: resolved/cancelled
  # colisionan con los valores del enum status.
  enum closure_type: { resolved: 0, duplicate: 1, not_applicable: 2, cancelled: 3 }, _prefix: :closure

  validates :title,         presence: true, length: { maximum: 255 }
  validates :origin,        presence: true
  validates :priority,      presence: true
  validates :status,        presence: true
  validates :assignee_type, presence: true
  validates :sla_status,    presence: true

  before_validation :derive_priority_from_matrix # @tickets_cases 2B
  before_create :assign_sla_targets
  before_create :assign_folio # @tickets_cases
  after_create  :create_ticket_created_event

  def can_transition_to?(new_status)
    VALID_TRANSITIONS[status].include?(new_status.to_s)
  end

  def transition!(new_status, actor: nil, reason: nil, closure: nil)
    raise "Transición inválida: #{status} → #{new_status}" unless can_transition_to?(new_status)
    # @tickets_cases 2F — un cambio que requiere aprobación no puede ejecutarse sin aprobarse.
    if blocked_by_change_approval?(new_status)
      raise 'El cambio requiere aprobación antes de pasar a ejecución'
    end

    closing    = new_status.to_s == 'closed'
    closure    = validate_closure!(closure) if closing # @tickets_cases 2G

    old_status  = status
    attrs       = { status: new_status }
    attrs[:resolved_at] = Time.current if new_status.to_s == 'resolved'
    if closing
      attrs[:closed_at]          = Time.current
      attrs[:closure_type]       = closure['closure_type']
      attrs[:closure_cause]      = closure['closure_cause']
      attrs[:closure_solution]   = closure['closure_solution']
      attrs[:customer_confirmed] = ActiveModel::Type::Boolean.new.cast(closure['customer_confirmed']) || false
    end
    attrs.merge!(sla_pause_attrs(old_status, new_status)) # @tickets_cases 2I

    update!(attrs)

    payload = { from: old_status, to: new_status.to_s, reason: reason }
    payload[:closure_type] = closure['closure_type'] if closing
    case_events.create!(
      account:    account,
      event_type: event_type_for_transition(old_status, new_status),
      origin:     actor ? :agent : :system,
      actor:      actor,
      payload:    payload.compact
    )
  end

  # @tickets_cases 2D — Escalamiento funcional: sube el nivel (N1→N2→N3), reasigna a
  # equipo/agente y, si la transición es válida, marca el estado "escalado".
  # Un único evento :escalated en el timeline captura nivel + estado + reasignación.
  def escalate!(actor: nil, reason: nil, team: nil, assignee: nil)
    raise 'Ticket cerrado: no se puede escalar' if closed? || cancelled?
    raise 'Nivel máximo de escalamiento alcanzado' if escalation_level >= MAX_ESCALATION_LEVEL

    old_level  = escalation_level
    old_status = status
    attrs = { escalation_level: escalation_level + 1 }
    if assignee
      attrs[:assignee] = assignee
      attrs[:assignee_type] = :agent
    elsif team
      attrs[:team] = team
      attrs[:assignee_type] = :team
    end
    changes_status = can_transition_to?(:escalated)
    attrs[:status] = :escalated if changes_status

    update!(attrs)

    case_events.create!(
      account:    account,
      event_type: :escalated,
      origin:     actor ? :agent : :system,
      actor:      actor,
      payload: {
        from_level: old_level, to_level: escalation_level,
        from: (old_status if changes_status), to: ('escalated' if changes_status),
        reason: reason, team: team&.name, assignee: assignee&.name
      }.compact
    )
    self
  end

  # ── @tickets_cases 2F — Problema y Cambio ──────────────────────────────────

  # Cambio que aún no puede ejecutarse por estar pendiente de aprobación.
  def blocked_by_change_approval?(new_status)
    kind_change? && requires_approval? && !change_approved? && new_status.to_s == 'in_progress'
  end

  def requires_approval?
    ActiveModel::Type::Boolean.new.cast(custom_attributes['requires_approval'])
  end

  def change_approval_status
    custom_attributes['approval_status'].presence || 'pending'
  end

  def change_approved?
    change_approval_status == 'approved'
  end

  # Registra la decisión de aprobación de un cambio (auditada en el timeline).
  def set_change_approval!(status, actor: nil, reason: nil)
    raise 'La aprobación solo aplica a cambios' unless kind_change?
    raise "Estado de aprobación inválido: #{status}" unless %w[approved rejected].include?(status.to_s)

    self.custom_attributes = custom_attributes.merge('approval_status' => status.to_s)
    save!

    case_events.create!(
      account:    account,
      event_type: status.to_s == 'approved' ? :change_approved : :change_rejected,
      origin:     actor ? :agent : :system,
      actor:      actor,
      payload:    { reason: reason }.compact
    )
    self
  end

  # Incidentes vinculados a este problema (relación incident_problem: incidente → problema).
  def related_incidents
    incident_ids = CaseTicketRelation
                   .where(related_ticket_id: id, relation_type: :incident_problem)
                   .pluck(:ticket_id)
    account.case_tickets.where(id: incident_ids)
  end

  # @tickets_cases 2F — al resolver un problema, propaga la resolución a sus incidentes.
  # Resuelve cada incidente que admita la transición y deja rastro en ambos timelines.
  def propagate_resolution_to_incidents!(actor: nil)
    resolved = []
    related_incidents.find_each do |incident|
      next unless incident.can_transition_to?(:resolved)

      incident.transition!(:resolved, actor: actor, reason: "Resuelto por el problema #{folio}")
      resolved << (incident.folio || "##{incident.id}")
    end

    if resolved.any?
      case_events.create!(
        account:    account,
        event_type: :problem_propagated,
        origin:     actor ? :agent : :system,
        actor:      actor,
        payload:    { incidents: resolved, count: resolved.size }
      )
    end
    resolved
  end

  # @tickets_cases 2I — política SLA resuelta (más específica) para este ticket, o nil.
  def sla_policy
    return @sla_policy if defined?(@sla_policy)

    @sla_policy = CaseSlaPolicy.resolve_for(self)
  end

  def calculate_sla_status
    return :on_time if resolved? || closed? || cancelled?

    target = first_response_at.nil? ? first_response_time_target : resolution_time_target
    return :on_time if target.nil?

    # @tickets_cases 2I — minutos efectivos: descuenta pausa y horas no laborables.
    elapsed = Cases::SlaClockService.elapsed_minutes(self, sla_policy)

    ratio = elapsed.to_f / target
    return :overdue if ratio >= 1.0
    return :at_risk  if ratio >= 0.8

    :on_time
  end

  private

  # @tickets_cases 2I — gestiona la pausa del SLA al entrar/salir de estados de espera.
  def sla_pause_attrs(old_status, new_status)
    entering = WAITING_STATUSES.include?(new_status.to_s) && WAITING_STATUSES.exclude?(old_status.to_s)
    leaving  = WAITING_STATUSES.include?(old_status.to_s) && WAITING_STATUSES.exclude?(new_status.to_s)

    if entering
      { sla_paused_since: Time.current }
    elsif leaving && sla_paused_since.present?
      paused = Cases::SlaClockService.minutes_between(
        self, sla_paused_since, Time.current, business: sla_policy&.business_hours_only
      )
      { sla_paused_minutes: sla_paused_minutes + paused, sla_paused_since: nil }
    else
      {}
    end
  end

  # @tickets_cases 2G — un ticket no puede cerrarse sin documentar tipo, causa y solución.
  # Normaliza las claves a string y valida los campos obligatorios. Devuelve el hash limpio.
  def validate_closure!(closure)
    data = (closure || {}).stringify_keys
    missing = []
    missing << 'tipo de cierre' if data['closure_type'].blank?
    missing << 'causa'          if data['closure_cause'].blank?
    missing << 'solución'       if data['closure_solution'].blank?
    raise "Para cerrar el ticket debes documentar: #{missing.join(', ')}" if missing.any?

    unless CaseTicket.closure_types.key?(data['closure_type'].to_s)
      raise "Tipo de cierre inválido: #{data['closure_type']}"
    end

    data
  end

  # @tickets_cases 2B — si hay impacto y urgencia, la prioridad se deriva de la matriz ITIL.
  # Si no, se respeta la prioridad fijada manualmente (comportamiento original).
  def derive_priority_from_matrix
    derived = Cases::PriorityMatrix.derive(impact, urgency)
    self.priority = derived if derived.present?
  end

  # @tickets_cases 2I — usa la política SLA configurada (más específica) y, si no hay,
  # cae al hash SLA_BY_PRIORITY. No pisa targets ya fijados manualmente.
  def assign_sla_targets
    policy = CaseSlaPolicy.resolve_for(self)
    fr = policy&.first_response_time_target
    rt = policy&.resolution_time_target

    if policy.nil?
      sla = SLA_BY_PRIORITY[priority.to_s]
      fr  = sla&.dig(:first_response_time_target)
      rt  = sla&.dig(:resolution_time_target)
    end

    self.first_response_time_target ||= fr
    self.resolution_time_target     ||= rt
  end

  # @tickets_cases: genera el folio según la plantilla de la cuenta (inmutable).
  def assign_folio
    return if folio.present?

    self.folio = Cases::FolioGeneratorService.new(self).generate
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] folio error: #{e.message}")
  end

  def create_ticket_created_event
    case_events.create!(
      account:    account,
      event_type: :ticket_created,
      origin:     :system,
      payload:    { case_type: case_type&.name, priority: priority, origin: origin }
    )
  end

  def event_type_for_transition(old_status, new_status)
    case new_status.to_s
    when 'assigned'     then :assigned
    when 'in_diagnosis' then :in_diagnosis
    when 'escalated'    then :escalated
    when 'resolved'     then :resolved
    when 'validating'   then :validating
    when 'closed'       then :closed
    when 'in_progress'  then %w[resolved validating].include?(old_status.to_s) ? :reopened : :status_changed
    else :status_changed
    end
  end
end
