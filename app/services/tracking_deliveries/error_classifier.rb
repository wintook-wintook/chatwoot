# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas
# TrackingDeliveries::ErrorClassifier
# ================================================================================
# Traduce el código de error de Meta (WhatsApp Cloud API) a qué hacer con el envío:
#
#   temporary  Meta o el límite de velocidad: se reenvía el mismo intento con espera.
#   marketing  131049, Meta limitó el marketing a ese usuario: un solo reenvío en 24 h.
#   permanent  el mensaje o el contacto no sirven: no se reenvía. Si el contacto es
#              inalcanzable (UNREACHABLE_CODES) el seguimiento se da por fallido.
#   config     la plantilla, la cuenta o el pago están mal: fallarían todos los envíos,
#              así que se pausa la campaña.
#
# Un código desconocido cuenta como permanente: reintentar a ciegas puede duplicar.
# Referencia: https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes
# ================================================================================
module TrackingDeliveries::ErrorClassifier
  TEMPORARY_CODES = %w[1 2 4 80007 130429 131000 131016 131048 131056 133004 132069].freeze
  MARKETING_CODES = %w[131049].freeze
  CONFIG_CODES = (%w[
    0 3 10 190 368 131031 131037 131042 131045 133010
    132000 132001 132005 132007 132012 132015 132016 132068
  ] + [ContactTrackings::TemplateHeader::MISSING_CODE]).freeze
  # ↑ feat/plantillas_whatsapp_mejoras F5: código propio (no de Meta) para «la plantilla lleva
  #   archivo y no hay uno guardado»: es de configuración, se pausa con el motivo.
  # Permanentes que además dejan al seguimiento sin sentido: el número no tiene
  # WhatsApp o no puede recibir, o el contacto pidió no recibir marketing.
  UNREACHABLE_CODES = %w[131021 131026 131050].freeze

  KINDS = %w[temporary marketing permanent config].freeze

  module_function

  def kind(code)
    code = code.to_s
    return 'permanent' if code.blank?
    return 'temporary' if TEMPORARY_CODES.include?(code)
    return 'marketing' if MARKETING_CODES.include?(code)
    return 'config' if CONFIG_CODES.include?(code) || code.match?(/\A2\d\d\z/) # 200-299: permisos

    'permanent'
  end

  def unreachable?(code)
    UNREACHABLE_CODES.include?(code.to_s)
  end
end
