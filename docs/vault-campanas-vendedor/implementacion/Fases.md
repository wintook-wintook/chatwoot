---
titulo: Fases del MVP
tipo: implementacion
tags: [campanas-vendedor, fases, plan]
---

# Fases (MVP incremental)

```
F1  Modelo: TrackingCampaign + TrackingCampaignProspect (+ migraciones, CRUD admin)
F2  Crear campaña: wizard (entrenamiento + objetivo + selección de contactos vía bulk)
F3  Iniciar: genera ContactTrackings; el Agente ya conversa (reuso total)
F4  Capa comercial: analyzer setea score/interés/resultado/valor por conversación
F5  Vista 1 (listado) + Vista 3 (prospectos) con filtros/orden/acciones
F6  Vista 2 (Dashboard Ejecutivo) + embudo + KPIs
F7  Vista 4 (cola vendedor) + Vista 5 (resultados $) + Vista 6 (rendimiento)
F8  Vista 7 (detalle) + enlaces a Kanban/cotización/CRM
```

> **F2/F3 = el fix del bulk** ([[Bulk-assign-hallazgos]]): mover a job en background +
> inbox fijo + agrupar bajo `TrackingCampaign`. Es la deuda que esta rama (`fix/bulk_tracking`)
> ya tenía sobre la mesa.

Estado: **ninguna fase implementada** (solo plan consolidado). Antes de F1 resolver las
decisiones de [[Pendiente]].
