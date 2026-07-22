# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Notas internas del ticket (osTicket "Internal notes")
# ================================================================================
# GET    /api/v1/accounts/:id/case_tickets/:case_ticket_id/notes
# POST   /api/v1/accounts/:id/case_tickets/:case_ticket_id/notes
# PATCH  /api/v1/accounts/:id/case_tickets/:case_ticket_id/notes/:id
# DELETE /api/v1/accounts/:id/case_tickets/:case_ticket_id/notes/:id
#
# La nota NO es un modelo propio: vive en `case_events` con event_type
# :internal_note y el texto en payload['content'] — la misma fila que pinta el
# Historial del Avance y que lee Cases::Ai::Summarizer. Por eso este controlador
# opera sobre case_events y no sobre una tabla nueva.
# ================================================================================

class Api::V1::Accounts::CaseNotesController < Api::V1::Accounts::BaseController
  before_action :set_ticket
  before_action :set_note, only: %i[update destroy]

  def index
    render json: { case_notes: notes_scope.map { |note| note_json(note) } }
  end

  def create
    note = @ticket.add_internal_note!(content: note_params[:content], actor: current_user)
    render json: { case_note: note_json(note) }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    content = note_params[:content].to_s.strip
    return render json: { error: 'La nota no puede estar vacía' }, status: :unprocessable_entity if content.blank?

    # La nota es parte del timeline, así que la edición deja rastro en vez de
    # reescribir el original en silencio.
    @note.update!(payload: @note.payload.merge(
      'content' => content,
      'edited_at' => Time.current.iso8601,
      'edited_by' => current_user&.name
    ))
    render json: { case_note: note_json(@note) }
  end

  def destroy
    @note.destroy!
    head :no_content
  end

  private

  def set_ticket
    @ticket = Current.account.case_tickets.find(params[:case_ticket_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ticket no encontrado' }, status: :not_found
  end

  def set_note
    @note = notes_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Nota no encontrada' }, status: :not_found
  end

  # Solo notas internas: nunca deja tocar otros eventos del timeline.
  # Orden cronológico (la más vieja arriba), como el hilo de osTicket: se lee
  # como bitácora de arriba abajo.
  def notes_scope
    @ticket.case_events.where(event_type: :internal_note).order(created_at: :asc)
  end

  def note_params
    params.require(:case_note).permit(:content)
  end

  def note_json(note)
    payload = note.payload || {}
    {
      id:         note.id,
      content:    payload['content'],
      actor:      ref_user(note.actor),
      created_at: note.created_at,
      edited_at:  payload['edited_at'],
      edited_by:  payload['edited_by']
    }
  end

  def ref_user(user)
    return nil unless user

    { id: user.id, name: user.name }
  end
end
