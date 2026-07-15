---
titulo: Reuso y arquitectura
tipo: implementacion
tags: [campanas-vendedor, arquitectura, reuso]
---

# Reuso y arquitectura

## Qué se reusa vs qué es nuevo

| Concepto | En el código hoy | Acción |
|---|---|---|
| "Entrenamiento del Agente" | `tracking_template` (= "Agente IA", `@contact_tracking`) | ✅ reusar |
| "Seleccionar prospectos" | **bulk assign** (`Contacts::FilterService`) | ✅ reusar (ver [[Bulk-assign-hallazgos]]) |
| "El Agente conversa" | `ContactTrackingJob` + RouterService | ✅ reusar |
| "Prospecto" | `ContactTracking` (1 activo por contacto+inbox) | ⭐ extender |
| "Oportunidad/cotización/demo" | **Kanban** (`kanban_process`) + `case_tickets` | ✅ enlazar |
| Señales intención/sentimiento/resultado | `last_intent`, `last_sentiment_analysis`, `outcome` | ✅ reusar |
| Score, Interés, Valor, Prioridad, Resultado, Vendedor, Siguiente acción | — | 🆕 nuevo |
| Agrupar y medir como "Campaña" | — | 🆕 `TrackingCampaign` |
| Dashboard KPIs+embudo | `contactTrackings/Dashboard.vue` | ✅ extender |

## Diagrama
```
┌──────────── Campañas (Agente Vendedor) — NUEVO ─────────────┐
│ TrackingCampaign ── tracking_template (Entrenamiento)           │
│      │ iniciar → bulk assign (Contacts::FilterService)       │
│      ▼                                                       │
│ TrackingCampaignProspect ─▶ ContactTracking ─▶ ContactTrackingJob (IA)
│      │ score/interés/resultado/valor      (Router, WhatsApp) │
│      │        ▲ analyzer de conversación (extiende el actual)│
│      ▼                                                       │
│ Dashboards (KPIs, embudo, cola) ── enlaza ─▶ Kanban / Tickets│
└──────────────────────────────────────────────────────────────┘
```
El **Paso 5** (el Agente conversa) funciona "gratis" reusando `@contact_tracking`. Lo nuevo
es el agrupador + capa comercial + las 7 vistas ([[Las-7-vistas]]).
