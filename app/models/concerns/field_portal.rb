# Plan-Trabajo-Campo R5 — lo que el cliente y un técnico externo hacen desde su
# enlace, sin usuario:
#
# - El cliente (portal `/servicio/:report_token`) confirma su visita o pide otra
#   fecha (`visit_response`) y, ya terminada la orden, califica el servicio (CSAT).
#   Cada respuesta queda como nota en el historial del caso.
# - Un técnico externo recibe un enlace (`/tecnico/:external_token`) que sirve
#   hasta que termina la visita o vence (EXTERNAL_LINK_TTL).
module FieldPortal
  extend ActiveSupport::Concern

  VISIT_RESPONSES = %w[confirmed reschedule].freeze
  EXTERNAL_LINK_TTL = 7.days

  def next_visit
    case_meetings.active.where(ends_at: Time.current..).order(:starts_at).first
  end

  def respond_to_visit!(status, note: nil, preferred: nil)
    raise ArgumentError, status unless VISIT_RESPONSES.include?(status.to_s)

    visit = next_visit
    update!(visit_response: { 'status' => status.to_s, 'note' => note.presence, 'preferred' => preferred.presence,
                              'meeting_id' => visit&.id, 'starts_at' => visit&.starts_at&.iso8601,
                              'at' => Time.current.iso8601 }.compact)
    portal_note!(I18n.t("field_portal.notes.#{status}", when: [preferred, note].compact_blank.join(' · ').presence || '—'))
  end

  # La respuesta vale para la visita que estaba agendada; si se movió de hora o es otra, ya no.
  def visit_response_current
    response = visit_response || {}
    visit = next_visit
    return {} if response.blank? || response['meeting_id'] != visit&.id
    return {} if visit && response['starts_at'] != visit.starts_at.iso8601

    response
  end

  # Ya no hay visita que confirmar: terminada o cancelada.
  def completed_for_portal?
    ServiceReportable::COMPLETION_STATUSES.include?(status) || status == 'cancelled'
  end

  def rateable?
    ServiceReportable::COMPLETION_STATUSES.include?(status) && csat_rating.nil?
  end

  def rate_service!(rating, comment = nil)
    raise ActiveRecord::RecordInvalid, self unless rateable? && (1..5).cover?(rating.to_i)

    update!(csat_rating: rating.to_i, csat_comment: comment.presence, csat_at: Time.current)
    portal_note!(I18n.t('field_portal.notes.rated', rating: rating.to_i, comment: comment.presence || '—'))
  end

  def issue_external_link!(name:, phone: nil)
    update!(external_technician: { 'name' => name, 'phone' => phone.presence }.compact,
            external_token: SecureRandom.base58(24), external_token_expires_at: EXTERNAL_LINK_TTL.from_now)
    external_token
  end

  def external_link_active?
    external_token.present? && external_token_expires_at&.future? &&
      ServiceReportable::COMPLETION_STATUSES.exclude?(status)
  end

  # Un solo uso: al terminar la visita el enlace deja de servir.
  def close_external_link!
    update_columns(external_token: nil, external_token_expires_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def portal_note!(content)
    case_events.create!(account: account, event_type: :internal_note, origin: :system,
                        payload: { field: 'portal', content: content })
  end
end
