# frozen_string_literal: true

# Va como `prepend` en ContactTrackingJob (config/initializers/motor2.rb): antes de mandar un toque de una Campaña
# con Vendedor IA, TrackingCampaigns::SendGate decide si sale ahora, espera (horario, tope del día, un mensaje de
# campañas al día por contacto), se pausa (ya lo atiende una persona) o se cancela (baja, campaña terminada). Con
# :aborted el job no cuenta el intento ni lo reprograma (ver CASO 1 en ContactTrackingJob#deliver).
module Motor2::CampaignSendHook
  private

  def deliver(tracking)
    decision = TrackingCampaigns::SendGate.new(tracking).call
    return record_touch(tracking, super) unless decision

    Rails.logger.info "[Motor2::CampaignSendHook] tracking ##{tracking.id}: #{decision[:action]} (#{decision[:reason]})"
    TrackingCampaigns::SendGate.hold!(tracking, decision, previous_attempt_at: tracking.attribute_before_last_save(:last_attempt_at))
    :aborted
  end

  # Campaña con Vendedor IA: la ventana de 24 h con el mismo margen que Motor2::LateMessage (escribir el texto con IA
  # tarda; al filo de las 24 h Meta lo rechaza). Fuera de eso, el toque sale con su plantilla.
  # La apertura con su plantilla sale SIEMPRE con la plantilla aprobada, aunque la ventana esté abierta (todos reciben
  # exactamente el mensaje aprobado; sin texto fijo ni IA). Los toques sí aprovechan la ventana abierta.
  def whatsapp_window_open?(tracking)
    open = super
    return open unless open && tracking.tracking_campaign&.motor2? && tracking.conversation
    return false if Motor2::CampaignTouch.opener?(tracking) && tracking.use_template_for_current_attempt?

    Motor2::LateMessage.window_open?(tracking.conversation)
  end

  # Para «por toque» de los resultados: el número del último toque de la campaña que le salió (los recordatorios del
  # seguimiento corto no cuentan: reinician attempt_count).
  def record_touch(tracking, result)
    return result unless result == true && tracking.tracking_campaign&.motor2?

    state = tracking.motor2_state.to_h
    return result if state['follow_up']

    sent = [state['touches_sent'].to_i, tracking.attempt_count + 1].max
    tracking.update_columns(motor2_state: state.merge('touches_sent' => sent)) # rubocop:disable Rails/SkipsModelValidations
    result
  end
end
