# Plan — Métricas de Comercial en 4 pestañas

> Rama `feat/nva_oportunidad` · 2026-10-21 · relacionado: [[Plan-Clase-Comercial]], [[Trampas]]

## Decisiones (2026-10-21)

1. Pestañas por **la pregunta que responde cada una** (nombres pensados para el dueño):
   **¿Cómo vamos?** · **Dinero en juego** · **Mes a mes** · **¿Por qué perdemos?**
2. Filtros de toda la página arriba (tipo, vendedor, equipo, período); cada pestaña agrega
   los suyos debajo.
3. **Botón «Calcular»** solo donde el cálculo pesa: **estancadas** (Dinero en juego) y **Mes a
   mes**. Lo demás carga solo. El botón recuerda el resultado con su hora («Calculado hace 5
   min · Actualizar»), no se pierde al cambiar de pestaña, sobrevive el mismo día en el
   navegador y, si cambian los filtros, avisa «Los filtros cambiaron · Recalcular» en vez de
   recalcular solo.
4. **Conversión entre etapas: fuera por ahora.**
5. Colores solo del tema del proyecto (ver Trampas #26: no hay `blue` ni `emerald`).

## Fases

- **M1 — Reacomodo + ¿Cómo vamos?** 4 pestañas (la vieja «Generales»/«Embudo» se migra);
  indicadores con ▲▼ contra el período anterior (ganado, tasa de cierre, ticket promedio,
  días para cerrar, recuperadas); ranking de vendedores; por tipo.
- **M2 — Dinero en juego.** Indicadores (en juego, ponderado, abiertas, cierra este mes); el
  embudo con «Calcular estancadas» y ⚠ por franja; pronóstico (se mueve de Generales); lista
  «Requieren atención» (cierre vencido + estancadas).
- **M3 — Mes a mes** (con «Calcular»): ganadas vs perdidas por mes (cantidad / monto), tasa de
  cierre por mes (gráfica aparte, nunca doble eje) y oportunidades nuevas por mes. Últimos 12
  meses.
- **M4 — ¿Por qué perdemos?** Motivos de pérdida (cantidad y monto) y de cancelación.

## Estado

- [x] M1–M4 (2026-10-21).
  - Front: `commercial/CommercialMetrics.vue` (armazón: filtros, pestañas, reporte compartido;
    migra la pestaña guardada `general`→`overview`, `funnel`→`money`) y
    `commercial/metrics/{OverviewTab,MoneyTab,MonthlyTab,LossesTab,CalcGate,KpiTile}.vue`;
    `CommercialFunnel.vue` vive dentro de «Dinero en juego» y pinta ⚠ por franja con las
    estancadas. Helpers: `caseMetricsCalc.js` (memoria del «Calcular»: misma llave de filtros
    y mismo día), `caseMetricsDelta.js` (▲▼; montos solo con una misma moneda),
    `caseCommercial.js#moneyList`.
  - Back: `PipelineBuilder` + `previous` (mismo largo, período anterior), `attention` (cierre
    vencido, mayor monto primero), `summary.closing_this_month`, `loss_reasons[].values`; lo
    abierto se movió a `PipelineOpenParts` (largo de clase). A pedido:
    `GET case_reports/pipeline_stale` (`PipelineStaleBuilder`: días desde el último cambio de
    ETAPA = `column_changed` o transición; umbral 7/15/30) y `GET case_reports/pipeline_monthly`
    (`PipelineMonthlyBuilder`: 12 meses fijos, ganadas/perdidas por `outcome_at`, nuevas por
    `created_at`, tasa).
  - Gráficas: Mes a mes con ganadas (verde oscuro) vs perdidas (gris claro) — se distinguen
    por claridad, no solo por tono —; la tasa en su propia gráfica (sin doble eje); tooltip y
    vista de tabla en cada bloque.
  - Abrir una oportunidad desde «Dinero en juego» manda `?back=<ruta de métricas>`; el caso
    cambia «Volver» por «Volver a métricas» y regresa ahí (la pestaña y los filtros se
    restauran del estado guardado; «Calcular» conserva su resultado del día). `TicketDetail`
    solo acepta rutas internas (`/app/…`).

## Período de calendario (2026-10-21)

Los «últimos 7/30/90 días» cortaban los meses y la comparación quedaba rara. Cada
pestaña mira un tiempo distinto, así que el filtro de tiempo depende de la pestaña:

| Pestaña | Tiempo | Filtro |
|---|---|---|
| ¿Cómo vamos? / ¿Por qué perdemos? | pasado (lo decidido) | período de calendario arriba |
| Dinero en juego | presente + futuro | sin período: chip «Foto de hoy»; su filtro es el cierre estimado |
| Mes a mes | tendencia | ventana propia: últimos 12 meses · este año · año pasado (`span`) |

- Períodos (`helper/caseMetricsPeriod.js`, `filters/CalendarPeriodPicker.vue`): Este mes
  (inicial) · Mes pasado · Este trimestre · Trimestre pasado · Este año · Año pasado ·
  Personalizado (dos fechas, el «hasta» incluido). Se quitó «Todo» (sin comparación y
  mezcla años). Los guardados viejos (7d…all) caen en «Este mes».
- Comparación justa: el front manda `prev_since`/`prev_until` (PipelineBuilder los usa; sin
  ellos, mismo largo justo antes). En curso → mismo tramo del anterior (1–21 oct vs 1–21
  sept); cerrado → el anterior completo; personalizado → mismo largo antes. La flecha dice
  «▲ $500 vs 1–21 sept» y la línea de ayuda «1–21 oct comparado con 1–21 sept».
- Las Métricas de TODAS las clases usan el mismo período (Soporte, Órdenes y Proyectos
  también): estado común en `mixins/caseMetricsPeriodMixin.js` (`restorePeriod`,
  `periodState`, `setPeriod`, `setCustom`, `periodRangeOf`). Soporte manda días locales
  (`date_from`/`date_to`, el «hasta» incluido); Órdenes/Proyectos, epoch `since`/`until`.
  Solo Comercial compara (▲▼). Se borró `MetricsPeriodPicker` y `METRIC_PERIODS`.

## Comprometidas por el cliente (2026-10-21)

«Esta semana te pago»: ya no es una venta en proceso más, pero tampoco ganada (no hay dinero).

- **Una sola fecha** (decisión del usuario): la casilla ☐ «Comprometida por el cliente»
  convierte `expected_close_at` de estimado del vendedor en la fecha que prometió el
  cliente (la etiqueta cambia a «Fecha comprometida» y es obligatoria). Dos fechas
  chocaban: ¿cuál cuenta en el pronóstico?, una se queda vieja, cuenta doble.
- Datos: `case_tickets.committed_at` (cuándo se marcó; nil = no) + `commit_note`
  (migración 20261026120000). `committed=` es atributo virtual (está en
  `COMMERCIAL_FIELDS`; las columnas que se registran, en `COMMERCIAL_COLUMNS`).
  Desmarcar borra marca y nota. Validación: comprometida sin fecha no guarda.
- Historial: evento `commitment_changed` (enum 41) con `action` set · moved (from/to) ·
  removed · note. Monto/fecha siguen en `amount_changed`.
- Formularios: `commercial/CommitmentFields.vue` (casilla + nota) en el alta
  (`CaseTicketModal`), alta/edición interna (`CaseTicketInternalModal`) y el panel del
  detalle (`CommercialPanel`).
- Lista y Tablero: pastilla «Comprometida · 24 oct» (teal) o «Promesa vencida · 24 oct»
  (roja). Filtro: casilla **«Solo comprometidas»** en la barra (`CaseScopeBar`, junto al
  aviso), decisión del usuario en vez de un resultado del combo: se SUMA a todo (resultado,
  filtros finos, búsqueda) y al aviso «Cierre vencido» (siempre con ese nombre), que con
  la casilla cuenta y filtra las comprometidas vencidas (el backend aplica `committed`
  también a `class_alert_scope`). Se guarda por clase y en las vistas (`committed`).
- Métricas (`PipelineCommitmentParts`):
  - Dinero en juego: «Comprometido esta semana» y «Comprometido este mes» (+ promesas
    vencidas); «Cierra este mes» = confirmado (comprometidas) + probable (sin compromiso,
    ponderado), ninguna cuenta doble; pronóstico con columna «Comprometido»; filtro de
    cierre «Esta semana»; «Requieren atención» con las promesas vencidas primero
    (`reason: promise_overdue | close_overdue`).
  - ¿Cómo vamos?: «Promesas cumplidas» = comprometidas decididas en el período que se
    ganaron a más tardar en la fecha prometida y sin moverla (evento `moved`), con ▲▼.
- Sin tarea automática al vencer la promesa (el usuario no la pidió): basta «Requieren
  atención» y la pastilla roja.

## Filtros: una sola fecha (2026-10-21, todas las clases)

Antes «Filtros» tenía un control por fecha (cierre estimado, fecha de cierre, alta
desde–hasta, visita, fecha objetivo), cada uno con opciones distintas: no se entendía
cuál era cuál, no había «esta semana» para el cierre y el único rango libre era el alta.
Decisión del usuario: **una fecha a la vez**, en las 4 clases.

- `helper/caseFilters.js`: el filtro fino `date` = `date_field` + `date_preset`
  (+ `date_from`/`date_to` si es `custom`). `DATE_FIELDS_BY_CLASS` (la primera es la
  de entrada): Soporte alta · cerrado; Comercial cierre/promesa · ganada o perdida · alta;
  Orden visita · alta · cerrado; Proyecto fecha objetivo · alta · cerrado.
- «¿Cuándo?» según la fecha: hacia adelante (cierre, visita, objetivo) vencidas · hoy ·
  esta semana · próxima semana · este mes · próximo mes · próximos 30 · personalizado;
  ya ocurridas (cerrado, alta) hoy · esta semana · este mes · mes pasado · últimos 30 ·
  últimos 90 · personalizado. `dateRange` (semana lunes–domingo) y `dateFilterParams`
  (misma API de siempre: expected_close_*, visit_* / visit_overdue, project_due_*,
  closed_*, date_from/to).
- Qué fechas se ofrecen depende de lo que se ve (`dateFieldApplies`, mismas reglas que
  antes). Si la elegida deja de aplicar NO salta a otra: solo no cuenta.
- `normalizeFineFilters` traduce lo guardado (estado local y vistas guardadas) con la
  forma vieja: se queda la primera fecha (cierre/visita/objetivo, cerrado, alta).
- Se puede perder: dos fechas a la vez (p. ej. creadas en agosto que cierran este mes).
