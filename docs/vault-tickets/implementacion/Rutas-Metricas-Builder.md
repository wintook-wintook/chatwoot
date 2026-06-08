---
titulo: Rutas frontend + endpoint de métricas + builder de reglas
tipo: implementación
tags: [tickets, rutas, metricas, charts, reglas]
---

## Rutas frontend reales

```
/accounts/:accountId/tickets          → gestorTickets_index    (agente + admin)
/accounts/:accountId/tickets/metrics   → gestorTickets_metrics  (agente + admin)
/accounts/:accountId/tickets/rules     → gestorTickets_rules    (solo admin)
/accounts/:accountId/tickets/:id       → gestorTickets_detail   (agente + admin)
```
⚠️ El orden importa: `metrics` y `rules` van ANTES de `:id` para que no se interpreten como ID.

## Endpoint de métricas (Fase 5)

`GET /api/v1/accounts/:id/case_tickets/metrics?date_from=&date_to=`

Devuelve: `summary` (total, total_open, sla_overdue, sla_at_risk, avg_resolution_minutes, sla_compliance_rate, resolved_this_period), `by_status`, `by_type`, `by_priority`, `by_sla_status`. La vista `Metrics.vue` usa **charts reales de vue-chartjs** (no barras CSS) y selector de período 7d/30d/90d/Todo.

### Gráficas (vue-chartjs / chart.js 2.9.4)

- **Por estado** → `BarChart` (barra vertical) — `app/javascript/dashboard/components/widgets/chart/BarChart.js` (ya existía).
- **Por tipo / prioridad / SLA** → `DoughnutChart` (donas) — `DoughnutChart.js` se CREÓ en este proyecto (el repo solo tenía `BarChart` y `HorizontalBarChart`). Sigue el mismo patrón `extends: Doughnut` + props `collection`/`chartOptions` + `watch` para re-render.
- Colores en **hex** (chart.js no entiende clases Tailwind): prioridad `{low:#94a3b8, medium:#3b82f6, high:#eab308, urgent:#ef4444}`, SLA `{on_time:#22c55e, at_risk:#eab308, overdue:#ef4444}`.
- Cada chart usa `:key="'tipo' + chartKey"` donde `chartKey = selectedPeriod`, para forzar re-mount al cambiar de período (chart.js 2.x no siempre re-renderiza solo).

> 🐛 **BUG CRÍTICO corregido en `enum_counts` (controller)** — `tickets.group(:status).count` en **Rails 7 devuelve las claves como STRING del enum** (`"open"`), no como entero. El código original buscaba `raw[enum_map[key]]` (= `raw[0]`, entero) → todas las distribuciones daban **0 aunque hubiera tickets** (el `summary.total` sí funcionaba). Fix: `h[key] = raw[key] || raw[enum_map[key]] || 0` (cubre ambos casos). Bug silencioso: sin datos reales en la BD nunca se detecta. **Verificar siempre las métricas con tickets de varios tipos/prioridades cargados.**

## Builder visual de reglas (mejora post-diseño)

`TicketRules.vue` NO usa textareas de JSON crudo (eran confusos para el usuario). Usa un **builder visual** con dropdowns:
- Sección **SI** (badge azul): filas `[campo] [operador] [valor]` — el tipo de input del valor cambia según el campo (select para enums, number para tiempo, text para mensaje).
- Sección **ENTONCES** (badge verde): filas `[tipo de acción] [valor]` — el valor cambia según la acción (select de prioridad/estado, text para agente/equipo, sin valor para escalate/close).
- Botones "+ Agregar condición" / "+ Agregar acción".
- El modal usa `size="medium"` (900px). El grid de condiciones es `1fr 160px 1fr 28px`; el de acciones `1fr 1fr 28px` (clase `.builder-row--action`).



## 🔗 Relacionado
- [[Trampas]] (charts vue-chartjs) · [[UI-y-API]]
