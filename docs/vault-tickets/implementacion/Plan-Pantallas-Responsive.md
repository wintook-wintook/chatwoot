# Plan — pantallas que no se acomodan al ancho (2026-11-19)

**Problema reportado por el usuario:** en algunas pantallas se pierden datos u objetos (listas, tablas) y hay que
bajar el zoom del navegador para verlos.

**Cómo se hizo la lista:** revisión del código (no abriendo cada pantalla) de `app/javascript/dashboard/views/`,
`routes/dashboard/` y `components/`. «Seguro» = el mecanismo de recorte es claro en el código; «probable» = depende
del ancho de la ventana.

**Causa de fondo:** el contenedor de la app (`routes/dashboard/Dashboard.vue`) y la raíz de casi todas las vistas
tienen `overflow-hidden`: lo que se sale y no está dentro de un contenedor con scroll queda cortado, sin forma de
desplazarse.

## Etapa 1 — se pierden datos (columnas o botones que no se ven) — HECHA (2026-11-19, commit 971d1026)

| # | Pantalla | Archivo | Qué pasa | Arreglo |
|---|---|---|---|---|
| 1 | Lista de casos (Ventas y Servicio) | `views/gestorTickets/Index.vue` (VeTable ~349, columnas ~856-1083 y ~1627-1800, `.tickets-table-wrap` ~1921) | ~1,500–2,000 px de columnas; sin `scroll-width`; el wrap con `overflow: hidden` | `scroll-width` + acciones fijas a la derecha |
| 2 | Campañas (lista) | `views/contactTrackings/Campaigns.vue` (~111-280, ~752, wrap ~813) | Igual que 1, más leve | Igual que 1 |
| 3 | Presupuesto de ventas › Avance por vendedor | `views/gestorTickets/salesBudgets/BudgetProgress.vue` ~235 | Tarjeta `overflow-hidden` corta montos y % | `overflow-x-auto` en la tarjeta |
| 4 | Ajustes › Kanban (procesos y tipos) | `components/settings/KanbanProcesses/Index.vue` ~385, `components/settings/KanbanTypeProcesses/Index.vue` ~248, `components/KanbanTypeProcesses-Simple.vue` ~276, `components/SimpleCrudTable.vue` ~76 | Tarjeta `overflow-hidden` corta la columna Acciones | `overflow-x-auto` |
| 5 | Asignación masiva › Vista previa de audiencia | `components/contacts/BulkTrackingAssign/AudiencePreview.vue` ~204 | Tarjeta `overflow-hidden` corta columnas | `overflow-x-auto` |
| 6 | Modales comunes (~118) | `components/Modal.vue` ~89 (`w-[37.5rem]`) y ~139 (cajón `w-[30rem]`) | 600 px fijos: en teléfono o ventana partida se cortan | `max-w-full` / ancho máximo de la pantalla |
| 7 | Kanban de conversaciones (barra de arriba) | `views/kanbanBoard.vue` ~858-910 | Sin `flex-wrap`: filtros y botones de la derecha se salen | `flex-wrap` |
| 8 | Asistente de Agentes IA (1.0) y asistente de Agentes listos | `views/contactTrackings/Assistant.vue` raíz ~1623, rejillas ~1755 y ~2187; `views/readyAgents/ReadyAgentModal.vue` ~376-386 | Bajo 768 px el segundo bloque queda cortado | scroll vertical en angosto |

## Etapa 2 — se aprieta (campos ilegibles, fechas cortadas) — PENDIENTE

| # | Pantalla | Archivo | Qué pasa |
|---|---|---|---|
| 9 | Detalle de caso › Ficha del contacto (cajón) | `routes/dashboard/contacts/components/ContactInfoPanel.vue` ~83 (desde `TicketDetail.vue` ~4659) | `w-1/4` sin mínimo (~260 px en laptop) |
| 10 | Modal de caso (crear/editar) | `components/contacts/CaseTicket/CaseTicketModal.vue` ~110, ~510 (`h-[485px]`), ~657, ~738, ~797, ~1009, ~1081; `views/gestorTickets/CaseTicketInternalModal.vue` ~142, ~565, ~714, ~797, ~1035, ~1110 | `grid-cols-2/3/4` sin `md:`; altura fija |
| 11 | Modal de tarea | `views/gestorTickets/Tasks.vue` ~1810; `components/contacts/CaseTicket/TicketTasks.vue` ~1308, ~1457 | `grid-cols-5` con fechas |
| 12 | Tarea rápida, Reportar actividad, Mantenimiento (plan y equipo), Cita, Plantilla de WhatsApp, Importar agente, Propuesta de Dali, Mi resumen, pasos del asistente de Agentes listos | `tasks/QuickTaskModal.vue` ~192, `tasks/ActivityReportModal.vue` ~274/301, `maintenance/MaintenancePlanForm.vue` ~116/135/152, `maintenance/AssetForm.vue` ~82/104, `CaseTicket/MeetingFormModal.vue` ~341, `whatsappTemplates/TemplateEditor.vue` ~717, `trackingTemplates/ImportModal.vue` ~301, `assistant/ProposalCard.vue` ~599, `home/MySummary.vue` ~478, `typeDetail/StageTasksModal.vue` ~392, `readyAgents/ReadyAgentModal.vue` (rejillas) | `grid-cols-3/4` sin breakpoint |
| 13 | Puntuación de campaña | `views/contactTrackings/CampaignScoringSettings.vue` ~146, ~195 | rejilla de 5 fija |
| 14 | Orden de trabajo › Materiales | `views/gestorTickets/workOrder/WorkOrderPanel.vue` ~351 | 7 columnas con inputs en la barra lateral de 400 px |
| 15 | Dali › tarjeta con tabla | `components/assistant/AssistantDataCard.vue` ~52 | tabla sin scroll en panel de 416 px |
| 16 | Ficha del agente 2.0 | `views/motor2/AgentPage.vue` ~307 | `md:grid-cols-[190px_1fr_320-400px]` desde 768 px → pasar a `lg:` |

## Etapa 3 — leve (apretado, pero se desplaza) — PENDIENTE

Tablas sin `overflow-x-auto` propio (el padre desplaza toda la página):
- métricas comerciales: `commercial/metrics/MonthlyTab.vue` ~384, `QuotesTab.vue` ~83, `LossesTab.vue` ~144, `OverviewTab.vue` ~350, `MoneyTab.vue` ~379, `commercial/CommercialFunnel.vue` ~417;
- `project/ProjectMetrics.vue` ~391, `workOrder/WorkOrderMetrics.vue` ~453/518;
- `tasks/VisitArrivals.vue` ~94, `contactTrackings/Dashboard.vue` ~736/778.

Tareas (`Tasks.vue`) ya tiene scroll y acciones fijas; solo obliga a moverse de lado en laptop.

## Revisadas y bien

Organizaciones, Contratos, Eventos, Catálogo, Cotizaciones (lista y editor), Presupuesto por vendedor y por cliente,
Consola ERP, Bases de conocimiento, lista de Agentes, Seguimientos, Kanban de casos, Despacho.

**Estado de la etapa 1 (2026-11-19):**
- Hechos y guardados: 1, 2, 3, 5, 6, 8. La lista de casos queda con la casilla, editar y «Contacto / asunto» fijos a la izquierda; Campañas, con el nombre fijo.
- Hechos pero SIN guardar: 4 (`components/settings/KanbanProcesses/Index.vue`, `KanbanTypeProcesses/Index.vue`) y 7 (`views/kanbanBoard.vue`). Esos archivos ya traían errores del revisor de estilo (textos sin traducir, `console.log`…) y el hook no deja guardarlos. Hay que decidir si se limpian (cambio grande) o se guardan saltando el hook.
- Descartados: `components/KanbanTypeProcesses-Simple.vue`, `KanbanProcesses-Simple.vue` y `SimpleCrudTable.vue`, porque no los usa ninguna pantalla.
