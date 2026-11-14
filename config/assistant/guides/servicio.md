---
key: servicio
title: Servicio, soporte y SLA
areas: [service]
keywords: [servicio, soporte, ticket, tickets, sla, sla vencido, en riesgo, politicas sla, primera respuesta, resolucion, tipo de caso, clase de caso, ordenes, proyectos, clasificacion, categoria, subcategoria, servicio afectado, itil, impacto, urgencia, naturaleza, escalar, nivel de escalamiento, centro de ayuda, dashboard de servicio, metricas de soporte, filtros, vistas guardadas, mias, no asignadas, pendientes, cerrados, buscar caso, origen, documentar cierre, causa, solucion, clasificacion sugerida, respuesta sugerida, resumen y causa raiz, repetidos, problema, cambio]
pages: [service_cases, cases, case, service_dashboard, reports, case_types, classifications, sla_policies, help_center]
sources: [app/javascript/dashboard/views/gestorTickets/Index.vue, app/javascript/dashboard/views/gestorTickets/Kanban.vue, app/javascript/dashboard/views/gestorTickets/Metrics.vue, app/javascript/dashboard/views/gestorTickets/ClassMetrics.vue, app/javascript/dashboard/views/gestorTickets/CaseClassSwitcher.vue, app/javascript/dashboard/views/gestorTickets/filters/*.vue, app/javascript/dashboard/helper/caseFilters.js, app/javascript/dashboard/views/gestorTickets/TicketDetail.vue, app/jobs/case_sla_monitor_job.rb]
reviewed: 2026-11-14
---
## Para qué sirve
Servicio › Casos junta lo que se atiende a los clientes después de la venta. Cada caso pertenece a una clase:
- Soporte: tickets de clientes, con SLA (tiempos de respuesta y resolución).
- Órdenes: trabajo planeado, con técnico, visitas y horas (ver la guía de órdenes de trabajo).
- Proyectos: trabajo por fases, con fecha objetivo, presupuesto y avance.
Órdenes y Proyectos salen solo si tu cuenta las tiene activas. Lo común a todos los casos (crear, pestañas, cerrar, reabrir) está en la guía de casos.

## Dónde está
- Servicio › Casos: arriba eliges la «Clase de caso» (Soporte, Órdenes, Proyectos) y la «Forma de ver»: Lista, Tablero o Dashboard.
- Catálogos › Tipos de caso, Catálogos › Clasificaciones y Catálogos › Políticas SLA (administrador).
- Servicio › Centro de Ayuda: los artículos de ayuda para tus clientes (ver la guía del Centro de ayuda).
- Informes › Dashboard de servicio: el mismo Dashboard de Servicio › Casos.

## Cómo se hace
### Buscar y filtrar tickets en la Lista
1. En Servicio › Casos elige Soporte y Lista.
2. Arriba elige de quién: «Mías», «No asignadas» o «Todos» (si tu rol solo ve lo suyo, no sale «Todos»).
3. Elige el tipo («Todos los tipos» o uno) y el estado: «Pendientes», «Cerrados» o «Todos».
4. Escribe en «Buscar por folio, título o contacto…».
5. Pulsa «Filtros» para afinar: Fecha («¿Qué fecha?»: Alta o Cerrado el; «¿Cuándo?»: Hoy, Esta semana, Este mes, Mes pasado, Últimos 30 días, Últimos 90 días o Personalizado), Prioridad, Origen, Servicio, Categoría, Naturaleza (si algún tipo maneja ITIL) y Responsable. «Limpiar» los quita todos.
6. El aviso rojo «SLA vencido (N)» deja solo los vencidos; otro clic lo quita.
Las columnas son Folio, Contacto / Asunto, Asignado, Prioridad, Estado, Siguiente paso, Vence y Creado. El lápiz edita el caso sin abrirlo.

### Guardar una vista
1. Con los filtros puestos, pulsa «Vistas» › «Guardar como» y ponle nombre. Puedes compartirla con la cuenta.
2. En «Vistas» eliges entre «Mis vistas» y «Compartidas». Si cambias los filtros, la vista sale «modificada» y puedes «Guardar» encima.
3. «Quitar vista» deja de aplicarla; «Gestionar vistas» sirve para renombrar, compartir, dejar de compartir o eliminar.

### Tipos de caso, clasificaciones y SLA
Los configura el administrador en Catálogos (ver la guía «Tipos de caso, clasificaciones y políticas SLA»):
1. Catálogos › Tipos de caso: cada tipo tiene su clase (Soporte, Ventas, Orden de trabajo o Proyecto), su prefijo de folio, si «Maneja ITIL» y si es «Visible en el portal del cliente».
2. Catálogos › Clasificaciones: «Servicios afectados» y «Categorías» (con subcategorías), para todos los tipos o para uno.
3. Catálogos › Políticas SLA: minutos de «1ª respuesta» y «Resolución» por prioridad, tipo y naturaleza ITIL; gana la más específica.
Al crear un caso, en «Datos del caso» eliges «Servicio afectado» y «Categoría». Si el tipo maneja ITIL, también «Naturaleza del caso (ITIL)» (Incidente, Solicitud de servicio, Problema, Cambio o Consulta), «Impacto» y «Urgencia»; la prioridad se calcula con impacto × urgencia.

### Escalar un caso de soporte
1. En el caso pulsa «Escalar» (solo en casos de Soporte abiertos que aún no están en N3).
2. Escribe el «Motivo del escalamiento» y, si quieres, elige otro equipo en «Reasignar a equipo» (o «Mantener asignación actual»).
3. Pulsa «Escalar». El caso sube de nivel (N1 → N2 → N3).

### Cerrar un ticket de soporte
1. Cambia el estado a Cerrado: se abre «Documentar cierre».
2. Elige el «Tipo de cierre» (Resuelto, Duplicado, No aplica o Cancelado), escribe la «Causa» y la «Solución» (obligatorias) y marca si fue «Confirmado por el cliente».
3. Pulsa «Cerrar caso».

### La IA en un ticket
Si el administrador la activó (Ajustes › Casos y etapas › Inteligencia Artificial):
1. En la pestaña Conversación puede salir «Clasificación sugerida por IA» con su porcentaje de confianza: «Aplicar» o «Descartar».
2. En «Más ▾› Dali» están «Respuesta sugerida» (de la base de conocimiento, con «Copiar» o «Usar en la conversación»), «Resumen y causa raíz», «Detección de repetidos» («Analizar» y «Vincular») y «Seguimiento sugerido». Cada una con su botón «Generar».

## Dudas frecuentes
- ¿Qué significa el punto de color junto al folio? Verde: a tiempo; ámbar: en riesgo (ya pasó el 80% del tiempo); rojo: vencido. Solo los casos de Soporte llevan SLA.
- ¿Se detiene el reloj? Sí, mientras el caso está en «En espera del cliente», «En espera de tercero» o «En espera interna». Al reabrir, el SLA empieza de cero.
- ¿Cómo veo los vencidos? Con el aviso «SLA vencido (N)» de la lista, o en Inicio › Mi resumen, en «Con SLA en riesgo o vencido».
- Si no le pones fecha en «Vence», el caso usa la que calcula el SLA.
- Un caso de Soporte en «Resuelto» se cierra solo a las 72 horas.
- En el Tablero, «Mostrar cerrados:» decide si ves los cerrados de los últimos 7, 30 o 90 días, todo el historial o ninguno; los abiertos siempre se ven.
- Los casos de naturaleza Problema tienen «Detalles del problema» (causa raíz y solución temporal) y los de Cambio, «Detalles del cambio» (riesgo, aprobación, plan de reversión y ventana programada, con «Aprobar» o «Rechazar»).
- El Dashboard de Soporte se filtra por tipo y «Período». Muestra casos del período y activos, SLA vencidos y en riesgo, cumplimiento SLA, 1ª respuesta y resolución promedio, resueltos, reabiertos, problemas abiertos y cambios pendientes (con ITIL), CSAT y gráficas de creados vs resueltos, por estado, tipo, prioridad, estado SLA, categoría, servicio afectado y responsable. En Órdenes y Proyectos muestra sus propias métricas.

## Quién puede
- Ver y trabajar casos de Servicio: según tu rol, todo, solo lo tuyo, ver sin cambiar o nada (el Técnico, por omisión, solo lo suyo).
- Tipos de caso, Clasificaciones y Políticas SLA: solo el Administrador.
