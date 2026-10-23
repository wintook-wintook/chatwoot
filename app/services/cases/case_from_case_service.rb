# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Clase-Orden-de-Trabajo F2b / Plan-Clase-Proyecto P2
# ================================================================================
# Servicio: Cases::CaseFromCaseService
# Crea un caso nuevo de otra clase a partir de uno existente y los deja ligados:
#   - «Crear orden de trabajo» desde un ticket de Soporte o una oportunidad Ganada
#     (relación `work_order_origin`).
#   - «Crear proyecto» desde una oportunidad Ganada (relación `project_origin`).
# El caso nuevo hereda cliente, conversación, asunto y descripción; sin cliente nace
# interno del agente que lo pide. La clase es fija (E1.4): es un caso nuevo, no un
# cambio de tipo. Deja un evento `related` en los dos casos.
# ================================================================================

class Cases::CaseFromCaseService
  Error = Class.new(StandardError)

  TARGETS = {
    'work_order' => { flag: 'case_work_order', relation: :work_order_origin,
                      type_error: 'Elige un tipo de orden de trabajo',
                      origin_error: 'Solo se crea una orden desde un ticket de Soporte o una oportunidad ganada' },
    'project' => { flag: 'case_project', relation: :project_origin,
                   type_error: 'Elige un tipo de proyecto',
                   origin_error: 'Solo se crea un proyecto desde una oportunidad ganada' }
  }.freeze

  def initialize(origin:, case_type:, actor:, target:)
    @origin    = origin
    @account   = origin.account
    @case_type = case_type
    @actor     = actor
    @target    = target.to_s
    @config    = TARGETS.fetch(@target)
  end

  def call
    validate!
    ActiveRecord::Base.transaction do
      created = create_case
      CaseTicketRelation.create!(account: @account, ticket: created, related_ticket: @origin,
                                 relation_type: @config[:relation])
      log_related(created, @origin)
      log_related(@origin, created)
      created
    end
  end

  private

  def validate!
    raise Error, 'Esta clase de caso no está activa en esta cuenta' unless @account.feature_enabled?(@config[:flag])
    raise Error, @config[:type_error] unless target_type?
    raise Error, @config[:origin_error] unless allowed_origin?
  end

  def target_type?
    @case_type&.case_class == @target && @case_type.account_id == @account.id
  end

  # Orden: Soporte (o sin tipo) u oportunidad ganada. Proyecto: oportunidad ganada.
  def allowed_origin?
    won = @origin.commercial? && @origin.outcome_won?
    @target == 'work_order' ? (@origin.class_capability?(:sla) || won) : won
  end

  def create_case
    attrs = { case_type_id: @case_type.id, title: @origin.title, description: @origin.description }
    if @origin.contact
      Cases::OrchestratorService.new(account: @account, contact: @origin.contact, conversation: @origin.conversation)
                                .create_for_manual(**attrs)
    else
      Cases::OrchestratorService.new(account: @account).create_internal(requester: @actor, **attrs)
    end
  end

  def log_related(ticket, other)
    ticket.case_events.create!(
      account: @account, event_type: :related, origin: @actor ? :agent : :system, actor: @actor,
      payload: { relation_type: @config[:relation].to_s, related_folio: other.folio,
                 related_title: other.title, related_ticket_id: other.id }.compact
    )
  end
end
