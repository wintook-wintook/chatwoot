# frozen_string_literal: true

# Academia Kontrolya — ¿ya hizo el ejercicio? Se revisa con los datos de verdad.
# Cada check devuelve el registro que lo prueba (queda como evidencia) o nil.
#
# - Lo de conversaciones es trabajo real: cuenta solo lo que hizo él y desde que pulsó «Hazlo»
#   (`since`), para que no valga algo de antes.
# - Contactos y organizaciones no guardan quién los creó: esos ejercicios van sobre su Cliente
#   de práctica (Academy::Practice), que es solo suyo.
#
#   Academy::Checks.new(account:, user:, since:).call('practice_case') → CaseTicket | nil
class Academy::Checks
  CHECKS = %w[reply_sent mention_note practice_contact practice_organization practice_note
              practice_case practice_task practice_stage practice_meeting].freeze
  STAGE_EVENTS = %i[column_changed status_changed stage_advanced].freeze

  def initialize(account:, user:, since:)
    @account = account
    @user = user
    @since = since
    @practice = Academy::Practice.new(account, user)
  end

  def call(check)
    raise ArgumentError, "check desconocido: #{check}" unless CHECKS.include?(check.to_s)

    public_send(check)
  end

  # ── Conversaciones ─────────────────────────────────────────────────────────
  def reply_sent
    my_messages.where(message_type: :outgoing, private: false).first
  end

  def mention_note
    my_messages.where(private: true).where('messages.content LIKE ?', '%(mention://user/%').first
  end

  # ── Contactos (sobre el Cliente de práctica) ───────────────────────────────
  def practice_contact = @practice.contact

  def practice_organization
    @practice.contact&.organization
  end

  def practice_note
    return nil unless @practice.contact

    @practice.contact.notes.where(user_id: @user.id).order(:created_at).last
  end

  # ── Casos (sobre el caso del Cliente de práctica) ──────────────────────────
  def practice_case = @practice.case

  def practice_task
    events(:task_created).first&.case_task || practice_cases_tasks.first
  end

  def practice_stage
    events(*STAGE_EVENTS).first
  end

  def practice_meeting
    return nil unless (ticket = @practice.case)

    ticket.case_meetings.where(organizer_id: @user.id).order(:created_at).first
  end

  private

  def my_messages
    scope = Message.where(account_id: @account.id, sender_type: 'User', sender_id: @user.id)
    @since ? scope.where('messages.created_at >= ?', @since).order(:created_at) : scope.none
  end

  def events(*types)
    return CaseEvent.none unless (ticket = @practice.case)

    CaseEvent.where(case_ticket_id: ticket.id, actor_id: @user.id, event_type: types).order(:created_at)
  end

  # Las tareas creadas por él en el caso de práctica (si el evento no se registró).
  def practice_cases_tasks
    return CaseTask.none unless (ticket = @practice.case)

    ticket.case_tasks.where(requester_id: @user.id).order(:created_at)
  end
end
