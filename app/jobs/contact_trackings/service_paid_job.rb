# frozen_string_literal: true

# proyecto@solicitudes (pieza 5, F4) — un caso-servicio movido a la columna «Pagado» del
# Kanban queda en firme (pago parcial: solo ese). Lo encola CaseTicket al cambiar de columna.
class ContactTrackings::ServicePaidJob < ApplicationJob
  PAID_COLUMN = 'pagado'

  queue_as :default

  def perform(case_ticket_id)
    caso = CaseTicket.find_by(id: case_ticket_id)
    return unless paid_service?(caso)

    ContactTrackings::ServiceRequests::PaidService.new(caso.conversation).confirm!([caso])
  end

  private

  def paid_service?(caso)
    caso&.conversation.present? && %w[apartado esperando_pago].include?(caso.metadata['estado']) &&
      I18n.transliterate(caso.case_type_column&.label.to_s).strip.casecmp?(PAID_COLUMN)
  end
end
