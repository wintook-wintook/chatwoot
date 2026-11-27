---
key: casos
title: Casos (lo común de Ventas y Servicio)
areas: [sales, service]
keywords: [caso, casos, folio, crear caso, nuevo caso, caso interno, ligar a un cliente, quitar de interno, ticket, responsable, equipo, vencimiento, vence, cambiar estado, cerrar caso, cancelar caso, reabrir, tareas pendientes, conversaciones del caso, ligar conversacion, agregar conversacion, nota, agendar, lista, tablero, dashboard, varios casos, tomar, siguiente paso, sin siguiente paso, agente, robot, sin agente, con agente, seguimiento ia, quien atiende, editar caso, copiar folio, filtros, vistas guardadas, guardar vista, buscar caso, mias, no asignadas, mostrar cerrados, casos relacionados, vincular caso, documentar cierre, escalar, sla vencido, categoria, servicio afectado, prioridad]
pages: [cases, service_cases, opportunities, case, case_types, case_folio, case_module_settings]
sources: [app/javascript/dashboard/views/gestorTickets/Index.vue, app/javascript/dashboard/views/gestorTickets/Kanban.vue, app/javascript/dashboard/views/gestorTickets/TicketDetail.vue, app/javascript/dashboard/views/gestorTickets/CaseTicketInternalModal.vue, app/javascript/dashboard/views/gestorTickets/AssignClientModal.vue, app/javascript/dashboard/views/gestorTickets/CaseRelations.vue, app/javascript/dashboard/views/gestorTickets/CaseClassSwitcher.vue, app/javascript/dashboard/views/gestorTickets/filters/*.vue, app/javascript/dashboard/views/gestorTickets/activity/*.vue, app/javascript/dashboard/views/gestorTickets/stage/*.vue, app/javascript/dashboard/views/gestorTickets/conversation/LinkConversationModal.vue, app/javascript/dashboard/helper/caseFilters.js, app/controllers/api/v1/accounts/case_tickets_controller.rb]
reviewed: 2026-11-14
---
## Para qué sirve
Un caso es un trabajo con un cliente que empieza y termina: una oportunidad de venta (Ventas) o un caso de servicio, como un ticket de soporte, una orden de trabajo o un proyecto (Servicio). Cada caso junta su folio, su etapa, el responsable, las tareas, las conversaciones y todo lo que ha pasado. Lo propio de las oportunidades (monto, Ganada, Perdida, Posponer) está en la guía de oportunidades.

## Dónde está
- Ventas › Oportunidades: los casos de venta.
- Servicio › Casos: los de servicio; arriba eliges la clase (Soporte, Órdenes o Proyectos, según lo que tenga activo tu cuenta).
- En los dos eliges la forma de ver: Tablero (por etapas), Lista o Dashboard. Se recuerda la última que usaste, y también tus filtros.
- Debajo eliges de quién: «Mías», «No asignadas» o «Todas» («Todos» en Soporte; «Míos», «No asignados», «Todos» en Proyectos).
- El folio es el número del caso. Se arma solo con el prefijo del tipo de caso y un consecutivo; el administrador lo ajusta en Ajustes › Casos y etapas › Configuración de folio.

## Cómo se hace
### Crear un caso
1. Entra a Ventas › Oportunidades o a Servicio › Casos.
2. Pulsa el botón con «+» (dice «Oportunidad», «Caso», «Orden de trabajo», «Proyecto» o el nombre del tipo que filtraste).
3. En la pestaña «Datos del caso» elige el «Tipo de caso», la «Organización (opcional)» y el «Contacto». Una oportunidad necesita contacto; un caso de soporte sin contacto se crea como caso interno (el botón cambia a «Crear caso interno»).
4. Escribe el «Título» y, si quieres, la «Descripción», el «Servicio afectado» («Productos de interés» en una oportunidad), la «Categoría» y la «Prioridad» (Baja, Media, Alta o Urgente). Si el tipo usa ITIL, también eliges «Naturaleza del caso (ITIL)», «Impacto» y «Urgencia», y la prioridad se calcula sola.
5. En «Asignación manual» eliges «Equipo» y «Responsable» (empieza en ti, o en el responsable fijo del contacto si lo tiene). Si lo dejas «— Sin asignar —», deciden las reglas de automatización.
6. En «Campos personalizados» llena los del tipo (los que tienen * son obligatorios). En una orden de trabajo hay además la pestaña «Dirección».
7. Pulsa el botón de crear («Crear oportunidad», «Crear caso», «Crear orden de trabajo» o «Crear proyecto»).

### Editar un caso
1. Dentro del caso pulsa el lápiz («Editar») junto al título.
2. En «Editar caso» cambias tipo (de la misma clase), título, descripción y los demás datos; el cliente no se cambia.
3. Pulsa «Guardar cambios». Un caso cerrado o cancelado no se edita: hay que reabrirlo.

### Buscar y filtrar en la lista o el tablero
1. Escribe en «Buscar por folio, título o contacto…».
2. Elige el tipo de caso y, en la Lista, el estado (en Ventas, el resultado: En curso, Ganadas, Perdidas, Pospuestas, Canceladas o Todas).
3. «Filtros» abre los filtros finos: «¿Qué fecha?» y «¿Cuándo?» (Vencidas, Hoy, Esta semana, Este mes, Últimos 30 días, Personalizado…), Prioridad y, según la clase, Origen, Servicio, Categoría, Naturaleza, Facturable o Responsable (este solo en «Todas»). «Limpiar» los quita.
4. El botón rojo filtra lo vencido: «SLA vencido» en Soporte, «Visitas vencidas» en Órdenes, «Cierre vencido» en Ventas y «Atrasados» en Proyectos.
5. En el Tablero, «Mostrar cerrados:» (o «Mostrar cerradas:») dice cuántos cerrados se ven: No mostrar, Últimos 7, 30 o 90 días, o Todo el historial. Los abiertos siempre se ven.
6. En la Lista puedes ordenar con los encabezados de columna y elegir cuántos ver en «Por página».

### Guardar una vista
1. Con los filtros a tu gusto, abre «Vistas» y pulsa «Guardar como».
2. Ponle nombre y, si quieres, marca «Compartir con la cuenta».
3. Después la eliges en «Vistas» («Mis vistas» o «Compartidas»). Si cambias filtros sale «modificada»: «Guardar» la actualiza y «Quitar vista» la deja de aplicar. «Gestionar vistas» sirve para renombrarlas, compartirlas o eliminarlas.

### Ligar un caso interno a un cliente
1. Abre el caso interno: arriba dice «Caso interno · quien lo pidió».
2. Pulsa «Ligar a un cliente» junto a ese texto.
3. Elige la organización (opcional) y el contacto, y pulsa «Ligar». Si eliges primero la organización, el contacto se busca entre los suyos; sin organización se toma la del contacto.
4. El caso deja de ser interno: aparece en la ficha de la organización y del contacto, en su portal y en sus reportes, y queda en la actividad. Quien lo pidió sigue como solicitante. Se puede también con el caso cerrado.

### Trabajar dentro del caso
1. Arriba están el folio (clic para «Copiar folio»), el cliente (clic para ver su ficha), el título, «Cambiar estado ▾», «Vence: …», «Equipo» y «Responsable». En soporte puede salir también «Escalar».
2. Pestañas: Actividad (filtros Todo, Cliente, Notas, Tareas y Cambios), Pendientes (Tareas y Tareas agendadas), Conversación y Avance. Lo demás está en «Más ▾»: Notas, Casos relacionados, Cotizaciones (si el caso tiene contacto), Dali (si tu empresa activó la inteligencia artificial de casos) y, según la clase, Reporte de servicio o Proyecto y Casos del proyecto.
3. A la altura de las pestañas: Nota, Tarea, Agendar y Mensaje para registrar algo sin cambiar de pestaña.
4. Vencimiento: pulsa «Vence», elige fecha y hora y «Guardar» (o «Quitar fecha»). Si no fijas fecha, se usa la estimada por el SLA.
5. Si otra persona tiene abierto el mismo caso, arriba sale «… también está en este caso».

### Cambiar de etapa
1. Pulsa «Cambiar estado ▾»: arriba dice «Ahora: …» y debajo las etapas a las que puede pasar.
2. Elige una. Sale «Cambiar a «…»» con «Motivo (opcional)», que queda en el historial; pulsa «Cambiar estado».
3. Si el caso tiene tareas agendadas a futuro, puedes marcar «Cancelarlas y avisar al cliente» (no se puede deshacer).

### Varias conversaciones en un caso
1. Pulsa «Conversaciones N ▾». Ves las ligadas; la «principal» no se cambia ni se quita.
2. Pulsa «Ligar conversación» (o «Agregar conversación» si ya hay una).
3. Elige una conversación del contacto o una bandeja con «Usar bandeja»: si ya hay una conversación abierta ahí se usa esa; si no, se crea. En WhatsApp el primer mensaje debe ser una plantilla aprobada.
4. Para quitar una adicional, pulsa la ✕ («Quitar del caso») junto a ella (la conversación no se borra). Un punto naranja avisa que el contacto tiene conversaciones sin ligar.

### Ligar casos relacionados
1. Abre «Más ▾» › Casos relacionados y pulsa «+ Vincular caso».
2. Busca por «Folio o título…», elige el «Tipo de relación» (por ejemplo Duplicado de, Padre de o Relacionado) y pulsa «Vincular».
3. Para quitarla, pulsa la ✕ junto al caso ligado y confirma «Eliminar»: el caso no se borra.

### Cerrar o cancelar
1. Pulsa «Cambiar estado ▾» y elige la etapa de cierre o de cancelación.
2. Si hay tareas pendientes, eliges: «Cancelarlas», «Conservarlas sin caso» (siguen en el contacto y en Mi día del responsable) o «Concluirlas ahora» con un reporte de cierre, y pulsas «Continuar».
3. Cada clase pide lo suyo en «Documentar cierre»: soporte, «Tipo de cierre» (Resuelto, Duplicado, No aplica o Cancelado), «Causa» y «Solución» obligatorias; orden de trabajo, «Horas reales» y «Recibió»; proyecto, un resumen opcional.
4. Cerrado o cancelado, el caso queda en solo lectura: solo se agregan notas y mensajes.

### Reabrir
1. En el caso cerrado o cancelado pulsa «Reabrir».
2. Escribe el «Motivo de la reapertura» (obligatorio) y pulsa «Reabrir caso». Queda en el historial y el SLA vuelve a contar desde cero.

### Ver de un vistazo cómo va cada caso (lista y tablero)
1. «Siguiente paso» muestra la tarea o tarea agendada más próxima del caso; «Sin siguiente paso» (en amarillo) avisa que el caso no tiene nada pendiente.
2. El robot junto al siguiente paso dice si un agente atiende la conversación del caso:
   - morado: un agente está contestando (Seguimiento IA o un agente de Agentes IA);
   - ámbar: hay agente, pero está en pausa (por ejemplo, porque la tomó una persona);
   - gris tachado: sin agente, nadie automático atiende la conversación (más tenue si el caso no tiene conversación).
3. Pasa el mouse sobre el robot para ver qué agente es, su objetivo, en qué intento va y cuándo vuelve a escribir.
4. En la barra de filtros, «Sin siguiente paso», «Sin agente» y «Con agente» dejan solo esos casos (otro clic quita el filtro). Los casos cerrados o cancelados no muestran robot.

### Varios casos a la vez
1. En la vista Lista marca las casillas de los casos.
2. Usa «Tomar» (te los asignas), «Asignar a», «Cambiar estado» o «Cerrar»; «✕ Limpiar selección» los desmarca. Las oportunidades y las órdenes de trabajo no se cierran así: hay que cerrarlas una por una.

## Dudas frecuentes
- ¿Puedo cambiar el cliente de un caso? No. Si es otro cliente, cancela el caso y crea uno nuevo.
- En el Tablero de Servicio, al soltar la tarjeta en otra columna puedes escribir una «Nota (qué hiciste)» y marcar «Avisar al cliente por su canal». Si ese paso cierra el caso, aparece «Ir a la ficha» para documentar el cierre ahí. Un caso cancelado ya no se mueve.
- Si el cliente vuelve a escribir sobre un caso de servicio cerrado, puede reabrirse solo; el administrador lo define en Ajustes › Casos y etapas › Ajustes del módulo. Las oportunidades no se reabren solas: solo queda el aviso en su historial.
- Al cerrar varios casos a la vez, las tareas agendadas a futuro no se cancelan: revísalas caso por caso.
- Desde un caso de soporte puedes pulsar «Crear orden de trabajo» si tu empresa usa órdenes: toma el cliente, la conversación, el asunto y la descripción del caso.

## Quién puede
- Ver y trabajar casos: según tu rol, en Ventas (oportunidades) y en Servicio (lo demás) puedes ver todo, solo lo tuyo, ver sin cambiar o nada. Con «Solo lo suyo» no sale «Todas».
- Asignar a otra persona y tomar lo que no tiene dueño («No asignadas», «Tomar») dependen de los permisos de tu rol; sin «Asignar a otra persona», el caso que creas queda a tu nombre.
- Reabrir: solo Administrador o Supervisor.
- Tipos de caso, folio y reglas: solo el Administrador.
