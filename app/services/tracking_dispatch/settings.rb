# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: configuración del despachador
# ================================================================================
# El despachador (TrackingDispatch::DispatchJob) reemplaza al job programado por
# seguimiento. Se enciende por cuenta, para desplegarlo poco a poco (plan §13, paso 2.10):
#
#   TRACKING_DISPATCHER_ACCOUNTS=568,612    solo esas cuentas
#   TRACKING_DISPATCHER_ACCOUNTS=all        todas
#   (vacía o sin definir)                    ninguna: todo sigue como antes
#
# Límites (por número de WhatsApp = inbox):
#   TRACKING_DISPATCH_PER_INBOX_PER_MINUTE   envíos por minuto (600 = 10/s; Meta permite 80/s)
#   TRACKING_DISPATCH_PER_INBOX_PER_ROUND    cuántos toma de cada inbox por vuelta (reparto
#                                            justo: uno con 2,000 no tapa a otro con 50)
#   TRACKING_DISPATCH_MAX_PER_ROUND          tope de toda la vuelta
# El tope diario por nivel de Meta (250 / 1K / 10K / 100K) sale de TrackingDispatch::MessagingTier.
# ================================================================================
module TrackingDispatch::Settings
  module_function

  def enabled_for?(account_id)
    accounts = ENV.fetch('TRACKING_DISPATCHER_ACCOUNTS', '').strip
    return false if accounts.blank? || account_id.blank?
    return true if accounts.casecmp('all').zero?

    accounts.split(',').map(&:strip).include?(account_id.to_s)
  end

  # Cuentas para filtrar en SQL: :all, o la lista de ids (vacía = ninguna).
  def account_scope
    accounts = ENV.fetch('TRACKING_DISPATCHER_ACCOUNTS', '').strip
    return :all if accounts.casecmp('all').zero?

    accounts.split(',').map(&:strip).reject(&:blank?).map(&:to_i)
  end

  def per_inbox_per_minute
    ENV.fetch('TRACKING_DISPATCH_PER_INBOX_PER_MINUTE', 600).to_i
  end

  def per_inbox_per_round
    ENV.fetch('TRACKING_DISPATCH_PER_INBOX_PER_ROUND', 50).to_i
  end

  def max_per_round
    ENV.fetch('TRACKING_DISPATCH_MAX_PER_ROUND', 500).to_i
  end
end
