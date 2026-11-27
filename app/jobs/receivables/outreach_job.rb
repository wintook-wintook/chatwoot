# frozen_string_literal: true

# Cobranza — cada hora: los agentes de cobranza con «Cobrar solo» prendido cuya hora de envío es esta (en el horario de su
# bandeja) cobran a quien le toca (Receivables::Outreach). Antes revisa las promesas de pago de la cuenta.
class Receivables::OutreachJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(now = Time.current)
    TrackingTemplate.where(agent_function: Motor2::Functions::Collections::KEY, archived_at: nil).find_each do |template|
      next unless due?(template, now)

      Receivables::Promises.reconcile(template.account, today: local(template, now).to_date)
      result = Receivables::Outreach.new(template, now: now).call
      Rails.logger.info("[Receivables::OutreachJob] agente #{template.id}: #{result}")
    rescue StandardError => e
      Rails.logger.error("[Receivables::OutreachJob] agente #{template.id}: #{e.class}: #{e.message}")
    end
  end

  private

  def due?(template, now)
    answers = template.motor2.to_h['answers'].to_h
    return false unless answers['outreach_on'] == true

    time = local(template, now)
    return false if answers['weekdays_only'] != false && (time.saturday? || time.sunday?)

    time.hour == (answers['send_hour'].presence || 10).to_i
  end

  def local(template, now) = now.in_time_zone(template.inbox&.timezone.presence || 'America/Mexico_City')
end
