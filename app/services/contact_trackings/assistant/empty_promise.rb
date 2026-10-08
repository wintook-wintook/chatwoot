# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — NI PREGUNTÓ NI ENTREGÓ (26/09/2026)
# ================================================================================
# Medido pidiendo rutas en lenguaje natural (2 de 5 corridas): «Voy a agregar la ruta…» o
# «necesito confirmar algunos detalles.» sin ninguna pregunta y con "entrenamiento": null.
# La persona se queda esperando algo que no viene. Se le da UNA vuelta más.
#
# Solo al editar (al armar desde cero, la entrevista pregunta y avanza sola) y no en un
# pedido de análisis, que contesta sin entregar a propósito.
# ================================================================================

module ContactTrackings::Assistant::EmptyPromise
  module_function

  # La respuesta con la que sigue el turno: la segunda si hizo falta y llegó, si no la misma.
  # El bloque recibe lo que se agrega a la conversación y devuelve la respuesta del modelo.
  def second_try(reply, said:, editing:)
    return reply unless editing && empty?(reply, said: said)

    extra = [{ role: 'assistant', content: { mensaje: reply['mensaje'], entrenamiento: nil }.to_json },
             { role: 'user', content: ContactTrackings::Assistant::RepairPrompts.t('repair.empty_promise') }]
    ContactTrackings::Assistant::ReplyParser.with_extras(yield(extra)) || reply
  end

  def empty?(reply, said:)
    return false if reply['entrenamiento'].present?
    return false if ContactTrackings::Assistant::ReplyParser.options(reply).present?
    return false if said.to_s.match?(ContactTrackings::Assistant::CheckerSection::ANALYSIS_RE)

    reply['mensaje'].to_s.exclude?('?')
  end
end
