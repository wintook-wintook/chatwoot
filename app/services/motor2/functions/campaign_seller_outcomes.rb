# frozen_string_literal: true

# «Vendedor de campaña» — lo que pasa cuando el agente decide (Motor2::Outcomes lo llama):
#   relay     (le_interesa)             → Motor2::Relay: al agente que sigue o a una persona
#   discarded (no_le_interesa)          → nota con el motivo; el seguimiento se cierra (no más toques)
#   done      (confirmó / no va / terminó la encuesta) → nota y cumplido; encuesta con calificación baja → caso
#   handoff   (pasar_a_humano)          → nota, se asigna a la persona o equipo y el agente se pausa
#   later     (mas_adelante)            → un solo toque más en N días (a su hora hábil); si no contesta, termina
#   booked    (agendó la cita)          → nota, se asigna a quien la atiende y cumplido
#   achieved  (ya_lo_hizo / confirmó)   → nota, etiqueta «lo logró» al contacto y cumplido
#   not_now   (no_esta_vez)             → nota; ya no hay más toques y se espera si acepta la próxima
#   future_yes (futuras: sí)            → etiqueta «volver a…» (quita la de «no…») y termina
#   opt_out   (no_contactar / futuras: no) → etiqueta «no…» (quita la de «volver a…»); la siguiente campaña del mismo
#                                          tipo ya no lo inscribe (TrackingCampaigns::Enroll)
class Motor2::Functions::CampaignSellerOutcomes
  def initialize(tracking, conversation, function)
    @tracking = tracking
    @conversation = conversation
    @function = function
    @template = tracking.tracking_template
  end

  HANDLERS = { 'discarded' => :discarded, 'done' => :done, 'handoff' => :handed_off, 'later' => :later, 'achieved' => :achieved,
               'not_now' => :not_now, 'future_yes' => :future_yes, 'opt_out' => :opt_out }.freeze

  def apply(kind, text)
    return Motor2::Relay.new(@tracking, @conversation, @function).call(text) if kind == 'relay'

    send(HANDLERS[kind], text) if HANDLERS.key?(kind)
  rescue StandardError => e
    Rails.logger.error("[Motor2::CampaignSellerOutcomes] #{e.class}: #{e.message}")
    @tracking.update_columns(last_error: "#{kind}: #{e.message}".first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def booked(meeting)
    when_text = Motor2::Skills::Appointments.label(meeting.starts_at.in_time_zone(@function.config.zone))
    note("Le interesó y agendó: #{when_text} con #{meeting.organizer&.name}.")
    @conversation.update!(assignee_id: meeting.organizer_id) if @conversation.assignee_id.blank? && meeting.organizer_id
    label('achieved')
    finish("Cita #{when_text}")
  end

  def note(text)
    return if @conversation.nil? # encuesta contestada desde el correo, antes de que haya plática

    Motor2::Delivery.note(@tracking, @conversation, "🤖 #{@template.name}: #{text}")
  end

  private

  def state = @tracking.motor2_state.to_h

  # La etiqueta de ese resultado al contacto (la de la campaña o la de fábrica); quita la contraria.
  def label(key)
    opposite = { 'future_yes' => %w[opt_out], 'opt_out' => %w[future_yes], 'achieved' => %w[opt_out] }[key]
    TrackingCampaigns::ContactLabels.apply(@tracking.contact, add: @function.label_for(key), kind: key,
                                                              remove: opposite.map { |k| @function.label_for(k) })
  end

  def achieved(text)
    note("🎯 Lo logró: #{text}")
    label('achieved')
    verify_payment(text) if @tracking.contract
    finish("Logrado: #{text}")
  end

  # Recordar: «ya pagué» lo dice el cliente; queda una tarea para que el responsable del contrato lo verifique.
  def verify_payment(text)
    contract = @tracking.contract
    owner = contract.assignee || @tracking.tracking_campaign&.user
    CaseTask.create!(account: contract.account, requester: owner, assignee: owner, contact: contract.contact,
                     title: "Verificar pago: #{contract.title}".first(255), due_at: 1.day.from_now,
                     description: "El cliente dice que ya pagó (campaña #{@tracking.tracking_campaign&.name}): #{text}".first(2000))
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[CampaignSellerOutcomes] tarea de pago #{@tracking.id}: #{e.message}")
  end

  # «No esta vez»: ya contestó (no salen más toques); se queda esperando si acepta que le escriban la próxima.
  def not_now(reason)
    note("No esta vez: #{reason}. Se le preguntó si le escribimos la próxima.")
    @tracking.update_columns(outcome: 'not_now', motor2_state: state.merge('exit_reason' => reason.to_s.first(200)), # rubocop:disable Rails/SkipsModelValidations
                             updated_at: Time.current)
  end

  def future_yes(text)
    note("Acepta que le escribamos la próxima#{": #{text}" if text.present?}.")
    label('future_yes')
    @tracking.update_columns(outcome: 'future_yes', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.cancel!
  end

  def opt_out(reason)
    note("No quiere que le escribamos de esto#{": #{reason}" if reason.present?}.")
    label('opt_out')
    discarded_columns(reason.presence || state['exit_reason'] || 'No quiere que le escribamos')
    @tracking.cancel!
  end

  def discarded_columns(reason)
    # El motivo queda en su memoria para «En qué se van» de la campaña (Motor2Results).
    @tracking.update_columns(outcome: 'discarded', motor2_state: state.merge('exit_reason' => reason.to_s.first(200)), # rubocop:disable Rails/SkipsModelValidations
                             updated_at: Time.current)
  end

  def discarded(reason)
    note("No le interesa: #{reason}")
    discarded_columns(reason)
    @tracking.cancel!
  end

  def done(text)
    return survey_done if @function.survey?

    note(text)
    finish(text)
  end

  # Las respuestas en la nota; con una calificación baja, un caso para que alguien lo atienda.
  def survey_done
    answers = survey_lines
    low = low_scores.any?
    note(["Contestó la encuesta#{' — calificación baja' if low}:", *answers].join("\n"))
    label('achieved')
    ticket = low && @conversation ? low_score_case(answers) : nil
    finish(ticket ? "Encuesta baja: caso #{ticket.try(:folio) || ticket.id}" : 'Encuesta contestada')
  end

  def survey_lines
    @function.survey_questions.each_with_index.map do |q, i|
      "• #{q}: #{state.dig('survey', (i + 1).to_s).to_h['respuesta'] || '—'}"
    end
  end

  def low_scores
    state['survey'].to_h.select { |number, v| @function.low_answer?(number, v['calificacion']) }.values
  end

  def low_score_case(answers)
    low_case = @function.answer(:low_case).to_h
    type_id = low_case_type(low_case['case_type_id'])
    target = low_case['user_id'] || low_case['team_id'] ? { user_id: low_case['user_id'], team_id: low_case['team_id'] } : @function.handoff_target
    Cases::OrchestratorService.new(account: @conversation.account, contact: @conversation.contact, conversation: @conversation)
                              .create_for_manual(title: "Encuesta con calificación baja: #{@conversation.contact&.name}".first(200),
                                                 description: answers.join("\n"), case_type_id: type_id,
                                                 priority: low_case['priority'] || 'high',
                                                 assignee_id: target[:user_id], team_id: target[:team_id])
  end

  # El tipo de caso que eligió la encuesta o, si no, el primero de soporte.
  def low_case_type(id)
    types = @conversation.account.case_types.active
    (id && types.where(id: id).pick(:id)) || types.where(case_class: :support).order(:id).pick(:id)
  end

  # «Ahora no»: un toque más en N días. En WhatsApp, pasadas las 24 h solo sale con plantilla: si ese toque no tiene,
  # va la del último toque de la campaña. En «Prueba real», N minutos.
  def later(text)
    days, reason = text.to_s.split('|', 2)
    days = days.to_i.clamp(1, Motor2::Skills::Campaign::MAX_LATER_DAYS)
    campaign = @tracking.tracking_campaign
    at = campaign&.test_run? ? days.minutes.from_now : later_time(campaign, days.days.from_now)
    note("Pidió que le escriban más adelante (#{days} días#{": #{reason}" if reason.present?}).")
    @tracking.update_columns(later_attributes(at, days)) # rubocop:disable Rails/SkipsModelValidations
    ContactTrackingJob.set(wait_until: at).perform_later(@tracking.id) unless TrackingDispatch.enabled_for?(@tracking.account_id)
  end

  def later_time(campaign, time)
    campaign ? TrackingCampaigns::Schedule.new(campaign).next_send_time(time) || time : time
  end

  def later_attributes(at, days)
    next_touch = @tracking.attempt_count + 1
    templates = Array(@tracking.whatsapp_templates)
    templates = templates.dup.tap { |list| list[next_touch - 1] = list.compact_blank.last } if templates.any? && templates[next_touch - 1].blank?
    { status: 'scheduled', scheduled_for: at, max_attempts: next_touch, whatsapp_templates: templates, outcome: 'later',
      motor2_state: state.merge('later_days' => days, 'follow_up' => nil), updated_at: Time.current }
  end

  def handed_off(reason)
    note("Pasa a una persona: #{reason}")
    assign(@function.handoff_target)
    Motor2::AttendClock.start(@tracking, @conversation, @function)
    @tracking.update_columns(outcome: 'handed_off', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    @tracking.pause!
  end

  def finish(text)
    @tracking.mark_objective_met!
    @tracking.update_columns(outcome: text.to_s.first(250), updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def assign(target) = Motor2::HandoffAssign.call(@conversation, target, tracking: @tracking)
end
