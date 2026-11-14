---
key: informes
title: Informes y dashboards
areas: [reports]
keywords: [informe, informes, reporte, reportes, dashboard, dashboards, metricas, estadisticas, resumen del negocio, mi negocio, dashboard de ventas, dashboard de servicio, dashboard de clientes, dashboard de campanas, en vivo, por usuario, por agente, por equipo, por bandeja, por etiqueta, csat, satisfaccion, encuesta, calificacion, bot, tiempo de respuesta, tiempo de primera respuesta, tiempo de resolucion, tiempo de espera del cliente, resoluciones, transferencias, notificaciones, descargar, descargar informe, csv, exportar informe, horas laborales, agrupar por, duracion, periodo, rango de fechas, trafico de conversaciones, mapa de calor, desatendidas, no asignadas, estado del usuario, explicame la semana, analisis de conversaciones, lo que necesita tu atencion, quien esta vendiendo, metricas de soporte, metricas de ordenes, metricas de proyectos, sla vencidos, cumplimiento sla]
pages: [reports, reports_live, reports_conversations, reports_agents, reports_inboxes, reports_labels, reports_teams, reports_bot, reports_csat, business_summary_report, business_summary, business_summary_access, service_dashboard, pipeline, clients_dashboard, my_summary]
sources:
  - app/javascript/dashboard/routes/dashboard/settings/reports/*.vue
  - app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js
  - app/javascript/dashboard/routes/dashboard/settings/reports/constants.js
  - app/javascript/dashboard/routes/dashboard/settings/reports/components/**/*.vue
  - app/javascript/dashboard/components/layout/config/sidebarItems/reports.js
  - app/javascript/dashboard/i18n/locale/es/report.json
  - app/javascript/dashboard/views/gestorTickets/summary/BusinessSummary.vue
  - app/javascript/dashboard/views/gestorTickets/Metrics.vue
  - app/javascript/dashboard/views/gestorTickets/workOrder/WorkOrderMetrics.vue
  - app/javascript/dashboard/views/gestorTickets/project/ProjectMetrics.vue
  - app/controllers/api/v2/accounts/case_reports_controller.rb
  - app/builders/v2/reports/cases/business_summary_builder.rb
  - app/policies/report_policy.rb
  - app/models/case_setting.rb
reviewed: 2026-11-14
---
## Para qué sirve
Informes junta en un solo menú la foto del negocio, los dashboards de cada área y el detalle de cómo se atienden las conversaciones.

## Dónde está
En el menú Informes, en este orden:
- Resumen del negocio: la foto de toda la empresa. Es la misma pantalla que Inicio › Mi negocio.
- Dashboard de ventas: cómo van las oportunidades (es el mismo «Dashboard» de Ventas › Oportunidades).
- Dashboard de servicio: los casos de servicio (el mismo «Dashboard» de Servicio › Casos). Abre la última clase de servicio que usaste (Soporte, si no has usado otra).
- Dashboard de clientes: prospectos y clientes.
- Dashboard de campañas: los seguimientos de los Agentes IA (el mismo de Campañas › Dashboard).
- Conversaciones (se despliega): En vivo, Conversaciones, Por usuario, Por equipo, Por bandeja, Por etiqueta, Satisfacción (CSAT) y Bot.
Al pulsar Informes en el menú principal se abre En vivo. Los dashboards de ventas y de servicio solo salen si tu empresa usa casos; Bot, solo si la cuenta tiene el bot activado.

## Qué contesta cada uno
- Resumen del negocio: lo que necesita atención hoy y cómo van ventas, soporte, órdenes, proyectos y conversaciones en el período. Detalle abajo.
- Dashboard de ventas: cuánto se vendió y qué hay en juego. Detalle en la guía dashboard_ventas.
- Dashboard de servicio: cómo van los casos de Soporte, Órdenes o Proyectos. Detalle abajo.
- Dashboard de clientes: cuántos prospectos y clientes hay, cuántos llegaron por mes, la conversión a cliente y los días de prospecto a cliente. Detalle en la guía dashboard_clientes.
- Dashboard de campañas: seguimientos por estado, por canal y por Agente IA, embudo de intención, citas próximas y seguimientos vencidos. Se filtra por fechas, canal, Agente IA y estado.
- En vivo: cómo están las conversaciones en este momento.
- Conversaciones: las cifras de todas las conversaciones del período.
- Por usuario, Por equipo, Por bandeja y Por etiqueta: las mismas cifras de una persona, equipo, bandeja o etiqueta.
- Satisfacción (CSAT): las respuestas a la encuesta de satisfacción.
- Bot: lo que atendió el bot.

## Cómo se hace
### Ver un informe
1. Abre Informes en el menú de la izquierda.
2. Elige el informe. Para los de conversaciones, despliega «Conversaciones».
3. Donde los haya, ajusta el periodo y los filtros arriba de la pantalla. Las cifras se recalculan solas al cambiarlos.

### Usar el Resumen del negocio
1. Entra a Informes › Resumen del negocio (o Inicio › Mi negocio).
2. Arriba a la derecha elige el «Período»: «Este mes» (el que sale primero), «Mes pasado», «Este trimestre», «Trimestre pasado», «Este año», «Año pasado» o «Personalizado» («Desde» y «Hasta»). Debajo del título dice el rango y «comparado con» el período anterior; cada cifra trae su flecha contra ese período.
3. «Lo que necesita tu atención»: promesas de pago vencidas, conversaciones sin atender, casos de soporte con SLA vencido, visitas vencidas sin realizar, proyectos atrasados y oportunidades con el cierre estimado vencido. «Ver» te lleva a la lista. Si no hay nada dice «Nada urgente: todo al día.».
4. «Explícame la semana»: Dali te cuenta cómo va el negocio en tres partes, «Va bien», «Preocupa» y «Hoy haría», solo con las cifras de la pantalla. «Volver a explicar» lo rehace.
5. Bloques por área, solo de las clases de caso que usa tu empresa: «Ventas · ¿cuánto vendimos y cuánto entra?» (Vendido, Tasa de cierre, Entra esta semana, Entra este mes, En juego), «Soporte · ¿estamos atendiendo bien?» (Casos abiertos, SLA vencido, Primera respuesta, Satisfacción), «Órdenes de trabajo · ¿cumplimos en campo?» (Órdenes abiertas, Visitas vencidas, Terminadas a tiempo, Esperando conformidad) y «Proyectos · ¿van a tiempo?» (Proyectos abiertos, Atrasados, En riesgo, Sobre presupuesto). «Ver los números →» abre el dashboard de esa área.
6. «Conversaciones · ¿cómo estamos atendiendo por chat?» (si la cuenta tiene bandejas): Conversaciones nuevas, Sin atender ahora, Primera respuesta, Tiempo de resolución, Satisfacción, «Por canal» y «¿De qué hablan? (etiquetas más usadas)».
7. «Análisis de conversaciones con Dali»: elige cuántas conversaciones lee («Conversaciones:», 100 por omisión, de 10 a 150) y pulsa «Calcular». Encuentra de qué hablan, quejas que se repiten, ventas que se escapan y clientes molestos. Cuesta tokens, por eso es a pedido; «Recalcular» lo rehace con el período nuevo.
8. Al final: «¿Quién está vendiendo?» (los que más ganaron) y «¿Quién tiene más cosas vencidas?».

### Usar el Dashboard de servicio
1. Entra a Informes › Dashboard de servicio. Arriba eliges la clase (Soporte, Órdenes o Proyectos) y el tipo de caso («Todos los tipos»).
2. Filtra por responsable («Todos los responsables»; en Órdenes, «Todos los técnicos»), por equipo («Todos los equipos») y por período (igual que en el Resumen del negocio; abre en «Este mes»).
3. Soporte: Volumen (Casos en el período, Casos activos, Resueltos en el período, Reabiertos), SLA (SLA vencidos, SLA en riesgo, Cumplimiento SLA), Tiempos de atención (Tiempo promedio resolución, 1ª respuesta promedio), Calidad (CSAT; con ITIL también Problemas abiertos y Cambios pendientes), la gráfica «Creados vs resueltos (diario)» y gráficas Por estado, Por tipo, Por prioridad, Estado SLA, Por categoría, Por servicio afectado y Por responsable.
4. Órdenes: Abiertas, Visitas vencidas, Cumplimiento, Horas real vs. estimado, Retrabajos, Materiales facturables, A la primera y Calificación del cliente; «Puntualidad de lo terminado», «Abiertas por etapa» y tablas por técnico y por tipo.
5. Proyectos: Abiertos, Hitos vencidos, Horas usadas del presupuesto y Entregas a tiempo; «Salud de los abiertos» (En tiempo, En riesgo, Atrasado, Sin fechas), «Abiertos por fase» y tablas por responsable y por tipo.
6. En Órdenes y Proyectos, «Ver tabla» / «Ver gráfica» cambia cómo se ve cada bloque. Lo abierto es foto de hoy; lo terminado cuenta por el día en que se terminó dentro del período.

### Ver En vivo
1. Entra a Informes › Conversaciones › En vivo. No tiene filtros: es el momento actual.
2. «Conversaciones abiertas»: Abiertas, Desatendidas, No asignadas y Pendientes.
3. «Estado del usuario»: cuántos están En línea, Ocupado y Desconectado.
4. «Tráfico de conversaciones»: un mapa por día y hora de los últimos 7 días. «Descargar informe» baja ese tráfico en un archivo.
5. «Conversaciones por usuarios»: cada usuario con sus conversaciones abiertas y desatendidas, y su estado.

### Ver Conversaciones, Por usuario, Por equipo, Por bandeja o Por etiqueta
1. En Por usuario, Por equipo, Por bandeja y Por etiqueta elige primero a quién ver: «Seleccionar usuario», «Seleccionar equipo», «Seleccionar bandeja de entrada» o «Seleccionar etiqueta» (sale el primero de la lista ya elegido). Conversaciones es de toda la cuenta.
2. Elige el periodo («Duración»): «Últimos 7 días» (el que sale primero), «Últimos 30 días», «Últimos 3 meses», «Últimos 6 meses», «Último año» o «Rango de fechas personalizado» (elige las fechas en «Seleccionar rango de fechas» y pulsa «Aplicar»).
3. «Agrupar por» (Día, Semana, Mes o Año, según el periodo) cambia cómo se dibujan las gráficas. Con «Últimos 7 días» no sale: va por día.
4. «Horas laborales» encendido cuenta los tiempos solo dentro del horario de atención.
5. Ves «Conversaciones», «Mensajes recibidos», «Mensajes enviados», «Tiempo de primera respuesta», «Tiempo de resolución», «Cantidad de resoluciones» y «Tiempo de espera del cliente», cada uno con su gráfica y su cambio contra el periodo anterior. Los tiempos son promedios.
6. El botón verde de arriba baja un archivo CSV del periodo: «Descargar informes de usuarios» (en Conversaciones y Por usuario), «Descargar informes del equipo», «Descargar informes de bandejas de entrada» o «Descargar informes de etiquetas». Trae a todos (todos los usuarios, equipos…), no solo al que elegiste.

### Ver Satisfacción (CSAT)
1. Entra a Informes › Conversaciones › Satisfacción (CSAT).
2. Filtra por periodo (las mismas opciones), «Elegir usuarios» (puedes elegir varios), «Seleccionar bandeja de entrada», «Seleccionar equipo» (si la cuenta usa equipos) y calificación (de «Pobre» a «Excelente»).
3. Arriba: «Total de respuestas», «Puntuación de satisfacción» (respuestas positivas entre el total) y «Tasa de respuesta» (respuestas entre encuestas enviadas), con la barra de cómo se reparten las calificaciones.
4. La tabla trae cada respuesta: «Contacto», «Responsable», «Calificación», «Comentario de retroalimentación» y el número de la conversación (lo pulsas para abrirla). Van de 25 en 25. Si no hay: «No hay respuestas disponibles de la encuesta de CSAT.».
5. «Descargar informes de CSAT» baja un CSV con los filtros puestos.

### Ver el Bot
1. Entra a Informes › Conversaciones › Bot. Filtra por periodo y «Agrupar por».
2. Ves «N.º de conversaciones» (las que atendió el bot), «Total de respuestas», «Tasa de resolución» (las que resolvió solo) y «Tasa de transferencia» (las que pasó a una persona), y las gráficas «Cantidad de resoluciones» y «Cantidad de transferencias».

### Pedir una cifra rápida
1. Pregúntale al asistente, por ejemplo «¿cuánto vendimos este mes?».
2. Te contesta con las cifras que tu rol puede ver.

## Límites
- En vivo no se puede ver de fechas pasadas; para eso usa Conversaciones.
- Bot y Satisfacción (CSAT) no tienen «Horas laborales»; CSAT tampoco «Agrupar por», y Bot no tiene botón de descarga.
- «Explícame la semana» y el «Análisis de conversaciones con Dali» se encienden o apagan en Ajustes › Casos y etapas › Inteligencia artificial; el análisis además necesita la integración de OpenAI.

## Dudas frecuentes
- No veo Informes en el menú: tu rol no tiene el área Informes. Pídeselo a tu administrador.
- No veo el Resumen del negocio: lo ven el Administrador y los roles con Informes; a alguien más se le da en Ajustes › Casos y etapas › Resumen del negocio: acceso (esa persona lo ve en Inicio › Mi negocio). Sin acceso sale «No tienes acceso al Resumen del negocio. Pídeselo a un administrador.».
- ¿Por qué no sale el bloque de Órdenes o Proyectos? El Resumen solo muestra las clases de caso que tu empresa usa (que tienen al menos un tipo de caso).
- La gráfica dice «No hemos recibido suficientes puntos de datos…»: no hay datos en ese periodo; prueba uno más largo.
- Lo que se hizo en cada tarea no está aquí: está en Agenda › Reportes.
- Tus avisos están en Inicio › Mi resumen, pestaña «Notificaciones».

## Quién puede
Entran el Administrador y los roles con Informes en «Todo» o «Ve todo (sin cambiar)». Por omisión son el Supervisor y Consulta; Vendedor y Técnico / Soporte no. Quien entra a Informes ve las cifras de toda la empresa. Los dashboards de ventas y de servicio también los abre quien tiene acceso a Ventas o a Servicio; si ese rol solo ve «lo suyo» (y no tiene Informes), ve solo sus números.
