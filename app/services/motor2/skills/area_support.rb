# frozen_string_literal: true

# «Atención a clientes» › Soporte (lo usa Motor2::Skills::AreaActions), para cualquier giro: primero busca la
# solución en las fuentes; si no la hay, levanta el caso, lo pasa al equipo o, si la empresa va a domicilio
# (aire acondicionado, instalaciones…), le agenda una visita técnica. No puede operar → urgente.
module Motor2::Skills::AreaSupport
  URGENT = 'Soporte — no puede operar: es urgente. NO le hagas preguntas: levanta YA su caso con crear_caso (con lo que dijo) y dale el folio.'
  SUPPORT_SEARCH = 'Primero búscalo con buscar_en_fuentes (con lo que dijo y de qué equipo, producto o sistema habla): lo que regrese te dice si ' \
                   'hay solución exacta (dásela tal cual), relacionada (dilo así) o ninguna (dilo y escálalo). Si no se entiende ' \
                   'qué le pasa, pregunta SOLO lo que haga falta para buscarlo (una cosa); nunca preguntes ni supongas causas. '
  SUPPORT_CASE = 'Si no hay solución (o ya la intentó y sigue igual), levanta su caso con crear_caso y dale el folio.'
  SUPPORT_VISIT = 'Si no se resuelve por aquí, ofrécele una visita técnica: pídele su dirección y, si puede, una foto del equipo; ' \
                  'luego ver_horarios y agendar_cita (en las notas: la dirección y la falla). Si no hay horarios, llama canalizar.'

  private

  def support_note
    return URGENT if now['severidad'] == 1 && support_case?

    rest = if support_case?
             SUPPORT_CASE
           elsif function.area('support').to_h['action'] == 'visit'
             SUPPORT_VISIT
           else
             'Si no hay solución (o ya la intentó y sigue igual), llama canalizar.'
           end
    "Soporte#{' — no puede operar: es urgente, no le hagas dar vueltas' if now['severidad'] == 1}. #{SUPPORT_SEARCH}#{rest}"
  end
end
