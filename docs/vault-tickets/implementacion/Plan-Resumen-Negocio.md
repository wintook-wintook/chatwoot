# Resumen del negocio (para el dueño)

> Rama `feat/nva_oportunidad` · 2026-10-21 · relacionado: [[Plan-Metricas-Comercial]], [[Trampas]]

## Decisiones (usuario, 2026-10-21)

1. Nombre: **«Resumen del negocio»** (no «Para el dueño»: no dice para quién es).
2. Todo el negocio en una pantalla que se lee en 30 s, por encima de las clases: primera
   opción del menú de Casos.
3. **Quién lo ve:** administradores siempre; los demás, solo si un administrador los marca
   en *Configuración → Resumen del negocio: acceso* (casillas por agente). Se guarda en el
   módulo (`case_settings.business_summary_user_ids`), no en la ficha de usuario de
   Chatwoot (para no chocar con sus actualizaciones). El backend revisa el permiso en cada
   consulta (403); el menú solo lo esconde.
4. IA «Explícame la semana»: sí (explica, no decide; solo usa las cifras del resumen).
5. Período inicial «Este mes», con la comparación justa de Números.

## Implementación

- Back: `V2::Reports::Cases::BusinessSummaryBuilder` (reusa PipelineBuilder, WorkOrderBuilder
  y ProjectBuilder; soporte: abiertos, SLA vencido/en riesgo, primera respuesta con ▲▼,
  CSAT). `classes` = las que la cuenta usa (una sin tipos no aparece). `people`: top 3
  vendedores y quién tiene más vencido (SLA, cierre estimado, fecha objetivo). `attention`
  (máx. 5, lo más grave primero): promesas de pago vencidas → SLA vencido → visitas
  vencidas → proyectos atrasados → cierres estimados vencidos sin compromiso.
  `GET case_reports/business_summary`, `POST case_reports/business_summary_ai`
  (`Cases::Ai::BusinessSummaryNarrator`, acción de IA `business_summary`).
  `CaseSetting#business_summary_visible_to?`; `case_setting` expone
  `business_summary_user_ids` y `can_view_business_summary`.
- Front: `views/gestorTickets/summary/BusinessSummary.vue` (ruta `tickets/summary`) y
  `BusinessSummaryAccess.vue` (`tickets/summary-access`, admin). Menú: ítem con
  `visibleGetter: 'caseTickets/getCanViewBusinessSummary'` (soporte mínimo agregado en
  `Secondary.vue`, que pide `fetchSettings` una vez). Cada punto de atención abre la Lista
  de su clase ya filtrada (deja el estado que la Lista restaura: Todos, abiertos, aviso de
  vencidos y, en promesas, «Solo comprometidas»).

## Segunda vuelta (2026-10-21)

- **También en Informes** (decisión del usuario): primera opción de *Informes*, la misma
  página (`reports/business-summary`, ruta `business_summary_reports`, prop `embedded`:
  el marco de Informes pone el título). En Casos sigue para los agentes autorizados (a
  Informes solo entran administradores). Ambos ítems usan `visibleGetter`.
- **Se quitó el reporte viejo «Oportunidades»** de Informes (ruta, menú y
  `OpportunityReports.vue`; lo cubren los Números de Comercial). Los endpoints v2 de
  case_reports que usaba (funnel, outcome, timeseries…) quedan en el backend.
- **Conversaciones** (`BusinessSummaryConversations`): mismas cifras que *Informes →
  Conversaciones* (MetricBuilder: nuevas, resueltas, primera respuesta y resolución, con
  comparación; ReportBuilder: abiertas / sin atender / sin asignar), CSAT, por canal y las
  5 etiquetas más usadas. «Conversaciones sin atender» entra en «Lo que necesita tu
  atención» (2.º lugar; abre la vista *Sin atender* de Chatwoot).
- **Análisis con IA, a pedido** (`Cases::Ai::ConversationAnalyst`, acción
  `conversation_analysis`, `POST case_reports/business_summary_conversations_ai`): muestra
  de 150 conversaciones del período (por última actividad), 8 mensajes por conversación
  sin notas privadas, y si el contacto tiene oportunidad abierta. Devuelve temas, quejas
  que se repiten, ventas que se escapan (preguntó precio y sin oportunidad) y clientes
  molestos, con enlaces a las conversaciones (ids filtrados contra la muestra). En el
  front, CalcGate con memoria del día (`caseMetricsCalc`). Manda el texto a OpenAI.
- **Menú de Casos:** Lista · Tablero · Tareas · Métricas · Resumen del negocio.
