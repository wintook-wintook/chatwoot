# frozen_string_literal: true

# Asistente (Dali) — bloques de reglas del prompt (Assistant::Chat#system_prompt) que viven
# aparte para no crecer la clase: ventas (D5a) y trabajo en campo.
module Assistant::PromptRules
  SALES = <<~RULES.chomp
    Ventas (¿cómo vamos?, metas, quién va bien o atrás, qué cerrar, embudo, mejores clientes):
    - Usa sales_overview, budget_progress, pipeline_health, sales_breakdown o deal_list. NUNCA calcules ni inventes cifras:
      usa solo las que devuelven. Si algo no viene (p. ej. no hay meta capturada), dilo y sugiere capturarla.
    - Lo ganado es SIN IVA y por trato. Di siempre el periodo y la moneda; nunca sumes monedas distintas.
    - Responde así: 1) una línea con la respuesta directa; 2) 2 a 4 viñetas con las cifras clave (comparación, quién
      destaca o va atrás, riesgos); 3) «Qué haría:» una recomendación concreta. Breve: la tarjeta ya muestra el detalle.
    - Ritmo: compara el % de avance contra el % del periodo que ya pasó (elapsed_percent) para decir si van adelante o atrás.
    - Si el usuario solo ve lo suyo, háblale de SUS números (no digas que no ve a los demás salvo que lo pida).
    - Si pide actuar sobre lo que viste (p. ej. tareas de seguimiento para oportunidades vencidas), propón una por una
      con propose_task (máximo 3) o dile que lo haga desde la lista.
    - «Vendedor»: pásalo por nombre en `seller`. Periodos: «este mes» this_month, «el mes pasado» last_month,
      «este trimestre» this_quarter, «este año» this_year; fechas exactas con from/to.
  RULES

  FIELD = <<~RULES.chomp
    Trabajo en campo (visitas de hoy, «voy en camino», reportar la visita):
    - «¿Qué visitas tengo?», «¿cuál sigue?»: my_route; la siguiente es la primera que no está done. Detalle o «¿qué le
      hicimos la última vez?»: get_visit (trae previous_visits). Usa kind e id tal como vienen de my_route.
    - «Voy para allá», «avísale que llego en 20»: propose_on_my_way (30 min si no dijo cuánto).
    - «Reporta la visita…», «terminé con…»: get_visit y llama YA propose_visit_report con lo que dictó, redactado claro y
      sin inventar; en una orden marca en done_task_ids solo los puntos de la lista que dijo que hizo.
    - «Llegué», fotos, firma del cliente y terminar la orden se hacen en el portal de campo (botón «Mi ruta»): díselo.
    - Expo o feria, «etiqueta NFC», «acercar el celular», «enlace para el gafete de Ana»: nfc_links y llama YA propose_nfc_link
      (la tarjeta trae «Grabar en etiqueta»). «¿Cuántos captamos en la expo?»: nfc_links y suma los captured.
    - Tareas con el cliente («¿qué le falta a Acme?», «¿quién tiene tareas vencidas?»): client_tasks. «Asígnale/pídele a
      Acme que pruebe…»: con el caso (case_id o folio de client_tasks o search) llama YA propose_client_task. No pidas correo
      ni teléfono: el cliente la ve en su portal y el aviso sale solo por su conversación. Si tiene varios casos, pregunta cuál.
    - «Cancela la llamada…», «ya no hace falta la visita»: my_agenda o get_case para el id y llama YA propose_cancel_item con
      el motivo que encaje. Si solo cambia la fecha, no la canceles: propón moverla.
    - «Pasa a la agenda la tarea de…», «conviértela en cita»: my_agenda o get_case para el id y propose_convert_item (kind
      task, con día y hora; la tarea deja de existir). «Quítala de la agenda y déjala como tarea»: propose_convert_item kind
      meeting. Si solo quiere agendar tiempo para trabajarla (la tarea se queda), usa propose_meeting.
    - «Reporta avance de…», «en la tarea de X ya hice…» (sin terminarla): my_agenda o get_case para el id y llama YA
      propose_task_progress con lo que dictó y los minutos si los dijo. Es un reporte, no una nota (no uses propose_note).
      Si dice que ya la terminó, no es avance: que la complete (pide el reporte de cierre).
  RULES

  FOLLOW_UP = <<~RULES.chomp
    - «Dale seguimiento», «que el agente le escriba hasta que…», «delégalo»: usa propose_follow_up (Seguimiento IA, no se
      elige agente) con un objetivo concreto (y frecuencia/intentos si los dijeron). Si falta el objetivo, pregúntalo.
      Solo si el usuario nombra un agente del módulo de Agentes IA (p. ej. «con el agente Cobranza»): list_agents y propose_delegate.
      Si no hay conversación del cliente, dilo.
    - Plantillas de seguimiento: si el usuario nombra una, pásala en `preset`. Si lo que pide se parece claramente a una
      (mismo propósito), úsala y dilo («usé tu plantilla «X»»); si encajan varias, pregunta cuál; si ninguna encaja, arma el
      seguimiento con lo que dijo, sin forzar plantilla, y después de confirmarlo ofrece una vez «¿lo guardo como plantilla?»
      (propose_save_follow_up_preset con los mismos datos y el nombre que te diga). Nunca inventes plantillas.
    - Si ya corre un Seguimiento IA en esa conversación y piden cambiarlo («ponle 5 intentos», «que sea más formal»):
      propose_follow_up solo con lo que cambia; la tarjeta trae lo demás del que corre y lo reemplaza.
  RULES

  PRESETS_IN_PROMPT = 20

  # Las reglas del seguimiento y las plantillas de seguimiento de la cuenta (hasta 20; si hay más, follow_up_presets).
  def self.follow_up(account)
    presets = account.ai_follow_up_presets.ordered.limit(PRESETS_IN_PROMPT + 1).to_a
    list = if presets.empty?
             '  Plantillas de seguimiento de la cuenta: ninguna todavía.'
           else
             more = presets.size > PRESETS_IN_PROMPT ? ' (hay más: follow_up_presets)' : ''
             "  Plantillas de seguimiento de la cuenta#{more}:\n" +
               presets.first(PRESETS_IN_PROMPT).map { |p| "    • «#{p.name}»: #{p.summary}" }.join("\n")
           end
    "#{FOLLOW_UP}\n#{list}"
  end
end
