# proyecto@bulk_tracking_assign
# frozen_string_literal: true

# ================================================================================
# proyecto@bulk_tracking_assign
# ================================================================================
# Controller: ContactTrackingBulkAssignsController
# Descripción: Endpoint para asignar una TrackingTemplate a un conjunto de
#              contactos resuelto por filtro (mismo formato que /contacts/filter).
#
# POST /api/v1/accounts/:account_id/contact_tracking_bulk_assigns
#   Parámetros:
#     - payload (array): filtro de contactos (mismo formato que Contacts::FilterService)
#     - template_id: ID de la TrackingTemplate a aplicar
#     - scheduled_for: fecha/hora ISO 8601 del primer intento
#     - excluded_contact_ids (array, opcional): IDs a excluir de la selección
#     - skip_active (boolean, opcional, default true): omitir contactos con tracking activo
#   Respuesta:
#     { inserted: N, skipped: N, errors: [{ contact_id:, contact_name:, message: }] }
# ================================================================================

class Api::V1::Accounts::ContactTrackingBulkAssignsController < Api::V1::Accounts::BaseController
  def create
    result = ContactTrackings::BulkAssignService.new(
      account:              Current.account,
      current_user:         current_user,
      filter_payload:       params.permit!['payload'] || [],
      template_id:          params[:template_id],
      scheduled_for:        parse_scheduled_for(params[:scheduled_for]),
      excluded_contact_ids: params[:excluded_contact_ids] || [],
      skip_active:          ActiveModel::Type::Boolean.new.cast(params.fetch(:skip_active, true))
    ).call

    render json: result, status: :ok
  end

  private

  def parse_scheduled_for(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
