# frozen_string_literal: true

# == Schema Information
#
# Table name: case_tickets
#
#  id                         :bigint           not null, primary key
#  actual_hours               :decimal(6, 2)
#  amount                     :decimal(14, 2)
#  assignee_type              :integer          default("bot"), not null
#  billable                   :boolean          default(FALSE), not null
#  budget_amount              :decimal(14, 2)
#  budget_hours               :decimal(8, 2)
#  closed_at                  :datetime
#  closure_cause              :text
#  closure_solution           :text
#  closure_type               :integer
#  commit_note                :text
#  committed_at               :datetime
#  conformity_note            :text
#  conformity_signature       :text
#  csat_at                    :datetime
#  csat_comment               :text
#  csat_rating                :integer
#  currency                   :string(3)
#  custom_attributes          :jsonb            not null
#  customer_confirmed         :boolean          default(FALSE), not null
#  description                :text
#  due_at                     :datetime
#  escalation_level           :integer          default(0), not null
#  estimated_hours            :decimal(6, 2)
#  expected_close_at          :date
#  external_technician        :jsonb            not null
#  external_token             :string
#  external_token_expires_at  :datetime
#  first_response_at          :datetime
#  first_response_time_target :integer
#  folio                      :string
#  impact                     :integer
#  locked_at                  :datetime
#  metadata                   :jsonb            not null
#  on_site                    :boolean
#  origin                     :integer          default("whatsapp"), not null
#  outcome                    :integer
#  outcome_at                 :datetime
#  outcome_note               :text
#  postponed_until            :date
#  priority                   :integer          default("medium"), not null
#  probability                :integer
#  progress                   :integer
#  project_due_on             :date
#  project_start_on           :date
#  received_at                :datetime
#  received_by                :string
#  reopen_count               :integer          default(0), not null
#  reopened_at                :datetime
#  report_sent_at             :datetime
#  report_token               :string
#  resolution_time_target     :integer
#  resolved_at                :datetime
#  sla_paused_minutes         :integer          default(0), not null
#  sla_paused_since           :datetime
#  sla_status                 :integer          default("on_time"), not null
#  status                     :integer          default("open"), not null
#  ticket_kind                :integer          default("service_request"), not null
#  title                      :string           not null
#  urgency                    :integer
#  visit_response             :jsonb            not null
#  work_address               :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  affected_service_id        :bigint
#  assignee_id                :bigint
#  case_type_column_id        :bigint
#  case_type_id               :bigint
#  category_id                :bigint
#  contact_id                 :bigint
#  contact_tracking_id        :bigint
#  conversation_id            :bigint
#  customer_asset_id          :bigint
#  kb_article_id              :bigint
#  locked_by_id               :bigint
#  maintenance_plan_id        :bigint
#  outcome_reason_id          :bigint
#  postpone_reason_id         :bigint
#  requester_id               :bigint
#  team_id                    :bigint
#
# Indexes
#
#  index_case_tickets_on_account_and_folio            (account_id,folio) UNIQUE WHERE (folio IS NOT NULL)
#  index_case_tickets_on_account_committed            (account_id,committed_at) WHERE (committed_at IS NOT NULL)
#  index_case_tickets_on_account_id_and_case_type_id  (account_id,case_type_id)
#  index_case_tickets_on_account_id_and_contact_id    (account_id,contact_id)
#  index_case_tickets_on_account_id_and_due_at        (account_id,due_at)
#  index_case_tickets_on_account_id_and_outcome       (account_id,outcome)
#  index_case_tickets_on_account_id_and_sla_status    (account_id,sla_status)
#  index_case_tickets_on_account_id_and_status        (account_id,status)
#  index_case_tickets_on_account_id_and_ticket_kind   (account_id,ticket_kind)
#  index_case_tickets_on_affected_service_id          (affected_service_id)
#  index_case_tickets_on_case_type_column_id          (case_type_column_id)
#  index_case_tickets_on_category_id                  (category_id)
#  index_case_tickets_on_contact_id                   (contact_id)
#  index_case_tickets_on_contact_tracking_id          (contact_tracking_id)
#  index_case_tickets_on_conversation_id              (conversation_id)
#  index_case_tickets_on_customer_asset_id            (customer_asset_id)
#  index_case_tickets_on_external_token               (external_token) UNIQUE
#  index_case_tickets_on_kb_article_id                (kb_article_id)
#  index_case_tickets_on_locked_by_id                 (locked_by_id)
#  index_case_tickets_on_maintenance_plan_id          (maintenance_plan_id)
#  index_case_tickets_on_metadata                     (metadata) USING gin
#  index_case_tickets_on_postponed_until              (postponed_until) WHERE (postponed_until IS NOT NULL)
#  index_case_tickets_on_project_due_on               (project_due_on) WHERE (project_due_on IS NOT NULL)
#  index_case_tickets_on_report_token                 (report_token) UNIQUE
#  index_case_tickets_on_requester_id                 (requester_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_type_column_id => case_type_columns.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (contact_tracking_id => contact_trackings.id) ON DELETE => nullify
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => nullify
#  fk_rails_...  (customer_asset_id => customer_assets.id) ON DELETE => nullify
#  fk_rails_...  (locked_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (maintenance_plan_id => maintenance_plans.id) ON DELETE => nullify
#  fk_rails_...  (outcome_reason_id => case_outcome_reasons.id) ON DELETE => nullify
#  fk_rails_...  (postpone_reason_id => case_outcome_reasons.id) ON DELETE => nullify
#  fk_rails_...  (requester_id => users.id) ON DELETE => nullify
#

class CaseTicket < ApplicationRecord
  include ServiceReportable # Plan-Trabajo-Campo R1 — reporte de servicio de la orden
  include FieldPortal # Plan-Trabajo-Campo R5 — portal del cliente y técnico externo
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
    # @tickets_cases — cerrado solo puede REABRIRSE (a in_progress). No se salta
    # a resolved ni a ningún otro estado: reabrir es volver a trabajarlo.
    'closed'                 => %w[in_progress],
    'cancelled'              => []
  }.freeze

  # @tickets_cases — agrupación "pendiente vs cerrado" para el filtro de estado
  # de la lista de casos. "Cerrado" incluye resuelto/validando aunque el status
  # literal no sea `closed`: para el negocio, un caso resuelto ya no es trabajo
  # activo aunque técnicamente pueda reabrirse o cambiar de estado después.
  PENDING_STATUSES = %w[
    open classified assigned in_diagnosis in_progress escalated
    waiting_on_customer waiting_on_third_party waiting_on_internal
  ].freeze
  CLOSED_STATUSES = %w[resolved validating closed cancelled].freeze

  # @tickets_cases — Plan-Clase-Comercial F3: una oportunidad no se resuelve ni se
  # cancela como un ticket; termina en `closed` con un resultado (won/lost/cancelled).
  COMMERCIAL_BLOCKED_STATUSES = %w[resolved validating cancelled].freeze
  COMMERCIAL_STATUS_MSG = 'Una oportunidad se cierra con un resultado: ganada, perdida o cancelada'
  # Datos de la oportunidad editables desde la ficha y el alta. `committed` es la
  # casilla «Comprometida por el cliente» (escribe `committed_at`, ver #committed=).
  COMMERCIAL_FIELDS = %w[amount currency expected_close_at probability committed commit_note].freeze
  # Columnas que cambian al guardar esos datos (lo que se registra en el historial).
  COMMERCIAL_COLUMNS = %w[amount currency expected_close_at probability committed_at commit_note].freeze
  COMMITMENT_COLUMNS = %w[committed_at commit_note].freeze
  COMMITMENT_DATE_MSG = 'es obligatoria si el cliente se comprometió (es la fecha que prometió)'
  # Plan-Clase-Orden-de-Trabajo F2a — datos de la orden que se editan (la conformidad
  # —received_by/received_at/conformity_note— solo se llena al cerrar).
  WORK_ORDER_FIELDS = %w[work_address estimated_hours actual_hours billable].freeze
  # Plan-Clase-Proyecto P1 — datos del proyecto que se editan (el monto va en `currency`).
  PROJECT_FIELDS = %w[project_start_on project_due_on budget_hours budget_amount progress].freeze

  SLA_BY_PRIORITY = {
    'low'    => { first_response_time_target: 2880, resolution_time_target: 7200 },
    'medium' => { first_response_time_target: 480,  resolution_time_target: 2880 },
    'high'   => { first_response_time_target: 120,  resolution_time_target: 480  },
    'urgent' => { first_response_time_target: 30,   resolution_time_target: 120  }
  }.freeze

  # @tickets_cases 2D — escalation_level: 0 = N1, 1 = N2, 2 = N3.
  MAX_ESCALATION_LEVEL = 2

  # @tickets_cases — el bloqueo de ticket expira solo tras este tiempo de inactividad.
  LOCK_TTL = 3.minutes

  # ¿Hay un bloqueo vigente (no expirado)?
  def lock_active?
    locked_by_id.present? && locked_at.present? && locked_at > LOCK_TTL.ago
  end

  # ¿Lo tiene bloqueado OTRO agente (no este)?
  def locked_by_other?(user)
    lock_active? && locked_by_id != user&.id
  end

  # @tickets_cases 2I — estados en los que el reloj de SLA se pausa.
  WAITING_STATUSES = %w[waiting_on_customer waiting_on_third_party waiting_on_internal].freeze

  # @tickets_cases 2F — campos específicos por naturaleza ITIL, persistidos en custom_attributes.
  PROBLEM_FIELDS = %w[workaround root_cause].freeze
  # approval_status se controla solo vía set_change_approval! (auditado), no por update libre.
  CHANGE_FIELDS  = %w[risk_level requires_approval rollback_plan scheduled_window].freeze
  CHANGE_APPROVAL_STATUSES = %w[pending approved rejected].freeze

  belongs_to :account
  belongs_to :contact,           optional: true # @tickets_cases Fase C — nil en tickets internos
  # Plan-Catalogo-Cotizaciones — cotizaciones de la oportunidad y las que salieron del caso.
  has_many :quotes, foreign_key: :opportunity_id, dependent: :nullify, inverse_of: :opportunity
  has_many :origin_quotes, class_name: 'Quote', foreign_key: :origin_ticket_id, dependent: :nullify,
                           inverse_of: :origin_ticket
  belongs_to :requester,         class_name: 'User', optional: true # @tickets_cases Fase C — agente solicitante (interno)
  belongs_to :conversation,      optional: true
  belongs_to :contact_tracking,  optional: true
  belongs_to :assignee,          class_name: 'User', optional: true
  belongs_to :locked_by,         class_name: 'User', optional: true # @tickets_cases — bloqueo de ticket
  belongs_to :team,              optional: true
  belongs_to :case_type,         optional: true # @tickets_cases: tipo configurable por cuenta
  belongs_to :case_type_column,  optional: true # @tickets_cases — sub-estado (columna del Kanban por tipo)
  # proyecto@solicitudes (pieza 5, F4): un servicio movido a la columna «Pagado» queda en firme.
  after_update_commit -> { ContactTrackings::ServicePaidJob.perform_later(id) if metadata&.key?('servicio') },
                      if: :saved_change_to_case_type_column_id?
  belongs_to :affected_service,  class_name: 'CaseService',  optional: true # @tickets_cases 2B
  belongs_to :category,          class_name: 'CaseCategory', optional: true # @tickets_cases 2B
  belongs_to :kb_article,        class_name: 'Article', optional: true # @tickets_cases 2H
  belongs_to :outcome_reason,    class_name: 'CaseOutcomeReason', optional: true # Plan-Clase-Comercial F3
  belongs_to :postpone_reason,   class_name: 'CaseOutcomeReason', optional: true # motivo de la pospuesta vigente
  has_many   :case_events,       dependent: :destroy
  has_many   :case_tasks,        dependent: :destroy # @tickets_cases — tareas/subtareas
  has_many   :work_order_items,  class_name: 'CaseWorkOrderItem', dependent: :destroy # materiales de la orden
  # @tickets_cases F0 — reuniones del ticket y sus series (docs/tickets_reuniones_plan.md).
  has_many   :case_meetings,     dependent: :destroy
  has_many   :case_meeting_series, class_name: 'CaseMeetingSeries', dependent: :destroy, inverse_of: :case_ticket
  # @tickets_cases 2E — relaciones dirigidas (este ticket como origen y como destino).
  has_many   :ticket_relations,        class_name: 'CaseTicketRelation', foreign_key: :ticket_id,         dependent: :destroy, inverse_of: :ticket
  has_many   :inverse_ticket_relations, class_name: 'CaseTicketRelation', foreign_key: :related_ticket_id, dependent: :destroy, inverse_of: :related_ticket

  # @tickets_cases Fase C — `internal` (5) al final: ticket agente→agente sin cliente.
  enum origin:       { whatsapp: 0, web: 1, email: 2, bot: 3, manual: 4, internal: 5 }
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
  # @tickets_cases — Plan-Clase-Comercial F3: resultado de una oportunidad, separado de
  # `status` (las tres quedan en `closed`). Valores nuevos SIEMPRE al final (Trampa 17).
  enum outcome:      { won: 0, lost: 1, cancelled: 2 }, _prefix: :outcome

  validates :title,         presence: true, length: { maximum: 255 }
  validates :origin,        presence: true
  validates :priority,      presence: true
  validates :status,        presence: true
  validates :assignee_type, presence: true
  validates :sla_status,    presence: true
  # @tickets_cases Fase C — externo lleva contacto; interno lleva solicitante.
  # Solo en creación: si más tarde se borra el contacto (contact_id → NULL por
  # dependent: :nullify), el ticket histórico debe seguir siendo editable/cerrable.
  validate :contact_or_requester_present, on: :create
  # Un tipo retirado (cambió de clase) conserva sus casos, pero no recibe nuevos.
  validate :case_type_not_retired, if: -> { case_type_id.present? && (new_record? || will_save_change_to_case_type_id?) }
  # Plan-Casos E2 — una oportunidad siempre es de un cliente (no hay oportunidad interna).
  validate :commercial_needs_contact, on: :create
  # Hoja de ruta E1.4 — un caso no cambia de clase al cambiar de tipo (el folio es
  # inmutable y las series se mezclarían). Sin tipo cuenta como Soporte.
  validate :case_class_unchanged, on: :update, if: :will_save_change_to_case_type_id?
  # @tickets_cases — Plan-Clase-Comercial F2: servicio/categoría deben ser globales
  # o del tipo del caso. Al crear, o si el TIPO cambia (modal, automatización, IA,
  # @solicitudes), la clasificación ajena se limpia sola en vez de bloquear el guardado.
  before_validation :drop_classification_of_other_type, if: -> { new_record? || will_save_change_to_case_type_id? }
  validate :classification_matches_type
  # @tickets_cases — Plan-Clase-Comercial F3: datos de la oportunidad.
  validates :probability, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :amount,      numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency,    format: { with: /\A[A-Z]{3}\z/ }, allow_nil: true
  # Plan-Metricas-Comercial — comprometida: la fecha de cierre pasa a ser la que
  # prometió el cliente, así que no puede quedar vacía.
  validate  :commitment_has_date
  validates :commit_note, length: { maximum: 500 }, allow_blank: true
  validates :estimated_hours, :actual_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :work_address, length: { maximum: 255 }, allow_blank: true
  validates :budget_hours, :budget_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :progress, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validate  :project_due_after_start
  before_validation -> { self.work_address = work_address.to_s.strip.presence }, if: :will_save_change_to_work_address?
  before_validation :normalize_commercial_data
  # Responsable fijo del contacto: un caso nuevo sin responsable elegido es suyo.
  before_validation :assign_contact_owner, on: :create

  # @tickets_cases Fase C — tickets internos (origin: internal, sin contacto).
  scope :internal, -> { where(origin: :internal) }
  # @tickets_cases — Plan-Clase-Comercial: casos de la clase Comercial y el resto
  # (un caso sin tipo cuenta como Soporte). Subconsulta y no JOIN, a propósito: un
  # JOIN con case_types vuelve ambiguo cualquier SQL suelto que diga `created_at`
  # (las métricas del módulo tienen varios).
  scope :commercial, -> { where(case_type_id: CaseType.class_commercial.select(:id)) }
  scope :non_commercial, -> { where(case_type_id: nil).or(where.not(case_type_id: CaseType.class_commercial.select(:id))) }
  # Plan-Clase-Orden-de-Trabajo F1 — casos cuya clase tiene la capacidad (ver
  # CaseType::CLASS_CAPABILITIES); sin tipo cuenta como Soporte.
  scope :with_capability, lambda { |capability|
    classes = CaseType.classes_with(capability)
    ids = CaseType.where(case_class: classes).select(:id)
    classes.include?('support') ? where(case_type_id: nil).or(where(case_type_id: ids)) : where(case_type_id: ids)
  }
  scope :of_class, lambda { |name|
    ids = CaseType.where(case_class: CaseType.case_classes.fetch(name.to_s)).select(:id)
    name.to_s == 'support' ? where(case_type_id: nil).or(where(case_type_id: ids)) : where(case_type_id: ids)
  }

  # @tickets_cases — cuando una prioridad viene FORZADA (directiva @crear_ticket
  # o ajuste por riesgo del intake IA), no dejar que la matriz ITIL la pise
  # aunque haya impacto+urgencia. No persiste; es una bandera del alta.
  attr_accessor :skip_priority_derivation

  before_validation :derive_priority_from_matrix # @tickets_cases 2B
  # @tickets_cases — mantiene el invariante columna⊆estado: si el status o el tipo
  # cambian por FUERA del tablero (detalle, reglas, SLA, API, IA, portal), el
  # puntero de columna se limpia y el ticket cae al fallback por status. Un solo
  # hook en el modelo cubre las seis vías; ver §7 del Plan-Columnas-Por-Tipo.
  before_save :resync_type_column, if: -> { will_save_change_to_status? || will_save_change_to_case_type_id? }
  # Plan-Clase-Comercial F3 — al entrar a una columna del embudo, la oportunidad toma
  # su probabilidad. Va DESPUÉS del resync: si el puntero se limpió, no hay columna.
  before_save :sync_probability_from_column,
              if: -> { will_save_change_to_case_type_column_id? && case_type_column_id.present? && commercial? }
  before_create :assign_sla_targets
  before_create :assign_folio # @tickets_cases
  after_create  :create_ticket_created_event
  # Plan-Plantilla-Tareas-Etapa T2 — al entrar a una etapa nacen las tareas de su
  # plantilla (al crear el caso, al moverlo en el tablero o al cambiar su estado).
  after_commit :create_stage_tasks, on: %i[create update],
                                    if: lambda {
                                      saved_change_to_id? || saved_change_to_case_type_column_id? ||
                                        saved_change_to_status? || saved_change_to_case_type_id?
                                    }

  # Embudo de contactos — un caso que nace en (o se liga a) una conversación mueve
  # su tarjeta a la columna «caso creado» del tablero de esa conversación.
  after_commit :advance_contact_funnel, on: %i[create update],
                                        if: -> { conversation_id.present? && saved_change_to_conversation_id? }

  # Etapa en la que está el caso: su columna, o la primera del tipo que cubre su
  # estado (el mismo criterio con el que el tablero pinta un caso sin columna).
  def current_stage_column
    return nil if case_type.nil?

    columns = case_type.case_type_columns.ordered.to_a
    columns.detect { |c| c.id == case_type_column_id } || columns.detect { |c| c.statuses.include?(status) }
  end

  def can_transition_to?(new_status)
    VALID_TRANSITIONS[status].include?(new_status.to_s)
  end

  # @tickets_cases Fase A — payload para notificaciones nativas (bell/ActionCable).
  # Notification#push_event_data invoca esto sobre el primary_actor.
  # `meta.assignee` es obligatorio: el frontend (NotificationTable) lo lee sin
  # optional-chaining → si falta `meta`, rompe el render de toda la lista.
  def push_event_data
    {
      id:     id,
      folio:  folio,
      title:  title,
      status: status,
      # @tickets_cases — sin esto un ticket movido por otro agente llega por
      # websocket sin puntero y salta a la columna equivocada hasta el refresh.
      case_type_column_id: case_type_column_id,
      meta:   { assignee: assignee&.push_event_data }
    }
  end

  # `force: true` — usado por el movimiento libre entre columnas personalizadas
  # (Cases::TicketMove / case_tickets_controller#move_across_state): salta la
  # validación de "un salto" de VALID_TRANSITIONS porque el orden de columnas que
  # configuró el admin es el flujo real, no la espina ITIL fija. Todo lo demás
  # (documentar cierre, timestamps, pausa de SLA, evento) sigue aplicando igual.
  def transition!(new_status, actor: nil, reason: nil, closure: nil, force: false)
    raise "Transición inválida: #{status} → #{new_status}" unless force || can_transition_to?(new_status)
    # @tickets_cases 2F — un cambio que requiere aprobación no puede ejecutarse sin aprobarse.
    if blocked_by_change_approval?(new_status)
      raise 'El cambio requiere aprobación antes de pasar a ejecución'
    end

    # @tickets_cases — Plan-Clase-Comercial F3: una oportunidad solo cierra con resultado.
    raise COMMERCIAL_STATUS_MSG if commercial? && COMMERCIAL_BLOCKED_STATUSES.include?(new_status.to_s)

    closing    = new_status.to_s == 'closed'
    closure    = validate_closure!(closure) if closing # @tickets_cases 2G
    ensure_service_report_complete!(status, new_status) # Plan-Trabajo-Campo R1

    old_status  = status
    old_outcome = outcome
    attrs       = { status: new_status }
    attrs[:resolved_at] = Time.current if new_status.to_s == 'resolved'
    attrs.merge!(closing_attrs(closure)) if closing
    attrs.merge!(sla_pause_attrs(old_status, new_status)) # @tickets_cases 2I
    attrs.merge!(commercial_exit_attrs(old_status, new_status))

    update!(attrs)

    payload = { from: old_status, to: new_status.to_s, reason: reason }
    payload.merge!(closure_payload(closure)) if closing
    # Reabrir una oportunidad borra su resultado; el evento conserva cuál era.
    payload[:previous_outcome] = old_outcome if old_outcome.present? && outcome.nil?
    case_events.create!(
      account:    account,
      event_type: event_type_for_transition(old_status, new_status),
      origin:     actor ? :agent : :system,
      actor:      actor,
      payload:    payload.compact
    )
    deliver_report_after_completion(old_status, new_status) # Plan-Trabajo-Campo R1
  end

  # @tickets_cases — Reapertura de un ticket cerrado (osTicket "Reopen").
  # El motivo es OBLIGATORIO: reabrir es revertir una decisión y tiene que
  # quedar por qué. `transition!` ya guarda el motivo en payload[:reason] y el
  # Recorrido lo pinta como "Motivo", así que aquí solo se valida y se limpian
  # los rastros del cierre.
  #
  # El SLA arranca de cero: reanudar el reloj viejo haría nacer el ticket
  # vencido y ensuciaría el cumplimiento del período.
  def reopen!(actor: nil, reason: nil)
    raise 'Solo se puede reabrir un ticket cerrado' unless closed?
    raise 'El motivo de reapertura es obligatorio' if reason.blank?

    update!(
      closed_at:          nil,
      closure_type:       nil,
      closure_cause:      nil,
      closure_solution:   nil,
      customer_confirmed: false,
      resolved_at:        nil,
      # Orden de trabajo: la conformidad era del trabajo anterior (las horas se quedan).
      received_by:        nil,
      received_at:        nil,
      conformity_note:    nil,
      reopened_at:        Time.current,
      reopen_count:       reopen_count + 1,
      sla_status:         :on_time,
      sla_paused_minutes: 0,
      sla_paused_since:   nil,
      first_response_at:  nil
    )

    # Deja el evento `reopened` (el enum ya lo reservaba desde el diseño).
    transition!('in_progress', actor: actor, reason: reason)
  end

  # @tickets_cases — Un ticket cerrado o cancelado se congela: no se le cambian
  # prioridad, vencimiento, tipo ni asignación. Las notas internas SÍ se
  # permiten siempre (son bitácora, no edición) y por eso no pasan por aquí.
  def frozen_for_edit?
    closed? || cancelled?
  end

  # Puede reabrir el admin siempre; el asignado solo dentro de la ventana.
  def reopenable_by?(user)
    return false unless closed?
    return false if user.blank?
    return true if user.administrator?

    assignee_id == user.id && within_reopen_window?
  end

  def within_reopen_window?
    # Plan-Clase-Comercial F3 (hallazgo #2): una oportunidad SIEMPRE se reabre, sin
    # ventana; abrir un caso de seguimiento partiría su historial comercial en dos.
    return true if commercial?

    days = CaseSetting.for_account(account).reopen_window_days.to_i
    return true if days.zero? # 0 = sin límite
    return true if closed_at.blank?

    closed_at >= days.days.ago
  end

  # ── @tickets_cases — Plan-Clase-Comercial F3: oportunidades ─────────────────

  def commercial?
    case_type&.class_commercial? || false
  end

  def work_order?
    case_type&.class_work_order? || false
  end

  def project?
    case_type&.class_project? || false
  end

  # Plan-Clase-Proyecto P2 — casos dentro de un proyecto: órdenes de trabajo y
  # tickets de Soporte (decisión 3), por la relación `project_member`.
  PROJECT_CHILD_CLASSES = %w[work_order support].freeze
  PROGRESS_DONE_STATUSES = %w[resolved validating closed].freeze

  def project_children
    CaseTicket.where(id: CaseTicketRelation.project_member.where(related_ticket_id: id).select(:ticket_id))
  end

  def parent_project
    ticket_relations.project_member.first&.related_ticket
  end

  # Avance automático (decisión 1): % de casos hijos terminados + hitos hechos
  # (los cancelados no cuentan). Sin hijos ni hitos manda el avance a mano.
  def project_progress_summary
    children = project_children.where.not(status: :cancelled).pluck(:status, :case_type_id)
    milestones = case_tasks.where(milestone: true).pluck(:status)
    done = children.count { |status, _| PROGRESS_DONE_STATUSES.include?(status) } + milestones.count('done')
    total = children.size + milestones.size
    {
      progress: total.zero? ? progress : (done * 100.0 / total).round,
      progress_auto: total.positive?,
      children_total: children.size,
      children_done: children.count { |status, _| PROGRESS_DONE_STATUSES.include?(status) },
      milestones_total: milestones.size,
      milestones_done: milestones.count('done'),
      actual_hours: project_children.of_class('work_order').sum(:actual_hours).to_f
    }
  end

  # Plan-Clase-Proyecto P1 — sigue abierto con la fecha objetivo ya pasada.
  def project_overdue?
    project? && project_due_on.present? && project_due_on < Date.current &&
      !CLOSED_STATUSES.include?(status)
  end

  def class_capability?(capability)
    CaseType.class_capability?(case_type&.case_class, capability)
  end

  # Pospuesta = en espera del cliente con fecha para retomarla (cuenta como Pendiente).
  def postponed?
    postponed_until.present? && waiting_on_customer?
  end

  # Cierra la oportunidad como ganada, perdida o cancelada. Pasa por transition!
  # (force: el embudo no sigue la espina ITIL), que valida motivo y deja el evento.
  def close_with_outcome!(result, actor: nil, reason_id: nil, note: nil, accepted_quote_id: nil)
    raise 'Solo las oportunidades se cierran con un resultado' unless commercial?
    raise 'La oportunidad ya está cerrada; reábrela para cambiar su resultado' if closed? || cancelled?

    closed = transition!('closed', actor: actor, force: true,
                                   closure: { 'outcome' => result.to_s, 'outcome_reason_id' => reason_id, 'outcome_note' => note })
    # Plan-Catalogo-Cotizaciones — sus cotizaciones vivas siguen el resultado.
    Quotes::OpportunitySync.from_opportunity(self, result, actor: actor, accepted_quote_id: accepted_quote_id)
    closed
  end

  # Deja la oportunidad en espera hasta `until_date`; Cases::ResumePostponedJob la
  # retoma ese día. El evento guarda la columna de donde salió para regresarla ahí.
  def postpone!(until_date:, actor: nil, reason: nil, reason_id: nil)
    date = postpone_date!(until_date)
    motive = postpone_reason!(reason_id)
    payload = { from: status, to: 'waiting_on_customer', until: date.iso8601, reason: reason.presence,
                reason_id: motive&.id, reason_label: motive&.label }
    payload[:column_id] = case_type_column_id unless postponed?
    update!(status: :waiting_on_customer, postponed_until: date, postpone_reason_id: motive&.id,
            case_type_column_id: postponed_column_id || case_type_column_id)
    case_events.create!(account: account, event_type: :postponed, origin: actor ? :agent : :system,
                        actor: actor, payload: payload.compact)
    Quotes::OpportunitySync.from_opportunity(self, :postponed, actor: actor) # Plan-Catalogo-Cotizaciones
    self
  end

  # Regresa una oportunidad pospuesta a trabajo activo, a la etapa donde estaba.
  def resume!(actor: nil, reason: nil)
    raise 'La oportunidad no está pospuesta' unless postponed?

    was_until = postponed_until
    update!(status: :in_progress, postponed_until: nil, postpone_reason_id: nil, case_type_column_id: resume_column_id)
    case_events.create!(account: account, event_type: :resumed, origin: actor ? :agent : :system, actor: actor,
                        payload: { from: 'waiting_on_customer', to: 'in_progress',
                                   postponed_until: was_until.iso8601, reason: reason.presence }.compact)
    Quotes::OpportunitySync.from_opportunity(self, :resumed, actor: actor) # Plan-Catalogo-Cotizaciones
    self
  end

  # Plan-Metricas-Comercial — casilla «Comprometida por el cliente». Marcarla
  # guarda cuándo (si ya estaba, se conserva); desmarcarla borra marca y nota.
  def committed=(value)
    if ActiveModel::Type::Boolean.new.cast(value)
      self.committed_at ||= Time.current
    else
      self.committed_at = nil
      self.commit_note = nil
    end
  end

  def committed?
    committed_at.present?
  end

  # Asigna (sin guardar) los datos comerciales recibidos y devuelve lo que cambia,
  # para registrarlo con log_commercial_change! una vez guardado.
  def assign_commercial_data(data)
    data = data.to_h.stringify_keys.slice(*COMMERCIAL_FIELDS)
    data['currency'] = data['currency'].to_s.strip.upcase.presence if data.key?('currency')
    data['commit_note'] = data['commit_note'].to_s.strip.presence if data.key?('commit_note')
    assign_attributes(data)
    changes_to_save.slice(*COMMERCIAL_COLUMNS)
  end

  # Monto/moneda/cierre/probabilidad → `amount_changed`. El compromiso va aparte
  # (`commitment_changed`: set · moved · removed · note) para poder medir si las
  # promesas se cumplen y cuántas veces se movieron.
  def log_commercial_change!(changes, actor: nil)
    return if changes.blank?

    origin = actor ? :agent : :system
    commitment = commitment_payload(changes)
    plain = changes.except(*COMMITMENT_COLUMNS)
    if plain.present?
      case_events.create!(account: account, event_type: :amount_changed, origin: origin, actor: actor,
                          payload: plain.transform_values { |from, to| { from: from, to: to } })
    end
    return unless commitment

    case_events.create!(account: account, event_type: :commitment_changed, origin: origin, actor: actor,
                        payload: commitment)
  end

  # Plan-Clase-Orden-de-Trabajo F2a — igual que los datos comerciales: asigna (sin
  # guardar) y devuelve lo que cambia, para registrarlo una vez guardado.
  def assign_work_order_data(data)
    data = data.to_h.stringify_keys.slice(*WORK_ORDER_FIELDS)
    assign_attributes(data)
    changes_to_save.slice(*WORK_ORDER_FIELDS)
  end

  # Plan-Clase-Proyecto P1 — mismo patrón que los datos de la orden.
  def assign_project_data(data)
    data = data.to_h.stringify_keys.slice(*PROJECT_FIELDS)
    assign_attributes(data)
    changes_to_save.slice(*PROJECT_FIELDS)
  end

  def log_project_change!(changes, actor: nil)
    return if changes.blank?

    case_events.create!(account: account, event_type: :project_changed, origin: actor ? :agent : :system,
                        actor: actor, payload: changes.transform_values { |from, to| { from: from, to: to } })
  end

  def log_work_order_change!(changes, actor: nil)
    return if changes.blank?

    case_events.create!(account: account, event_type: :work_order_changed, origin: actor ? :agent : :system,
                        actor: actor, payload: changes.transform_values { |from, to| { from: from, to: to } })
  end

  # Plan-Clase-Orden-de-Trabajo F2b — una orden «Por programar» (open/classified)
  # pasa a «Programada» (assigned) al agendar su primera visita. Si ya avanzó, no
  # se toca: reprogramar o agendar otra visita no la regresa.
  TO_SCHEDULE_STATUSES = %w[open classified].freeze

  def mark_visit_scheduled!
    return unless work_order? && TO_SCHEDULE_STATUSES.include?(status)

    transition!('assigned', force: true, reason: 'Visita programada')
  end

  # Próxima visita vigente (programada o reprogramada, desde ahora).
  def next_visit_at
    case_meetings.active.where(starts_at: Time.current..).minimum(:starts_at)
  end

  # ¿Hay una visita vigente cuya hora ya pasó (nadie la marcó realizada)?
  def visit_overdue?
    case_meetings.active.exists?(starts_at: ...Time.current)
  end

  # Suma de los materiales con costo (sin costo no suman).
  def work_order_total
    work_order_items.sum { |item| item.total || 0 }
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

  # @tickets_cases — bitácora: nota interna del agente en el timeline.
  # NUNCA sale al cliente (vive en case_events, que el User Portal no expone).
  # La clave `content` del payload es la que ya esperan Cases::Ai::Summarizer y
  # payloadSummary() en JourneyView.vue — no renombrarla.
  # @tickets_cases — `case_task` opcional: si viene, la nota pertenece a esa
  # tarea del ticket (folio T00N en la tabla); si es nil, es nota del ticket.
  def add_internal_note!(content:, actor: nil, case_task: nil)
    raise 'La nota no puede estar vacía' if content.blank?

    case_events.create!(
      account:    account,
      event_type: :internal_note,
      origin:     actor ? :agent : :system,
      actor:      actor,
      case_task:  case_task,
      # @tickets_cases — consecutivo estable por ticket (N001, N002…): se guarda
      # en el payload al crear y no se recicla al borrar.
      payload:    { content: content.to_s.strip, sequence: next_note_sequence }
    )
  end

  # Siguiente consecutivo de nota interna para este ticket.
  def next_note_sequence
    case_events.where(event_type: :internal_note)
               .maximum(Arel.sql("(payload->>'sequence')::int")).to_i + 1
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

  # @tickets_cases P4 — vencimiento estilo osTicket. `due_at` manual pisa al
  # estimado por el SLA (created_at + objetivo de resolución + pausas acumuladas).
  # Devuelve nil si no hay fecha manual ni objetivo de resolución.
  def effective_due_at
    return due_at if due_at.present?
    return nil if resolution_time_target.nil? || created_at.nil?

    created_at + (resolution_time_target + sla_paused_minutes).minutes
  end

  # ¿Vencido por su fecha límite y todavía abierto? (para el rojo de la UI)
  def due_overdue?
    date = effective_due_at
    date.present? && date.past? && !resolved? && !closed? && !cancelled?
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

  # @tickets_cases — Regla 2 (invariante) del Plan-Columnas-Por-Tipo: la columna
  # NUNCA contradice al estado. Si el puntero deja de cumplir columna.statuses ∋
  # status (o pertenece a otro tipo), se pone en NULL → el tablero lo pinta por el
  # fallback de status. Dejarlo en NULL (en vez de reasignar) es deliberado: NULL
  # significa "nadie ha decidido el sub-estado", que es la verdad en ese momento.
  def advance_contact_funnel
    Kanban::FunnelTriggerJob.perform_later(conversation_id, 'case_created', { 'case_class' => case_type&.case_class, 'folio' => folio })
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] embudo de contactos del caso #{id}: #{e.message}")
  end

  def create_stage_tasks
    Cases::StageTasksService.new(self).call
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] tareas de la etapa del caso #{id}: #{e.message}")
  end

  def resync_type_column
    return if case_type_column_id.nil?

    col = CaseTypeColumn.find_by(id: case_type_column_id)
    return if col && col.case_type_id == case_type_id && col.statuses.include?(status)

    self.case_type_column_id = nil
  end

  # ── Plan-Clase-Comercial F3 ────────────────────────────────────────────────

  def closing_attrs(closure)
    return outcome_attrs(closure) if commercial?
    return conformity_attrs(closure) if work_order?
    return { closed_at: Time.current, closure_solution: closure['closure_solution'].presence } if project?

    {
      closed_at:          Time.current,
      closure_type:       closure['closure_type'],
      closure_cause:      closure['closure_cause'],
      closure_solution:   closure['closure_solution'],
      customer_confirmed: ActiveModel::Type::Boolean.new.cast(closure['customer_confirmed']) || false
    }
  end

  # Cierre de oportunidad: resultado + motivo; la probabilidad queda en 100/0 y el
  # caso se acomoda en la columna del resultado si el tipo la tiene.
  def outcome_attrs(closure)
    result = closure['outcome']
    {
      closed_at:           Time.current,
      outcome:             result,
      outcome_at:          Time.current,
      outcome_reason_id:   closure['outcome_reason_id'].presence,
      outcome_note:        closure['outcome_note'].presence,
      probability:         result == 'won' ? 100 : 0,
      postponed_until:     nil,
      postpone_reason_id:  nil,
      case_type_column_id: type_column_id { |c| c.outcome == result } || case_type_column_id
    }
  end

  def closure_payload(closure)
    if work_order?
      return { received_by: closure['received_by'], actual_hours: closure['actual_hours'],
               note: closure['conformity_note'].presence }.compact
    end
    return { note: closure['closure_solution'].presence }.compact if project?
    return { closure_type: closure['closure_type'] } unless commercial?

    { outcome: closure['outcome'], outcome_reason: outcome_reason&.label,
      note: closure['outcome_note'].presence }.compact
  end

  # Salir de `closed` borra el resultado (el evento guarda cuál era) y salir de la
  # espera borra la fecha de «retomar el». Para Soporte ambos ya son nil.
  def commercial_exit_attrs(old_status, new_status)
    attrs = {}
    if old_status.to_s == 'closed' && new_status.to_s != 'closed' && outcome.present?
      attrs.merge!(outcome: nil, outcome_at: nil, outcome_reason_id: nil, outcome_note: nil, probability: nil)
    end
    attrs.merge!(postponed_until: nil, postpone_reason_id: nil) if leaving_postponement?(new_status)
    attrs
  end

  def commitment_has_date
    errors.add(:expected_close_at, COMMITMENT_DATE_MSG) if committed? && expected_close_at.blank?
  end

  def commitment_payload(changes)
    marked = commitment_mark_payload(changes['committed_at'])
    return marked if marked
    return unless committed?

    if changes.key?('expected_close_at')
      from, to = changes['expected_close_at']
      return { action: 'moved', from: from, to: to }
    end
    { action: 'note', note: commit_note } if changes.key?('commit_note')
  end

  # Se marcó o se quitó la casilla (nil si no cambió).
  def commitment_mark_payload(change)
    return unless change

    was, now = change
    return { action: 'removed' } if now.nil?

    { action: 'set', on: expected_close_at, note: commit_note }.compact if was.nil?
  end

  def project_due_after_start
    return unless project_start_on && project_due_on && project_due_on < project_start_on

    errors.add(:project_due_on, 'no puede ser antes de la fecha de inicio')
  end

  def leaving_postponement?(new_status)
    postponed_until.present? && new_status.to_s != 'waiting_on_customer'
  end

  # Primera columna (no final) del tipo que cumpla la condición.
  def type_column_id(&)
    return nil if case_type.nil?

    case_type.case_type_columns.ordered.to_a.detect(&)&.id
  end

  def postponed_column_id
    type_column_id { |c| c.outcome.nil? && c.statuses.include?('waiting_on_customer') }
  end

  # La columna de donde salió al posponerse, si todavía sirve para `in_progress`.
  def resume_column_id
    event = case_events.where(event_type: :postponed).where("payload ? 'column_id'").order(:id).last
    column_id = event&.payload&.dig('column_id')
    type_column_id { |c| c.id == column_id && c.outcome.nil? && c.statuses.include?('in_progress') }
  end

  # Valida que se pueda posponer y devuelve la fecha (Date) de «retomar el».
  def postpone_date!(value)
    raise 'Solo las oportunidades se posponen' unless commercial?
    raise 'Una oportunidad cerrada no se pospone' if closed? || cancelled?

    date = parse_postpone_date(value)
    raise 'Indica una fecha futura para retomarla' if date.nil? || date <= Date.current

    date
  end

  def parse_postpone_date(value)
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def sync_probability_from_column
    column_probability = CaseTypeColumn.where(id: case_type_column_id).pick(:probability)
    self.probability = column_probability unless column_probability.nil?
  end

  # Moneda en mayúsculas; al crear una oportunidad, moneda de la cuenta y la
  # probabilidad de la columna donde nace.
  def assign_contact_owner
    return if assignee_id.present? || contact&.owner_id.nil?

    self.assignee_id = contact.owner_id
    self.assignee_type = :agent
  end

  def normalize_commercial_data
    self.currency = currency.to_s.strip.upcase.presence
    # Plan-Clase-Proyecto P1 — el presupuesto también va en la moneda de la cuenta.
    self.currency ||= CaseSetting.for_account(account).default_currency if new_record? && account && project?
    return unless new_record? && account && commercial?

    self.currency ||= CaseSetting.for_account(account).default_currency
    self.probability ||= starting_probability
  end

  def starting_probability
    column_id = type_column_id { |c| c.outcome.nil? && c.statuses.include?(status) }
    CaseTypeColumn.where(id: column_id).pick(:probability)
  end

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
    return validate_outcome!(data) if commercial? # Plan-Clase-Comercial F3
    return validate_conformity!(data) if work_order? # Plan-Clase-Orden-de-Trabajo F2a
    return data if project? # Plan-Clase-Proyecto P1: el resumen de cierre es opcional

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

  # Plan-Clase-Comercial F3 (hallazgo #1) — la oportunidad cierra con resultado y, si
  # se perdió o canceló, con motivo del catálogo. Sin catálogo, basta la nota.
  def validate_outcome!(data)
    result = data['outcome'].to_s
    raise 'Para cerrar la oportunidad indica el resultado: ganada, perdida o cancelada' unless CaseTicket.outcomes.key?(result)

    reasons = account.case_outcome_reasons.where(outcome: result)
    if data['outcome_reason_id'].present?
      raise 'El motivo no corresponde a este resultado' unless reasons.exists?(id: data['outcome_reason_id'])
    else
      require_reason_or_note!(reasons, data, note_required: result != 'won')
    end
    data
  end

  # Plan-Clase-Orden-de-Trabajo F2a — cerrar una orden pide la conformidad: quién
  # recibió y las horas reales (si ya estaban capturadas en la orden, bastan).
  def validate_conformity!(data)
    data['actual_hours'] = data['actual_hours'].presence || actual_hours
    missing = []
    missing << 'horas reales' if data['actual_hours'].blank?
    missing << 'quién recibió' if data['received_by'].to_s.strip.blank?
    raise "Para cerrar la orden indica: #{missing.join(', ')}" if missing.any?
    raise 'Las horas reales no pueden ser negativas' if BigDecimal(data['actual_hours'].to_s).negative?

    data
  rescue ArgumentError
    raise 'Las horas reales deben ser un número'
  end

  def conformity_attrs(closure)
    {
      closed_at:       Time.current,
      actual_hours:    closure['actual_hours'],
      received_by:     closure['received_by'].to_s.strip,
      received_at:     Time.current,
      conformity_note: closure['conformity_note'].presence
    }
  end

  # Con catálogo activo el motivo es obligatorio (también en Ganada). Sin catálogo,
  # Perdida/Cancelada piden la nota; Ganada no.
  def require_reason_or_note!(reasons, data, note_required: true)
    raise 'Indica el motivo del resultado' if reasons.enabled.exists?
    raise 'Describe el motivo en la nota' if note_required && data['outcome_note'].blank?
  end

  # Motivo de la pospuesta: obligatorio si la cuenta tiene motivos de pospuesta activos.
  def postpone_reason!(reason_id)
    reasons = account.case_outcome_reasons.outcome_postponed
    if reason_id.present?
      reasons.find_by(id: reason_id) || raise('El motivo no corresponde a una pospuesta')
    elsif reasons.enabled.exists?
      raise 'Indica el motivo de la pospuesta'
    end
  end

  # @tickets_cases 2B — si hay impacto y urgencia, la prioridad se deriva de la matriz ITIL.
  # Si no, se respeta la prioridad fijada manualmente (comportamiento original).
  def derive_priority_from_matrix
    return if skip_priority_derivation
    return if commercial? # Plan-Clase-Comercial F3: la prioridad de una venta la decide el vendedor

    derived = Cases::PriorityMatrix.derive(impact, urgency)
    self.priority = derived if derived.present?
  end

  # @tickets_cases 2I — usa la política SLA configurada (más específica) y, si no hay,
  # cae al hash SLA_BY_PRIORITY. No pisa targets ya fijados manualmente.
  def assign_sla_targets
    return unless class_capability?(:sla) # hallazgo #7: solo Soporte lleva SLA (ni oportunidad ni orden)

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

  # @tickets_cases Fase C — todo ticket es de un contacto (externo) o de un agente
  # solicitante (interno). No puede quedarse sin ambos.
  def case_type_not_retired
    return unless case_type&.retired?

    errors.add(:case_type_id, 'está retirado: usa el tipo nuevo de su clase')
  end

  def contact_or_requester_present
    return if contact_id.present? || requester_id.present?

    errors.add(:base, 'Debe tener un contacto o un solicitante interno')
  end

  def commercial_needs_contact
    errors.add(:contact_id, 'una oportunidad necesita un cliente') if commercial? && contact_id.blank?
  end

  def case_class_unchanged
    old_type = CaseType.find_by(id: case_type_id_in_database)
    return if (old_type&.case_class || 'support') == (case_type&.case_class || 'support')

    errors.add(:case_type_id, 'es de otra clase. Cancela este caso y crea uno nuevo en la otra clase')
  end

  def drop_classification_of_other_type
    self.affected_service_id = nil if other_type?(affected_service)
    self.category_id = nil if other_type?(category)
  end

  def classification_matches_type
    errors.add(:affected_service_id, 'no aplica a este tipo de caso') if other_type?(affected_service)
    errors.add(:category_id, 'no aplica a este tipo de caso') if other_type?(category)
  end

  # Servicio/categoría que existe pero es propio de OTRO tipo.
  def other_type?(classification)
    classification.present? && !classification.applies_to_type?(case_type_id)
  end

  def event_type_for_transition(old_status, new_status)
    case new_status.to_s
    when 'assigned'     then :assigned
    when 'in_diagnosis' then :in_diagnosis
    when 'escalated'    then :escalated
    when 'resolved'     then :resolved
    when 'validating'   then :validating
    when 'closed'       then commercial? ? :outcome_set : :closed
    when 'in_progress'  then %w[resolved validating closed].include?(old_status.to_s) ? :reopened : :status_changed
    else :status_changed
    end
  end
end
