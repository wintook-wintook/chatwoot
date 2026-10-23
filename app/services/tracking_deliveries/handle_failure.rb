# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas
# TrackingDeliveries::HandleFailure
# ================================================================================
# Decide qué pasa con un envío fallido según el tipo de error de Meta (ErrorClassifier):
#
#   :retry        temporal / marketing con reintentos disponibles: el seguimiento se
#                 regresa al intento que falló y se reprograma (5 min, 30 min, 2 h; el de
#                 marketing una vez a las 24 h). El envío normal lo vuelve a mandar.
#   :config       se pausa la campaña con el motivo (o el seguimiento, si no tiene).
#   :unreachable  el contacto no puede recibir: el seguimiento queda fallido.
#   :permanent    no se reenvía; el seguimiento sigue su curso (el siguiente intento
#                 puede ir por otro camino, p. ej. plantilla en vez de sesión).
#
# Dos orígenes:
#   - rechazo al momento, desde ContactTrackingJob (immediate: true): el seguimiento está
#     'active' y bloqueado por el job, que no avanzó attempt_count.
#   - webhook de estado, desde FailureJob: el seguimiento ya avanzó (o terminó). Solo se
#     regresa si este envío sigue siendo el último y el contacto no ha respondido.
# ================================================================================
class TrackingDeliveries::HandleFailure
  BACKOFF = [5.minutes, 30.minutes, 2.hours].freeze
  MARKETING_BACKOFF = [24.hours].freeze
  # Estados desde los que un webhook puede regresar el seguimiento al intento fallido.
  REWINDABLE_STATUSES = %w[pending scheduled completed].freeze

  def initialize(delivery, tracking: nil, immediate: false)
    @delivery = delivery
    @tracking = tracking || delivery.contact_tracking
    @immediate = immediate
  end

  def perform
    return :skipped unless @delivery.failed? && @tracking

    case @delivery.error_kind
    when 'config' then pause_for_config
    when 'temporary', 'marketing' then retry_allowed? ? schedule_retry : give_up
    else give_up
    end
  end

  private

  def backoff
    @delivery.error_kind == 'marketing' ? MARKETING_BACKOFF : BACKOFF
  end

  def retry_allowed?
    @delivery.retry_count < backoff.size && rewindable?
  end

  def latest_delivery?
    @tracking.tracking_deliveries.maximum(:id) == @delivery.id
  end

  def contact_replied?
    return false if @tracking.conversation_id.blank?

    Message.incoming.where(conversation_id: @tracking.conversation_id)
           .exists?(['created_at > ?', @delivery.sent_at || @delivery.created_at])
  end

  # Regresa el seguimiento al intento que falló. attempt_count y la repetición vuelven a
  # como estaban antes de ese envío; el callback del modelo programa el job.
  def schedule_retry
    retry_at = backoff[@delivery.retry_count].from_now
    @delivery.update!(next_retry_at: retry_at)
    @tracking.update!(
      status: 'scheduled', scheduled_for: retry_at,
      last_error: "#{@delivery.error_summary} — reintento #{@delivery.retry_count + 1}/#{backoff.size}",
      **rewind_attributes
    )
    :retry
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[TrackingDeliveries] No se pudo reprogramar el seguimiento #{@tracking.id}: #{e.message}"
    give_up
  end

  def give_up
    return fail_tracking if TrackingDeliveries::ErrorClassifier.unreachable?(@delivery.error_code)

    # Rechazo al momento: el job marca el seguimiento como fallido con el motivo (como antes).
    # Por webhook: el seguimiento sigue; solo queda el motivo a la vista.
    @tracking.update_column(:last_error, @delivery.error_summary) unless @immediate # rubocop:disable Rails/SkipsModelValidations
    :permanent
  end

  def fail_tracking
    unless @tracking.cancelled? || @tracking.objective_met?
      @tracking.update_columns(status: 'failed', last_error: @delivery.error_summary, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
    :unreachable
  end

  def pause_for_config
    campaign = @delivery.tracking_campaign || @tracking.tracking_campaign
    TrackingCampaigns::Pause.new(campaign, reason: @delivery.error_summary).perform if campaign
    pause_tracking(by_campaign: campaign.present?)
    :config
  end

  # Se pausa directo (sin pause!): pause! recorre las colas de Sidekiq para cancelar jobs,
  # y el job que llegue de todos modos se ignora porque el seguimiento está pausado.
  # Si este envío sigue siendo el último, se regresa al intento fallido para que al
  # reanudar se vuelva a mandar (también si el seguimiento ya había terminado).
  def pause_tracking(by_campaign:)
    rewind = rewindable?
    return unless rewind || %w[pending scheduled active].include?(@tracking.status)

    attributes = { status: 'paused', paused_at: Time.current, paused_by_campaign: by_campaign,
                   last_error: @delivery.error_summary, updated_at: Time.current }
    attributes.merge!(rewind_attributes) if rewind
    @tracking.update_columns(attributes) # rubocop:disable Rails/SkipsModelValidations
  end

  # attempt_count y la repetición como estaban antes del envío que falló.
  def rewind_attributes
    { attempt_count: @delivery.attempt_number - 1, response_adjustments_count: @delivery.repetition }
  end

  def rewindable?
    return false unless latest_delivery?
    return true if @immediate

    REWINDABLE_STATUSES.include?(@tracking.status) && !contact_replied?
  end
end
