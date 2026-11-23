# frozen_string_literal: true

# Motor 2.0 — el seguimiento corto de los tres agentes listos (Functions::Extras#follow_up): si el cliente deja de
# contestar a media plática, el mismo agente lo vuelve a buscar (los líderes insisten de 5 a 11 veces):
#   1. dentro de las 24 h de WhatsApp: 1 o 2 recordatorios a las NUDGE_HOURS de su último mensaje, que escribe el
#      agente retomando lo pendiente (Motor2::Attempt): prospectos, la pregunta; clientes, la aclaración o «¿se
#      resolvió?»; campaña, su duda o la oferta — Motor2::FollowUpJob;
#   2. pasadas las 24 h (solo con plantilla aprobada): las plantillas elegidas, una cada template_days, con el envío
#      de siempre (ContactTrackingJob: el seguimiento queda «scheduled»);
#   3. si nunca contesta (sin plantillas): al final de las 24 h, finish! deja la etiqueta (sin-respuesta o, si se le
#      dio una solución en clientes, resuelto-sin-confirmar) y, en clientes a medio caso, lo pasa al equipo del área.
# Solo si el agente quedó esperando algo (su mensaje pregunta u ofrece RESUELTO / ESCALAR). Si contesta, todo vuelve
# a empezar desde su nuevo mensaje; si ya terminó (calificado, pasado…) no se le busca; si contesta después del
# último toque, el agente lo retoma (revive!).
#
#   memoria: motor2_state['follow_up'] = true, ['follow_up_message'] = id de su último mensaje
module Motor2::FollowUp
  NUDGE_HOURS = [2, 20].freeze
  END_STEP = 99
  END_AFTER = 23.hours

  module_function

  # Después de contestarle: se programa lo que sigue, desde su último mensaje.
  def schedule!(tracking, function, reply = nil)
    plan = plan_for(function)
    return unless plan && waiting_for_answer?(reply) && Motor2::LIVE.include?(tracking.reload.status)

    message = last_message(tracking)
    return unless message

    state = tracking.motor2_state.to_h.merge('follow_up' => true, 'follow_up_message' => message.id)
    tracking.update_columns(status: 'active', scheduled_for: Motor2::InboxRouter::NO_ATTEMPTS.from_now, attempt_count: 0, # rubocop:disable Rails/SkipsModelValidations
                            motor2_state: state, updated_at: Time.current)
    next_step(tracking, message, 0, plan)
  end

  # Lo que eligió la empresa (nil si no da seguimiento).
  def plan_for(function)
    plan = function.respond_to?(:follow_up) ? function.follow_up : nil
    plan if plan && (plan[:nudges].positive? || plan[:templates].any?)
  end

  # El agente quedó esperando algo: preguntó u ofreció RESUELTO / ESCALAR.
  def waiting_for_answer?(reply) = reply.nil? || reply.to_s.include?('?') || reply.to_s.include?('RESUELTO')

  def last_message(tracking) = tracking.conversation&.messages&.incoming&.reorder(:created_at)&.last

  # El recordatorio `step`; si ya no hay, las plantillas o, sin ellas, el cierre al final de las 24 h.
  def next_step(tracking, message, step, plan)
    if step < plan[:nudges]
      Motor2::FollowUpJob.set(wait_until: message.created_at + hours(tracking, NUDGE_HOURS[step])).perform_later(tracking.id, message.id, step)
    elsif plan[:templates].any? && whatsapp?(tracking)
      templates!(tracking, message, plan)
    else
      Motor2::FollowUpJob.set(wait_until: message.created_at + hours(tracking, END_AFTER / 1.hour)).perform_later(tracking.id, message.id, END_STEP)
    end
  end

  # Ya no se le puede escribir libre: sus plantillas o, sin ellas, el cierre sin respuesta (ya, no a las 23 h).
  def after_window(tracking, message, plan)
    return finish!(tracking) unless plan
    return templates!(tracking, message, plan) if plan[:templates].any? && whatsapp?(tracking)

    finish!(tracking)
  end

  # Pasadas las 24 h: el envío de siempre con sus plantillas (una cada template_days).
  def templates!(tracking, message, plan)
    test = test_run?(tracking)
    tracking.update!(status: 'scheduled', attempt_count: 0, max_attempts: plan[:templates].size,
                     whatsapp_templates: plan[:templates], retry_interval_value: plan[:template_days], retry_interval_unit: test ? 'minutes' : 'days',
                     scheduled_for: message.created_at + hours(tracking, 24) + (test ? plan[:template_days].minutes : plan[:template_days].days))
  end

  # Nunca contestó: la etiqueta y, en clientes a medio caso, al equipo del área.
  def finish!(tracking)
    config = Motor2::Config.for(tracking)
    state = tracking.motor2_state.to_h
    solved = state['opciones'].present?
    Motor2::Labels.apply(tracking.conversation, [solved ? 'resuelto-sin-confirmar' : 'sin-respuesta'])
    tracking.update_columns(motor2_state: state.merge('follow_up_done' => true), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    return unless config.function&.key == 'customers' && !solved && state.dig('triage', 'area').to_s.presence_in(%w[support sales admin other])

    Motor2::Outcomes.new(tracking, tracking.conversation, config).apply('handoff', 'Dejó de contestar a media gestión: revisa lo que pidió.')
  end

  # ¿Sigue esperando su respuesta? (no escribió después, nadie del equipo tomó la plática, sigue vivo)
  def waiting?(tracking, message_id)
    return false unless tracking&.status == 'active' && tracking.motor2_state.to_h['follow_up_message'] == message_id

    conversation = tracking.conversation
    conversation.present? && !conversation.resolved? && !conversation.messages.incoming.exists?(['id > ?', message_id]) &&
      !person_wrote_after?(conversation, message_id)
  end

  def person_wrote_after?(conversation, message_id)
    conversation.messages.where(message_type: :outgoing, private: false, sender_type: 'User').where('id > ?', message_id)
                .where("COALESCE(#{AiFollowUp.message_attr_sql('ai_agent')}, '') <> 'true'").exists?
  end

  # Contestó después del último toque: el agente lo retoma.
  def revive!(tracking)
    return unless tracking.status == 'completed' && tracking.motor2_state.to_h['follow_up']

    tracking.update_columns(status: 'active', scheduled_for: Motor2::InboxRouter::NO_ATTEMPTS.from_now, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # El próximo toque (para enseñarlo en la conversación): { at:, kind: 'nudge' | 'template' } o nil.
  def next_touch(tracking)
    state = tracking.motor2_state.to_h
    return nil unless state['follow_up'] && !state['follow_up_done']
    return { at: tracking.scheduled_for, kind: 'template' } if tracking.status == 'scheduled'

    at = next_nudge_at(tracking, state['follow_up_message'])
    at && { at: at, kind: 'nudge' }
  end

  def next_nudge_at(tracking, message_id)
    message = Message.find_by(id: message_id)
    plan = plan_for(Motor2::Config.for(tracking).function)
    return nil unless message && plan && tracking.status == 'active'

    NUDGE_HOURS.first(plan[:nudges]).map { |h| message.created_at + hours(tracking, h) }.find(&:future?)
  end

  # Alguien del equipo lo va a atender: no más toques de este seguimiento.
  def cancel!(tracking)
    state = tracking.motor2_state.to_h.merge('follow_up_done' => true, 'follow_up_message' => nil)
    attrs = { motor2_state: state, updated_at: Time.current }
    attrs.update(status: 'active', scheduled_for: Motor2::InboxRouter::NO_ATTEMPTS.from_now) if tracking.status == 'scheduled'
    tracking.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
  end

  def whatsapp?(tracking) = tracking.inbox&.channel_type.to_s.include?('Whatsapp')

  # «Prueba real» de una campaña: cada hora de espera es un minuto, para verlo completo en un rato.
  def hours(tracking, count) = test_run?(tracking) ? count.minutes : count.hours

  def test_run?(tracking) = tracking.tracking_campaign&.test_run? || false
end
