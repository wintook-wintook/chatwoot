# frozen_string_literal: true

# feat/ventana_evento_calendario F3 — correos invitados de una tarea agendada (`attendee_emails`):
# sin espacios, en minúsculas y sin repetir. Si alguno está mal escrito se responde 422 antes de
# crear o editar (before_action :reject_invalid_attendee_emails).
module AttendeeEmailsParams
  extend ActiveSupport::Concern

  ATTENDEE_EMAIL = /\A[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+\z/

  private

  def raw_attendee_emails
    Array(params[:attendee_emails]).map { |e| e.to_s.strip.downcase }.compact_blank.uniq
  end

  def clean_attendee_emails
    raw_attendee_emails.grep(ATTENDEE_EMAIL)
  end

  def reject_invalid_attendee_emails
    invalid = raw_attendee_emails.grep_v(ATTENDEE_EMAIL)
    return if invalid.empty?

    render json: { error: I18n.t('agenda_items.invalid_emails', emails: invalid.join(', ')) }, status: :unprocessable_entity
  end
end
