# frozen_string_literal: true

# diag/llamadas_whatsapp (F2) — errores de una llamada, para que el controlador responda
# cada caso distinto (portado de la v4.19, enterprise/lib/voice/call_errors.rb).
module Voice::CallErrors
  # Meta: el cliente no ha dado permiso para que el negocio le llame.
  NO_CALL_PERMISSION_CODE = 138_006

  class CallFailed < StandardError; end
  class NotRinging < StandardError; end
  # Otro agente ya la contestó (409 en el controlador).
  class AlreadyAccepted < StandardError; end
  # El cliente colgó antes de que el agente contestara (409).
  class CallAlreadyEnded < StandardError; end
  # Hay que pedir permiso al cliente antes de llamarle.
  class NoCallPermission < StandardError; end
end
