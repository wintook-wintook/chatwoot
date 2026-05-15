# frozen_string_literal: true

# ================================================================================
# proyecto@import_seguimiento
# ================================================================================
# Controller: ContactTrackingImportsController
# Descripción: Endpoint para importar contactos desde Excel/CSV hacia contact_trackings.
#
# POST /api/v1/accounts/:account_id/contact_tracking_imports
#   Parámetros:
#     - file (multipart): archivo .xlsx, .xls o .csv con los contactos a importar
#   Respuesta:
#     { inserted: N, skipped: N, errors: [{ row: N, message: "..." }] }
# ================================================================================

class Api::V1::Accounts::ContactTrackingImportsController < Api::V1::Accounts::BaseController
  def create
    unless params[:file].present?
      render json: { error: 'El archivo es requerido' }, status: :unprocessable_entity
      return
    end

    results = ContactTrackingImportService.new(
      account:      Current.account,
      file:         params[:file],
      current_user: current_user
    ).call

    render json: results, status: :ok
  end
end
