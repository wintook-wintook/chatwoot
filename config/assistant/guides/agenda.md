---
key: agenda
title: Agenda, tareas y reportes
areas: [agenda]
keywords: [agenda, agendar, agendar tarea, agendo, como agendo, tarea, tareas, mi dia, dia de, dia de otro, ver el dia de, mi dia de otro usuario, supervisar, mi orden de hoy, pasar a manana, completar, concluir, hecho hoy, tarea agendada, cita, llamada, visita, reporte, reporte de cierre, reportar actividad, reportar avance, avance, ver reportes, historial, historial de la tarea, ver historial, tiempo dedicado, minutos, horas, llegadas, mi ruta, puntaje de tareas, mias, no asignadas, vencidas, programada, cancelar, cancelar tarea, cancelar cita, motivo de cancelacion, reabrir, sin responsable, sin asignar, borrar tarea, no puedo borrar, reprogramar, solicitante, prioridad, duracion estimada, programada para, plan de mi dia, siguiente, exportar csv, evidencia, buscar tarea, participantes, participas, invitar compañero, con quien voy, no puedo ir, ocupado a esa hora]
pages: [tasks, agenda, my_day, calendar, task_reports, field_route, task_outcomes, task_scoring, case]
sources:
  - app/javascript/dashboard/views/gestorTickets/Tasks.vue
  - app/javascript/dashboard/views/gestorTickets/TaskReports.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/*.vue
  - app/javascript/dashboard/components/cancel/*.vue
  - app/javascript/dashboard/components/convert/*.vue
  - app/controllers/api/v1/accounts/case_tasks_index_controller.rb
  - app/controllers/api/v1/accounts/task_reports_controller.rb
  - app/controllers/api/v1/accounts/task_histories_controller.rb
  - app/javascript/dashboard/components/agenda/ParticipantsPicker.vue
  - app/services/cases/meetings/participants.rb
reviewed: 2026-11-23
---
## Para qué sirve
La Agenda junta todo lo que tienes que hacer: tareas (con fecha, sin hora) y tareas agendadas (con hora: llamadas, reuniones, visitas), y lo que ya se hizo, con su reporte.

## Dónde está
- Agenda › Tareas: pestañas Mi día, Mías, No asignadas y Todas. Abre en Mi día. Mi día también está en Inicio › Mi resumen. Arriba a la derecha, el botón «Nueva tarea».
- Agenda › Calendario (si tu empresa lo tiene): ver la guía del calendario.
- Agenda › Reportes: pestañas Reportes y Llegadas.
- Agenda › Mi ruta en campo: la pantalla para celular de quien sale a visitas.

## Cómo se hace
### Trabajar Mi día
1. Entra a Agenda › Tareas › Mi día. Arriba ves «Para hoy: N tareas» (o «Nada vence hoy»), su tiempo estimado, cuántas no tienen estimado, cuántas pendientes hay en total y cuántas están programadas para después. Puedes filtrar por tipo de caso («Todos los tipos»).
2. «Sugeridas por prioridad» trae tus pendientes ordenadas por un puntaje, con el motivo de su lugar (vencida, vence hoy, SLA en riesgo, visita hoy, caso en espera…).
3. Arma «Mi orden de hoy»: arrastra tareas ahí o pulsa la flecha ↑ («Agregar a mi orden de hoy») y reordénalas arrastrando; «Quitar de mi orden de hoy» la saca. La primera queda como «Siguiente».
4. La tarea «Siguiente» trae los botones «Completar», «Reportar avance», «Ver historial», «Abrir caso» (si tiene caso) y «Pasar a mañana» (la programa para el día siguiente). En las demás, un clic abre la tarea para editarla y el ícono de reloj abre su historial.
5. Si tu empresa tiene la inteligencia artificial de casos activa, «Plan de mi día con Dali» te sugiere en qué orden hacer tus tareas y cuáles «Puede esperar a mañana». Es solo una sugerencia: no cambia tu orden. «Volver a generar» arma otro.
6. A la derecha están la «Agenda de hoy» (tus tareas agendadas) y «Hecho hoy» (lo que ya concluiste). La palomita de una tarea agendada la completa: llenas el reporte de cierre y eliges si se realizó o el cliente no asistió. Un clic en la cita abre su caso (o su contacto).
7. Si quedaron tareas programadas sin hacer, sale un aviso con «Pasarlas a hoy» o «Ignorar». Si llega una urgente después de armar tu día, te avisa con «Subir al inicio».

### Ver el Mi día de otra persona
1. En Agenda › Tareas › Mi día, junto a «Actualizar», elige a la persona en «Día de:» («Mío» es el tuyo). Solo sale si tu rol ve la Agenda de todos (Administrador, Supervisor).
2. Ves su día tal como lo ve ella: sus pendientes en el orden sugerido, «Su orden de hoy», su agenda de hoy y lo que hizo hoy. Arriba dice «Estás viendo el día de …».
3. Es solo para ver: no puedes armarle ni cambiarle su orden, pasar sus tareas a mañana, completarlas ni reportar su avance. Puedes abrir cada tarea, su caso y su historial.
4. Para regresar a tu día elige «Mío»; al recargar la página vuelves al tuyo.

### Ver y filtrar tareas
1. Usa las pestañas Mías, No asignadas o Todas.
2. Filtra por estado (Pendientes, Completadas, Todos los estados), por tipo (Todas, No agendadas, Agendadas), por tipo de caso («Todos los tipos»), por vencimiento (Cualquier fecha, Vencidas, Vencen hoy, Esta semana) y por solicitante («Solicitante: todos»); en Todas, también por responsable («Responsable: todos»).
3. Busca en «Buscar en el título o la descripción…». El botón de flechas («Actualizar») recarga la lista sin perder los filtros. Cada pestaña recuerda sus filtros.
4. La tabla muestra Folio (T001…), Caso, Tarea, Prioridad, Solicitante, Responsable, Vence, Programada y Estado (con «Completar» en las pendientes). Un clic en una tarea la abre para editarla; si está concluida, cancelada o su caso está cerrado, se abre en modo lectura («Ver tarea»). Un clic en una tarea agendada abre su caso.
5. Si nada coincide sale «No hay tareas que coincidan con los filtros.».

### Editar una tarea
1. Haz clic en la tarea o elige «Editar» en su menú ⋮. Se abre «Editar tarea».
2. Puedes cambiar «Título», «Solicitante» (solo si la tarea no lo tenía), «Responsable», «Descripción (opcional)», «Vence», «Programada para» (el día que piensas hacerla; si queda después del vencimiento avisa «Queda después del vencimiento: se entregará tarde.»), «Prioridad», «Duración estimada» y «Estado».
3. Si tu empresa tiene la IA de casos, abajo de la descripción hay botones para corregir o mejorar el texto (y deshacerlo).
4. Pulsa «Guardar». Si el caso está cerrado no se puede modificar: reábrelo primero.

### Crear una tarea
1. Pulsa «Nueva tarea» en Agenda › Tareas, o «Tarea» en la barra de arriba.
2. Llena «Qué hay que hacer» y, si quieres, «Descripción (opcional)», «Responsable», «Fecha programada», «Hora (opcional)» y «Fecha de vencimiento».
3. Sin hora es una tarea. Con hora es una tarea agendada: va al calendario y, si el responsable conectó Google, a su Google Calendar.
4. Para una visita marca «Es una visita al cliente» (pide fecha y hora; la dirección es opcional).
5. Elige organización o contacto si es para un cliente, y su caso en «Caso (opcional)». Sin contacto ni organización se ve solo en Mi día.
6. Pulsa «Crear tarea».

### Concluir con reporte
1. Pulsa «Completar» en la tarea. Se abre el «Reporte de cierre».
2. Escribe «Qué se hizo», el Tiempo dedicado, el Resultado y, si quieres, evidencia (hasta 5 archivos).
3. Pulsa «Concluir». El reporte queda en Agenda › Reportes, en la ficha del cliente y, si tiene caso, en su actividad; el tiempo suma a las horas del caso.
4. El tiempo que te propone es lo estimado de la tarea menos lo que ya reportaste en sus avances.

### Reportar avance de una tarea (sin completarla)
Para lo que hiciste en una tarea que sigue pendiente (una llamada, una parte del trabajo).
1. En el menú ⋮ de la tarea pulsa «Reportar avance» (dentro del caso o en Agenda › Tareas); en Mi día es el botón «Reportar avance» de la tarea. También desde «Reportar actividad» de la barra de arriba: elige el cliente y su caso, y en «Tarea (opcional)» la tarea.
2. Escribe «Qué se hizo», ajusta fecha y hora, el tiempo dedicado y, si quieres, resultado y evidencia. Pulsa «Guardar avance».
3. La tarea sigue pendiente. El avance es un reporte, no una nota: sale en el historial de la tarea (filtro Reportes, con el tiempo reportado contra lo estimado), en Agenda › Reportes como «Avance», en la ficha del cliente y en la actividad del caso; su tiempo suma ya a las horas del caso. No sale en la pestaña Notas.
4. También se lo puedes pedir a Dali: «reporta avance de la T003: llamé al proveedor, 20 minutos».

### Guardar una tarea sin responsable
Al guardar una tarea (dentro del caso o al editarla en Agenda › Tareas) con «— Sin asignar —», te pregunta antes: «La tarea no tiene responsable: no le aparecerá a nadie en su Mi día. ¿Guardarla sin asignar?». «Elegir responsable» te regresa a la lista de responsables; «Guardar sin asignar» la guarda así. Si la tarea ya estaba sin responsable, o es una tarea del cliente, no pregunta.

### El menú de cada tarea
Son los tres puntos ⋮ al final de la fila; siempre se ven, aunque la tabla se mueva de lado. Arriba van las acciones, solo las que se pueden hacer según el estado:
- Pendiente: «Reportar avance» (la primera), «Editar», «Agregar nota», «Pasar a la agenda», «Cancelar…» y «Eliminar». Dentro del caso sale además «Agendar tarea», después de «Editar».
- Concluida o cancelada: «Ver», «Agregar nota», «Reabrir» y «Eliminar». Una tarea concluida o cancelada no se edita: se ve en modo lectura (la cancelada, con su motivo). Para cambiarle algo, primero «Reabrir»: regresa a pendiente y conserva su reporte.
«Eliminar» solo sale si la creaste tú en las últimas 24 horas o eres administrador. Abajo de la línea va «Ver historial»: todo lo de la tarea en un solo lugar. Si no cabe hacia abajo, el menú se abre hacia arriba.

### Historial de la tarea
1. Ábrelo con «Ver historial» en el menú ⋮ de la tarea, con un clic en su folio (T004) dentro del caso, con el botón «Ver historial» en Mi día, o con un clic en la tarea en la ficha del contacto (también las tareas sin caso).
2. Arriba: estado, responsable, vence, programada y el tiempo reportado contra lo estimado («1 h 30 min de 2 h estimado»), y el caso o el cliente.
3. Botones (con la tarea pendiente): «Reportar avance», «Agregar nota», «Agendar» y «Completar». En la ficha del contacto solo «Reportar avance». En una tarea del cliente no sale «Reportar avance». En Agenda › Tareas, «Agendar» te lleva al caso para agendarla; si no tiene caso, abre «Pasar a la agenda».
4. Abajo, por día, todo lo que pasó: se creó, cambios de vencimiento, notas, reportes de avance y de cierre (con tiempo, resultado y evidencia), sus tareas agendadas (agendada, movida, realizada, no asistió o cancelada, con su reporte), lo que hizo el cliente en su portal y si se completó, canceló o reabrió.
5. Filtros: Todo, Notas, Reportes, Agendadas, Cliente y Cambios, con cuántos hay de cada uno.
6. También se lo puedes pedir a Dali: «¿cómo va la T004?».

### Tareas agendadas del caso: completar y su menú
1. En la columna Estado de una tarea agendada pulsa «Completar». El reporte de cierre pregunta «¿Cómo terminó?»: «Se realizó» o «El cliente no asistió» (también lleva qué pasó y el tiempo). Queda «Realizada» o «No asistió», con la fecha y quién la cerró.
2. El menú (⋮) de una agendada: «Editar», «Pasar a tarea (sin hora)» (si no han salido a la visita), «Mover el vencimiento de la tarea» o «Reintentar sincronización» cuando aplican, «Cancelar…» y «Eliminar» (el organizador en las primeras 24 horas o un administrador). Abajo de la línea, «Ver la tarea T00X» si es sesión de una tarea.
3. Realizada o «No asistió»: solo lectura («Ver»); «Reabrir» la regresa a agendada (su reporte se queda) y «Ver reporte» muestra el reporte de cierre.
4. Cancelada: solo lectura con su motivo; no se reabre (su evento ya se canceló en Google): si hace falta, se agenda otra.

### Cancelar una tarea o tarea agendada
Cancelar es «ya no se va a hacer»; no es completarla (eso pide el reporte) ni borrarla (eso es solo para errores de captura).
1. En el menú de la tarea (los tres puntos ⋮ al final de la fila) elige «Cancelar…». En una tarea agendada te pregunta primero «¿La quieres reprogramar?»: si solo cambia la fecha, reprográmala y se conserva su historial.
2. Elige el motivo (El cliente ya no lo necesita, Se resolvió de otra forma, Duplicada, Se reprogramó u Otro; con «Otro» escribe el porqué).
3. «¿Le dedicaste tiempo?»: opcional; es obligatorio si ya se trabajó (una visita con «voy en camino» o «llegué», o una tarea del cliente en proceso). Ese tiempo suma a las horas del caso y sale en Reportes.
4. En una tarea agendada: si es de una serie, «Solo esta» o «Toda la serie» (también se cancela en Google Calendar); y «Avisarle al cliente por su conversación».
5. La tarea queda tachada como «Cancelada · motivo», deja de contar en pendientes, vencidas y siguiente paso, y queda en la actividad del caso. «Reabrir» (en el mismo menú) la regresa a pendiente.
6. También se lo puedes pedir a Dali: «cancela la llamada con Mario de mañana, ya no hace falta».

### Agendar una tarea o pasarla a la agenda
Son dos cosas distintas:
1. «Agendar tarea» (dentro del caso): le pones día y hora para trabajarla y la tarea se queda. Puedes agendarla varias veces, o de golpe con «Serie» (por ejemplo, todos los martes 4 semanas). Cada una queda ligada a la tarea; «Ver historial» (filtro Agendadas) las muestra.
2. «Pasar a la agenda»: la tarea deja de ser tarea y se vuelve una sola tarea agendada, con el tiempo que ya tenía reportado. Ya trae el título, la descripción y la duración estimada; eliges día, hora y lugar. Solo sale en tareas pendientes que no tienen tareas agendadas y que no son obligatorias, de la etapa ni del cliente (esas solo se agendan).
3. Al revés, una tarea agendada pasa a tarea sin hora con «Pasar a tarea (sin hora)», en su menú dentro del caso o en el calendario al abrirla. Se quita de la agenda y de Google Calendar y queda como tarea con fecha límite ese mismo día, el organizador como responsable y lo que duraba como tiempo estimado. Si tiene cliente, puedes avisarle que se quita la cita. Si era la sesión de una tarea, no se crea otra: queda esa tarea. Si es de una serie, solo esa vez sale de la agenda. No se puede si ya se hizo, se canceló o ya marcaron «voy en camino».
4. Queda en la actividad del caso («Tarea ↔ agenda»). También se lo puedes pedir a Dali: «pasa a la agenda la tarea de llamar a Mario, el jueves a las 10» o «la visita de mañana quítala de la agenda y déjala como tarea».

### Participantes de una tarea agendada
Solo las agendadas (con hora) llevan participantes: otros del equipo que van además del responsable.
1. Al agendar (en «Tarea» con hora, en «Agendar tarea» del caso o en el calendario) toca los nombres en «Participantes». Si alguno ya tiene algo a esa hora (en Kontrolya o en su Google Calendar), te lo avisa; puedes agendar igual.
2. Cada participante la ve en su Agenda, su Mi día y su Mi ruta con la etiqueta «Participas», y le llega aviso cuando lo agregan o quitan, si cambia la hora, si se cancela y media hora antes de empezar. Si tiene Google Calendar conectado, le llega también como invitación.
3. Solo el responsable la edita, marca «Voy en camino» y «Llegué» y la concluye con el reporte.
4. Si no puedes ir, pulsa «No puedo ir» (en Mi día o al abrirla en el calendario) y escribe por qué: le llega al responsable y en el formulario sale «no puede ir».
5. A Dali: «agéndame la visita a Grúas el jueves a las 10 con Beto».

### Borrar una tarea
Solo para lo que se capturó por error: la borra quien la creó en las primeras 24 horas, o un administrador. Si ya no se puede borrar, te lo dice y te abre «Cancelar» para hacerlo con su motivo.

### Reportar algo sin tarea
Pulsa «Reportar actividad» en la barra de arriba: Título, «Qué se hizo», fecha, hora, resultado, tiempo y evidencia. Sin cliente queda como actividad interna. Si es de una tarea pendiente, elígela en «Tarea (opcional)» y queda como su avance.
Los reportes (cierre, avance y actividad) salen en la actividad del caso como reporte, con su ícono; la pestaña Notas es solo para las notas escritas.

### Revisar lo hecho
1. Entra a Agenda › Reportes y filtra por persona («Todas las personas») y fechas (Desde, Hasta).
2. Reportes: las tareas concluidas, avances y actividades, con su tipo (Tarea, Tarea agendada, Orden de trabajo, Actividad o Avance), resultado, tiempo dedicado (contra lo estimado), evidencia, llegada, cliente y caso. Arriba sale el «Tiempo total» y, si hay varias personas, cuánto lleva cada una. En una orden de trabajo, «Ver reporte de servicio» lo abre. «Ver más» trae los siguientes.
3. Llegadas: una tabla con Cuándo, Quién, Cliente, Visita y Ubicación («Sin ubicación» si no se tomó); «Exportar CSV» las descarga.

## Dudas frecuentes
- ¿Cómo agendo una tarea? Agendar es ponerle día y hora para que entre al calendario. Hay tres caminos: (1) una nueva: «Nueva tarea» en Agenda › Tareas (o «Tarea» en la barra de arriba) y llena «Fecha programada» y «Hora (opcional)»; con hora queda agendada; (2) una que ya existe y tiene caso: en el caso, menú de la tarea › «Agendar tarea» (día y hora; se puede repetir o hacer «Serie»); (3) una que ya existe sin caso: «Pasar a la agenda» (eliges día, hora y lugar). También se lo puedes pedir a Dali: «agéndame llamar a Mario el jueves a las 10».
- ¿Por qué el vencimiento de una tarea no tiene hora? Una tarea sin agendar no entra al calendario: su vencimiento es solo el día y vence al final de ese día. Si necesitas una hora exacta (cita, llamada, visita), es una tarea agendada: usa «Agendar tarea» o «Pasar a la agenda».
- ¿Es obligatorio el tiempo dedicado? Por omisión sí. El administrador lo cambia en Catálogos › Resultados de tareas («Exigir el tiempo dedicado en los reportes»); ahí también da de alta los resultados.
- Si concluyes varias tareas a la vez, el tiempo se reparte por igual entre ellas.
- ¿Cómo se decide el orden de Mi día? Por los pesos de Ajustes › Puntaje de tareas (administrador).
- Una visita entra a Mi ruta en campo del técnico y a Servicio › Despacho.

## Quién puede
- Con Agenda en «Todo» ves todas las pestañas y los reportes de todos.
- Con Agenda en «Todo» puedes ver el Mi día de otra persona («Día de:»).
- Con «Solo lo suyo» no hay pestaña Todas ni «Día de:», «No asignadas» solo si tu rol puede tomar lo que no tiene dueño, y en Reportes ves solo los tuyos.
- Puntaje de tareas y Resultados de tareas: solo el Administrador.
