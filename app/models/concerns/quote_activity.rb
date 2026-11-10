# frozen_string_literal: true

# Plan Actividad del caso — la cotización deja huella en la bitácora de su caso (la
# oportunidad, o el caso del que salió): creada y cada cambio de estado.
module QuoteActivity
  extend ActiveSupport::Concern

  included do
    after_create_commit :log_quote_created, if: :activity_ticket_id
    after_update_commit :log_quote_status, if: -> { activity_ticket_id && saved_change_to_status? }
  end

  private

  def activity_ticket_id
    opportunity_id || origin_ticket_id
  end

  def log_quote_created
    log_quote_event(:quote_created)
  end

  def log_quote_status
    log_quote_event(:quote_status_changed, from: status_before_last_save, to: status,
                                           total: total.to_s, currency: currency)
  end

  def log_quote_event(type, **extra)
    CaseEvent.create!(account_id: account_id, case_ticket_id: activity_ticket_id, event_type: type,
                      origin: Current.user ? :agent : :system, actor: Current.user,
                      payload: { quote_id: id, folio: folio }.merge(extra.compact))
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] bitácora de la cotización #{id}: #{e.message}")
  end
end
