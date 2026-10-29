# prospeccion V4 — un agente marca o quita «no contactar» desde la ficha del contacto.
#
#   POST   /contacts/:contact_id/opt_out  → lo marca (fuente 'agent') y cancela sus seguimientos
#   DELETE /contacts/:contact_id/opt_out  → se lo quita (el contacto volvió a dar permiso)
class Api::V1::Accounts::Contacts::OptOutsController < Api::V1::Accounts::Contacts::BaseController
  def create
    ContactTrackings::OptOut.call(@contact, source: 'agent')
    render json: opt_out_json
  end

  def destroy
    ContactTrackings::OptOut.undo(@contact)
    render json: opt_out_json
  end

  private

  def opt_out_json
    @contact.reload
    { opted_out_at: @contact.opted_out_at&.to_i, opted_out_source: @contact.opted_out_source }
  end
end
