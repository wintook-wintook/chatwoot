# Gestor de Tickets — Fase 5: Métricas y Reportes

**Proyecto:** Gestor de Tickets (Motor de Gestión de Casos Inteligente)  
**Rama:** `feat/tickets`  
**Fecha de implementación:** 2026-06-04  
**Estado:** ✅ Completo  
**Depende de:** Fases 0–4

---

## Qué se implementó

Fase 5 agrega un dashboard de métricas con selector de período, 7 KPIs resumen y 4 gráficas de distribución (CSS puro, sin librerías externas). El backend expone un endpoint dedicado que calcula todas las agregaciones con una sola pasada por la BD.

---

## Archivos creados

| Archivo | Función |
|---------|---------|
| `views/gestorTickets/Metrics.vue` | Vista de métricas con cards y barras |

## Archivos modificados

| Archivo | Qué se agregó |
|---------|---------------|
| `controllers/api/v1/accounts/case_tickets_controller.rb` | Acción `metrics` + 4 helpers privados |
| `config/routes.rb` | `get :metrics` en collection de `case_tickets` |
| `api/caseTickets.js` | Método `getMetrics(params)` |
| `store/modules/caseTickets.js` | Estado `metrics`, getter `getMetrics`, acción `fetchMetrics` |
| `store/mutation-types.js` | Constante `SET_CASE_METRICS` |
| `routes/dashboard/gestorTickets/routes.js` | Ruta `gestorTickets_metrics` |
| `sidebarItems/gestorTickets.js` | Item "Métricas" en el menú secundario |
| `i18n/locale/es/gestorTickets.json` | Namespace `METRICS` (15 claves) + `SIDEBAR.METRICS` |
| `i18n/locale/en/gestorTickets.json` | Namespace `METRICS` (15 claves) + `SIDEBAR.METRICS` |

---

## Endpoint

### `GET /api/v1/accounts/:account_id/case_tickets/metrics`

**Query params opcionales:**

| Param | Tipo | Default |
|-------|------|---------|
| `date_from` | date (YYYY-MM-DD) | hace 30 días |
| `date_to` | date (YYYY-MM-DD) | hoy |

**Respuesta:**

```json
{
  "period": { "from": "2026-05-05", "to": "2026-06-04" },
  "summary": {
    "total": 45,
    "total_open": 12,
    "sla_overdue": 3,
    "sla_at_risk": 2,
    "avg_resolution_minutes": 187.5,
    "sla_compliance_rate": 84.2,
    "resolved_this_period": 18
  },
  "by_status": {
    "open": 5, "classified": 2, "in_progress": 3,
    "waiting_on_customer": 1, "waiting_on_internal": 1,
    "escalated": 0, "resolved": 15, "closed": 3, "cancelled": 15
  },
  "by_type": {
    "support": 20, "commercial": 12, "implementation": 8,
    "internal_tracking": 3, "system_incident": 2
  },
  "by_priority": { "low": 5, "medium": 20, "high": 15, "urgent": 5 },
  "by_sla_status": { "on_time": 8, "at_risk": 2, "overdue": 3 }
}
```

### Cálculos del backend

| Métrica | Cálculo |
|---------|---------|
| `total_open` | Tickets en la cuenta (sin filtro de período) con status ≠ closed/cancelled |
| `sla_overdue` | `total_open` con `sla_status = overdue` |
| `sla_at_risk` | `total_open` con `sla_status = at_risk` |
| `avg_resolution_minutes` | `AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60)` sobre tickets resolved/closed con `resolved_at` no nulo, dentro del período |
| `sla_compliance_rate` | `(on_time + at_risk) / total_resolved_closed * 100` — tickets cerrados/resueltos dentro del período |
| `resolved_this_period` | Tickets con `status IN (resolved, closed)` dentro del período |
| `by_*` | `GROUP BY` con conversión de enum int → string key |

---

## Vista `Metrics.vue`

### Selector de período (pills)

| Opción | Rango |
|--------|-------|
| 7 días | `date_from = hoy - 7d` |
| 30 días | `date_from = hoy - 30d` (default) |
| 90 días | `date_from = hoy - 90d` |
| Todo | Sin filtro de fecha |

### Cards resumen (7 KPIs)

| Card | Color dinámico |
|------|---------------|
| Tickets en el período | — |
| Tickets activos (global) | — |
| SLA vencidos | Rojo si > 0 |
| SLA en riesgo | Amarillo si > 0 |
| Cumplimiento SLA % | Verde ≥ 90%, Amarillo ≥ 70%, Rojo < 70% |
| Tiempo promedio resolución | Formateado: Xh Ym |
| Resueltos en el período | Verde siempre |

### Gráficas de distribución (CSS bars)

Cuatro paneles con barras horizontales proporcionales al máximo de cada distribución:

1. **Por estado** — excluye `closed` y `cancelled` para mostrar solo tickets activos
2. **Por tipo** — todos los case_types
3. **Por prioridad** — colores: gris/azul/amarillo/rojo
4. **Por SLA** — colores: verde/amarillo/rojo

Las barras usan `width: (count / max) * 100%` calculado en Vue computed properties. No se usa ninguna librería de gráficos.

---

## Navegación

El menú secundario del sidebar ahora tiene 3 items:

```
[📋] Todos los tickets   → /tickets
[📊] Métricas            → /tickets/metrics
[⚙️] Reglas              → /tickets/rules
```

---

## Resumen completo — todas las fases implementadas

| Fase | Contenido | Archivos nuevos |
|------|-----------|----------------|
| 0 | Migraciones + modelos | 6 (3 migrations + 3 models) |
| 1 | Servicios + jobs + bot | 4 nuevos + 2 modificados |
| 2 | API REST | 3 controllers + routes |
| 3 | Panel derecho conversación | API client + store + 3 componentes Vue |
| 4 | Vista sidebar dedicada | 3 vistas + routes + sidebar config |
| 5 | Métricas y reportes | 1 vista + endpoint backend |

**Total backend:** 6 modelos/migraciones, 3 servicios, 1 job, 3 controllers, 1 endpoint de métricas  
**Total frontend:** 7 vistas/componentes Vue, 1 store Vuex extendido, 2 API clients, sidebar + routing completo
