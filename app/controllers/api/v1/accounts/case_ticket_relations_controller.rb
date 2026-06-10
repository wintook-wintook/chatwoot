# frozen_string_literal: true

# ================================================================================
# @tickets_cases 2E — Relaciones entre tickets
# ================================================================================
# GET    /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/relations
# POST   /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/relations
# DELETE /api/v1/accounts/:account_id/case_tickets/:case_ticket_id/relations/:id
#
# Las relaciones son dirigidas (ticket → related_ticket). El index devuelve tanto
# las salientes (este ticket es el origen) como las entrantes (este ticket es el
# destino), cada una con su dirección para que la UI muestre la etiqueta correcta.
# ================================================================================

class Api::V1::Accounts::CaseTicketRelationsController < Api::V1::Accounts::BaseController
  before_action :set_ticket

  def index
    render json: { case_ticket_relations: relations_json }
  end

  def create
    related = Current.account.case_tickets.find_by(id: params[:related_ticket_id])
    return render json: { error: 'Ticket relacionado no encontrado' }, status: :not_found unless related

    relation = CaseTicketRelation.new(
      account:        Current.account,
      ticket:         @ticket,
      related_ticket: related,
      relation_type:  params[:relation_type]
    )

    if relation.save
      @ticket.case_events.create!(
        account: Current.account, event_type: :related, origin: :agent, actor: current_user,
        payload: { relation_type: relation.relation_type, related_folio: related.folio,
                   related_title: related.title, related_ticket_id: related.id }.compact
      )
      render json: { case_ticket_relation: relation_json(relation, :outgoing) }, status: :created
    else
      render json: { error: relation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    relation = CaseTicketRelation.where(account: Current.account)
                                 .where('ticket_id = :id OR related_ticket_id = :id', id: @ticket.id)
                                 .find_by(id: params[:id])
    return render json: { error: 'Relación no encontrada' }, status: :not_found unless relation

    relation.destroy!
    head :no_content
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def relations_json
    outgoing = @ticket.ticket_relations.includes(:related_ticket).map { |r| relation_json(r, :outgoing) }
    incoming = @ticket.inverse_ticket_relations.includes(:ticket).map { |r| relation_json(r, :incoming) }
    (outgoing + incoming).sort_by { |r| r[:created_at] }.reverse
  end

  def relation_json(relation, direction)
    other = direction == :outgoing ? relation.related_ticket : relation.ticket
    {
      id:            relation.id,
      relation_type: relation.relation_type,
      direction:     direction,
      created_at:    relation.created_at,
      ticket:        ticket_ref(other)
    }
  end

  def ticket_ref(ticket)
    {
      id:          ticket.id,
      folio:       ticket.folio,
      title:       ticket.title,
      status:      ticket.status,
      ticket_kind: ticket.ticket_kind,
      priority:    ticket.priority
    }
  end
end
