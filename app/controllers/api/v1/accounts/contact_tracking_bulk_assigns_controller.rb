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
#     - campaign_name: nombre de la TrackingCampaign que agrupa la corrida (@campanas_vendedor)
#     - launch: false guarda la campaña sin inscribir a nadie (Guardada); por defecto true
#     - template_id: ID de la TrackingTemplate a aplicar
#     - scheduled_for: fecha/hora ISO 8601 del primer intento
#     - excluded_contact_ids (array, opcional): IDs a excluir de la selección
#     - skip_active (boolean, opcional, default true): omitir contactos con tracking activo
#     - audience_source (opcional): { type: 'segment', segment_id: } | { type: 'label', label: },
#       cómo se eligió la audiencia, para mostrarla al modificar una campaña Guardada
#   Respuesta (200): { queued: N, campaign_id:, campaign_name: }
#     El procesamiento por contacto corre en background (ContactTrackings::BulkAssignJob);
#     el progreso real se ve en el detalle de la campaña (stats por status).
#   Respuesta (422): { error: "mensaje" } ante validación fallida.
#
# PATCH /api/v1/accounts/:account_id/contact_tracking_bulk_assigns/:id
#   Modifica la campaña Guardada :id como POR LOTE (mismos parámetros, sin launch). Sigue
#   Guardada; ya puesta en curso no se modifica. Respuesta (200): { saved:, contacts:, campaign_id: }
# ================================================================================

class Api::V1::Accounts::ContactTrackingBulkAssignsController < Api::V1::Accounts::BaseController
  def create
    render_result(assign_service(launch: launch_param).call)
  end

  def update
    campaign = Current.account.tracking_campaigns.find(params[:id])
    return render_result(error: 'Solo se puede modificar una campaña Guardada.') unless campaign.saved?

    render_result(assign_service(campaign: campaign).update!)
  end

  # Dry-run: clasifica la audiencia en buckets sin crear nada (@campanas_vendedor).
  def preview
    result = ContactTrackings::BulkAssignPreviewService.new(
      account: Current.account,
      current_user: current_user,
      filter_payload: params.permit!['payload'] || [],
      template_id: params[:template_id],
      skip_active: ActiveModel::Type::Boolean.new.cast(params.fetch(:skip_active, true)),
      excluded_contact_ids: params[:excluded_contact_ids] || []
    ).call

    return render json: result, status: :unprocessable_entity if result[:error].present?

    render json: result, status: :ok
  end

  private

  def assign_service(**extra)
    ContactTrackings::BulkAssignService.new(
      account: Current.account,
      current_user: current_user,
      filter_payload: params.permit!['payload'] || [],
      template_id: params[:template_id],
      campaign_name: params[:campaign_name],
      scheduled_for: parse_scheduled_for(params[:scheduled_for]),
      excluded_contact_ids: params[:excluded_contact_ids] || [],
      skip_active: ActiveModel::Type::Boolean.new.cast(params.fetch(:skip_active, true)),
      window: window_params,
      audience_source: audience_source_param,
      **extra
    )
  end

  def render_result(result)
    render json: result, status: result[:error].present? ? :unprocessable_entity : :ok
  end

  # false → la campaña queda Guardada, sin inscribir a nadie (por defecto true)
  def launch_param
    ActiveModel::Type::Boolean.new.cast(params.fetch(:launch, true))
  end

  def audience_source_param
    params[:audience_source]&.permit(:type, :segment_id, :label)&.to_h
  end

  # proyecto@automatizacion_campanas — la ventana de la campaña por lote (todo opcional).
  def window_params
    {
      ends_at: parse_scheduled_for(params[:ends_at]),
      entry_delay_minutes: params[:entry_delay_minutes].presence&.to_i,
      respect_working_hours: params.key?(:respect_working_hours) ? ActiveModel::Type::Boolean.new.cast(params[:respect_working_hours]) : nil
    }
  end

  def parse_scheduled_for(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
