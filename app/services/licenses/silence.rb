# ================================================================================
# feat/licencias (F3) — UNA CUENTA SUSPENDIDA NO HABLA SOLA
# ================================================================================
# Decisión 23/10/2026: con la cuenta suspendida (licencia vencida, o suspendida a mano en el
# super admin) los mensajes entran y se guardan, pero nada responde ni envía solo:
#
#   ContactTrackingResponseAnalyzerJob  el Agente IA no contesta
#   ContactTrackingJob                  el primer mensaje se reprograma (no queda fallido)
#   TrackingDispatch::Claim / SendJob   las campañas no toman ni envían; vuelven a la fila
#   Calls::MissedCallService            no manda el mensaje automático de llamada perdida
#
# Al reactivar la cuenta (renovar) todo retoma solo. Un solo lugar decide qué es «callada».
# Plan: docs/licencias_plan_v1.md §5.1
# ================================================================================
module Licenses::Silence
  module_function

  def silenced?(account)
    account.present? && account.suspended?
  end
end
