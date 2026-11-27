# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — PONER EN CURSO UNA CAMPAÑA GUARDADA
# ================================================================================
# Una campaña Guardada (saved) no inscribe a nadie. Al ponerla en curso:
#
#   - El inicio que ya pasó (o que está vacío) se corre a ahora: queda En curso (running).
#     Un inicio futuro se respeta: queda Programada (draft) y la abre TrackingCampaigns::WindowJob.
#   - Por lote: la audiencia guardada (segmento o etiqueta + excluidos) se resuelve AHORA, con
#     los contactos del momento, y se inscribe en background como al crearla (BulkAssignJob).
#   - Continua: solo cambia el estado; desde ahí las automatizaciones ya pueden inscribir.
#
# Uso: TrackingCampaigns::Launch.new(campaign, user).call # => { campaign:, queued: } | { error: }
# ================================================================================
class TrackingCampaigns::Launch
  def initialize(campaign, user)
    @campaign = campaign
    @user = user
  end

  def call
    return { error: 'La campaña ya está en curso o terminó.' } unless @campaign.saved?

    now = Time.current
    return { error: 'La ventana de la campaña ya terminó: cambia la fecha de fin.' } if @campaign.ends_at && @campaign.ends_at <= now

    start = [@campaign.scheduled_for, now].compact.max
    open_campaign = -> { @campaign.update!(scheduled_for: start, status: TrackingCampaign.status_for(start, now)) }

    return continuous_launch(open_campaign) if @campaign.continuous?

    return contacts_launch(open_campaign) if contact_ids.any?

    result = batch_service(start).enqueue!(&open_campaign)
    result[:error] ? result : { campaign: @campaign, queued: result[:queued] }
  end

  private

  # Continua: queda en curso y entran los que lleguen. Recordar: los contratos que ya entran en sus días, desde ya
  # (luego cada mañana: TrackingCampaigns::RenewEnrollJob).
  def continuous_launch(open_campaign)
    open_campaign.call
    TrackingCampaigns::RenewEnrollJob.perform_later(@campaign.id) if @campaign.brief.to_h['renew_source'].present?
    { campaign: @campaign }
  end

  # Campaña con Vendedor IA armada desde otra («con los que les interesó»): la audiencia es una lista de contactos.
  def contact_ids = @campaign.motor2? ? Array(@campaign.audience.to_h['contact_ids']).map(&:to_i) : []

  def contacts_launch(open_campaign)
    open_campaign.call
    TrackingCampaigns::Motor2EnrollJob.perform_later(@campaign.id, nil, @user&.id) # lee los ids de la campaña
    { campaign: @campaign, queued: contact_ids.size }
  end

  def batch_service(start)
    audience = (@campaign.audience || {}).with_indifferent_access
    ContactTrackings::BulkAssignService.new(
      account: @campaign.account, current_user: @user, campaign: @campaign,
      filter_payload: audience[:filter_payload] || [], template_id: @campaign.tracking_template_id,
      scheduled_for: start, campaign_name: @campaign.name,
      excluded_contact_ids: audience[:excluded_contact_ids] || [],
      skip_active: audience.fetch(:skip_active, true)
    )
  end
end
