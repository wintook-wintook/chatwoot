# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — INSCRIBIR A UN CONTACTO EN UNA CAMPAÑA
# ================================================================================
# Plan: docs/automatizacion_campanas_plan.md (§4.1). El único camino para meter a alguien
# en una campaña: lo usan el lote (BulkAssignService) y la automatización ("Agregar a
# campaña"). Siempre deja una TrackingCampaignEntry, entre o no:
#
#   campaña pausada, terminada o pasado el fin  → omitido "campaign_closed"
#   ya inscrito en esta campaña                  → omitido "already_enrolled"
#   llegó al tope del día (daily_cap)            → omitido "daily_cap"
#   ya tiene un Agente IA activo en el inbox     → omitido "active_tracking"
#   el canal no lo puede contactar (sin teléfono → omitido "not_contactable"
#     en WhatsApp, sin correo en Email…)
#   la hora calculada cae después del fin        → omitido "outside_window"
#   si no                                        → inscrito + ContactTracking programado
#
# Dos inscripciones del mismo contacto al mismo tiempo (dos automatizaciones que disparan
# juntas): el índice único deja pasar una; la otra queda "already_enrolled".
# ================================================================================
class TrackingCampaigns::Enroll
  include ContactTrackings::Eligibility

  # skip_active: false solo lo usa el lote cuando se pide explícitamente por API (la
  # pantalla siempre manda true); la automatización nunca lo desactiva.
  def initialize(campaign, contact, source:, conversation: nil, automation_rule: nil, agent: nil, # rubocop:disable Metrics/ParameterLists
                 at: Time.current, skip_active: true)
    @campaign = campaign
    @contact = contact
    @source = source
    @conversation = conversation
    @automation_rule = automation_rule
    @agent = agent
    @at = at
    @skip_active = skip_active
  end

  # La TrackingCampaignEntry creada (inscrita u omitida).
  def call
    reason = skip_reason
    return skip(reason) if reason

    send_at = TrackingCampaigns::Schedule.new(@campaign).send_at(@at)
    return skip('outside_window') unless send_at

    enroll(send_at)
  rescue ActiveRecord::RecordNotUnique
    skip('already_enrolled')
  end

  private

  def skip_reason
    return 'campaign_closed' unless open?
    return 'already_enrolled' if @campaign.entries.enrolled.exists?(contact_id: @contact.id)
    return 'daily_cap' if daily_cap_reached?
    return 'active_tracking' if @skip_active && active_tracking?

    'not_contactable' unless contactable?
  end

  # Cerrada también si le falta el canal o el Agente IA: no hay por dónde ni con qué escribir.
  def open?
    @campaign.accepting_entries?(@at) && @campaign.inbox.present? && @campaign.tracking_template.present?
  end

  def daily_cap_reached?
    return false if @campaign.daily_cap.blank?

    day = @at.in_time_zone(@campaign.inbox.timezone.presence || 'UTC')
    @campaign.entries.enrolled.where(created_at: day.all_day).count >= @campaign.daily_cap
  end

  def active_tracking?
    ContactTracking.exists?(contact_id: @contact.id, inbox_id: @campaign.inbox_id, status: ACTIVE_STATUSES)
  end

  def contactable?
    reusable = builder.existing_conversation.present?
    channel_contactability(@contact, @campaign.inbox.channel_type, reusable: reusable).first
  end

  def builder
    @builder ||= TrackingCampaigns::TrackingBuilder.new(@campaign, @contact, agent: @agent, note: note)
  end

  # La inscripción se guarda PRIMERO, sola: si otra ganó la carrera, el índice único salta
  # acá y no se crea un segundo seguimiento. No va todo en una transacción porque el
  # seguimiento encola un job, y el job podría correr antes del commit y no encontrarlo.
  # Si crear el seguimiento falla, la inscripción se deshace y el error sube.
  def enroll(send_at)
    entry = create_entry(status: 'enrolled')
    begin
      entry.update!(contact_tracking_id: builder.create!(scheduled_for: send_at))
    rescue StandardError
      entry.destroy
      raise
    end
    entry
  end

  def note
    return nil unless @source == 'automation'

    rule = @automation_rule ? " por la automatización \"#{@automation_rule.name}\"" : ''
    "📋 Inscrito en la campaña \"#{@campaign.name}\"#{rule}"
  end

  def skip(reason)
    create_entry(status: 'skipped', reason: reason)
  end

  def create_entry(status:, reason: nil)
    @campaign.entries.create!(account_id: @campaign.account_id, contact: @contact, source: @source, status: status,
                              reason: reason, conversation: @conversation, automation_rule: @automation_rule)
  end
end
