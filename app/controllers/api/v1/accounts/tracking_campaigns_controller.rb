# @campanas_vendedor
# frozen_string_literal: true

# ================================================================================
# Controller: TrackingCampaignsController
# ================================================================================
# Listado de campañas (corridas de asignación masiva de seguimientos) para el
# Dashboard de Seguimientos. Cada campaña agrupa sus ContactTracking; las
# estadísticas se agregan en una sola consulta para evitar N+1.
#
# GET /api/v1/accounts/:account_id/tracking_campaigns        → listado con stats
#     ?lite=true → solo lo que necesita un selector (automatizaciones), sin stats
# GET /api/v1/accounts/:account_id/tracking_campaigns/:id     → una campaña con stats
# POST /api/v1/accounts/:account_id/tracking_campaigns        → crea una campaña CONTINUA
#     (proyecto@automatizacion_campanas): sin audiencia, la llenan las automatizaciones.
#     Las por lote se crean por contact_tracking_bulk_assigns, que además asigna la audiencia.
# PATCH /api/v1/accounts/:account_id/tracking_campaigns/:id → modifica una campaña Guardada
#     como CONTINUA (mismos parámetros que create). Como por lote se modifica por
#     PATCH contact_tracking_bulk_assigns/:id. Ya puesta en curso no se modifica.
# GET /api/v1/accounts/:account_id/tracking_campaigns/:id/entries?page=N → inscritos y omitidos
#     (proyecto@automatizacion_campanas, ver TrackingCampaignEntriesJson)
# ================================================================================

class Api::V1::Accounts::TrackingCampaignsController < Api::V1::Accounts::BaseController
  include TrackingCampaignEntriesJson
  include TrackingCampaignContinuousParams
  ACTIVE_TRACKING_STATUSES = %w[pending scheduled active paused].freeze
  EMPTY_FUNNEL = { replied: 0, interested: 0, appointment: 0, objective_met: 0, paused_rule: 0, cancelled_rule: 0 }.freeze

  def index
    return render(json: lite_list) if ActiveModel::Type::Boolean.new.cast(params[:lite])

    campaigns = Current.account.tracking_campaigns
                       .includes(:tracking_template, :inbox)
                       .order(created_at: :desc)
    ids = campaigns.map(&:id)
    stats = stats_by_campaign(ids)
    delivery = delivery_by_campaign(ids)
    funnel = funnel_by_campaign(ids)

    render json: campaigns.map { |campaign| campaign_json(campaign, stats[campaign.id], delivery[campaign.id], funnel[campaign.id]) }
  end

  def show
    campaign = Current.account.tracking_campaigns.find(params[:id])
    stats = stats_by_campaign([campaign.id])
    delivery = delivery_by_campaign([campaign.id])
    funnel = funnel_by_campaign([campaign.id])

    render json: campaign_json(campaign, stats[campaign.id], delivery[campaign.id], funnel[campaign.id])
  end

  # Borra la campaña. Antes cancela los seguimientos aún vivos (detiene sus jobs)
  # para que no sigan enviando mensajes sin campaña. Los seguimientos NO se borran:
  # el modelo los desvincula (dependent: :nullify) y quedan sueltos en "Todos".
  def entries
    campaign = Current.account.tracking_campaigns.find(params[:id])
    render json: entries_payload(campaign, [params[:page].to_i, 1].max)
  end

  def create
    template, error = continuous_template
    return render_error(error) if error

    campaign = Current.account.tracking_campaigns.new(continuous_attributes(template).merge(user: current_user))
    return render_error(campaign.errors.messages.values.flatten.to_sentence) unless campaign.save

    render json: { campaign_id: campaign.id, campaign_name: campaign.name }
  end

  # Una Guardada se puede modificar (y pasar de por lote a continua); en curso, ya no.
  # Sigue Guardada: ponerla en curso es POST :id/launch.
  def update
    campaign = Current.account.tracking_campaigns.find(params[:id])
    return render_error('Solo se puede modificar una campaña Guardada.') unless campaign.saved?

    template, error = continuous_template
    return render_error(error) if error

    attributes = continuous_attributes(template).merge(status: 'saved', audience: {})
    return render_error(campaign.errors.messages.values.flatten.to_sentence) unless campaign.update(attributes)

    render json: { campaign_id: campaign.id, campaign_name: campaign.name }
  end

  def destroy
    campaign = Current.account.tracking_campaigns.find(params[:id])
    cancel_active_trackings(campaign)
    # Al borrarla, los seguimientos se desvinculan: uno que siguiera vivo quedaría enviando
    # sin campaña y fuera del dashboard. Si alguno no se pudo cancelar, no se borra.
    return render_error('No se pudieron cancelar todos los seguimientos de la campaña.') if active_trackings(campaign).exists?

    campaign.destroy!
    head :no_content
  end

  private

  def active_trackings(campaign)
    campaign.contact_trackings.where(status: ACTIVE_TRACKING_STATUSES)
  end

  # Cancela los seguimientos no terminales de la campaña (pending/scheduled/active/paused).
  # cancel! cancela los jobs programados y marca el estado como 'cancelled'.
  def cancel_active_trackings(campaign)
    active_trackings(campaign).find_each(&:cancel!)
  end

  # { campaign_id => { 'pending' => N, 'active' => N, ... } } en una sola query.
  # Además desglosa 'completed' según si hubo respuesta (last_intent) o no, con una
  # clave sintética 'completed_replied' (el resto de completados = sin respuesta).
  def stats_by_campaign(ids)
    return {} if ids.blank?

    grouped = ContactTracking.where(tracking_campaign_id: ids).group(:tracking_campaign_id, :status).count
    acc = grouped.each_with_object({}) do |((campaign_id, status), count), memo|
      (memo[campaign_id] ||= {})[status] = count
    end

    completed_replied = ContactTracking.where(tracking_campaign_id: ids, status: 'completed')
                                       .where.not(last_intent: nil)
                                       .group(:tracking_campaign_id).count
    completed_replied.each do |campaign_id, count|
      (acc[campaign_id] ||= {})['completed_replied'] = count
    end
    acc
  end

  # Eje de ENTREGA (WhatsApp): ver TrackingCampaigns::DeliveryStats.
  def delivery_by_campaign(ids)
    TrackingCampaigns::DeliveryStats.new(ids).call
  end

  # Embudo por campaña, mismo criterio que el overview de cuenta: replied = last_intent
  # no nulo; el resto solo por las reglas de palabra clave: interested_at / booked_at,
  # status objective_met, y pausados/cancelados que siguen así porque los dejó una regla
  # (keyword_action_fired). Queries agregadas (sin N+1).
  # Devuelve { campaign_id => { replied:, interested:, appointment:, objective_met:, paused_rule:, cancelled_rule: } }.
  def funnel_by_campaign(ids)
    return {} if ids.blank?

    base = ContactTracking.where(tracking_campaign_id: ids)
    # siguen en `status` porque una regla de palabra clave con `action` los dejó así
    by_rule = ->(status, action) { base.where(status: status).where("keyword_action_fired->>'action' = ?", action) }
    counts = {
      replied: base.where.not(last_intent: nil),
      interested: base.where.not(interested_at: nil),
      appointment: base.where.not(booked_at: nil),
      objective_met: base.where(status: 'objective_met'),
      paused_rule: by_rule.call('paused', 'pause'),
      cancelled_rule: by_rule.call('cancelled', 'cancel')
    }.transform_values { |relation| count_by_campaign(relation) }

    ids.index_with { |id| counts.transform_values { |by_campaign| by_campaign[id].to_i } }
  end

  def count_by_campaign(relation)
    relation.group(:tracking_campaign_id).count
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  # proyecto@automatizacion_campanas — para el desplegable "Agregar a campaña".
  def lite_list
    Current.account.tracking_campaigns.order(created_at: :desc)
           .map { |c| c.slice(:id, :name, :status, :mode, :scheduled_for, :ends_at, :inbox_id) }
  end

  def campaign_json(campaign, status_counts, delivery_counts, funnel_counts)
    {
      id: campaign.id,
      name: campaign.name,
      status: campaign.status,
      objective: campaign.objective,
      scheduled_for: campaign.scheduled_for,
      # proyecto@automatizacion_campanas — la ventana y cómo se agenda a cada inscrito
      mode: campaign.mode,
      purpose: campaign.purpose, # prospeccion V0
      ends_at: campaign.ends_at,
      entry_delay_minutes: campaign.entry_delay_minutes,
      respect_working_hours: campaign.respect_working_hours,
      daily_cap: campaign.daily_cap,
      created_at: campaign.created_at,
      template_name: campaign.tracking_template&.name,
      inbox_name: campaign.inbox&.name,
      stats: aggregate_stats(status_counts || {}),
      delivery: aggregate_delivery(delivery_counts || {}),
      funnel: funnel_counts || EMPTY_FUNNEL
    }.merge(editable_json(campaign), prospecting_json(campaign))
  end

  # prospeccion V6: el embudo de prospección (solo en campañas de Prospección)
  # prospeccion P2: y la entrega de interesados (tablero, columna, plazo, escalar)
  def prospecting_json(campaign)
    { prospecting_funnel: campaign.prospecting? ? TrackingCampaigns::ProspectingFunnel.for(campaign) : nil }
      .merge(campaign.handoff_settings, subject_test: TrackingCampaigns::SubjectTest.stats(campaign)) # P3: prueba A/B
  end

  # Para modificar una Guardada: CampaignForm la vuelve a llenar con esto. Y, si está
  # pausada por un error de configuración de Meta (proyecto@automatizacion_campanas), el motivo.
  def editable_json(campaign)
    { tracking_template_id: campaign.tracking_template_id, audience: campaign.audience,
      paused_reason: campaign.paused_reason, paused_at: campaign.paused_at,
      email_subject: campaign.email_subject, # prospeccion F1
      email_subject_b: campaign.email_subject_b } # prospeccion P3
  end

  def aggregate_stats(status_counts)
    completed = status_counts['completed'].to_i
    completed_replied = status_counts['completed_replied'].to_i
    {
      total: status_counts.except('completed_replied').values.sum,
      pending: status_counts['pending'].to_i + status_counts['scheduled'].to_i,
      active: status_counts['active'].to_i,
      paused: status_counts['paused'].to_i,
      completed: completed,
      completed_replied: completed_replied,
      completed_no_reply: completed - completed_replied,
      cancelled: status_counts['cancelled'].to_i,
      failed: status_counts['failed'].to_i
    }
  end

  def aggregate_delivery(delivery_counts)
    {
      delivered: delivery_counts[:delivered].to_i,
      sent: delivery_counts[:sent].to_i,
      unconfirmed: delivery_counts[:unconfirmed].to_i,
      retrying: delivery_counts[:retrying].to_i,
      failed: delivery_counts[:failed].to_i,
      failure_reasons: delivery_counts.fetch(:failure_reasons, [])
    }
  end
end
