---
titulo: Índice — Campañas con Agente Vendedor IA
tipo: indice
tags: [campanas-vendedor, indice, moc]
---

# 💼 Campañas con Agente Vendedor IA — Bóveda de conocimiento

Módulo (MVP) para desplegar un **Agente Vendedor IA** sobre un **segmento de
prospectos** y medir su desempeño **comercial**. No es un sistema de envíos masivos:
se siente como un **gerente comercial** que responde 3 preguntas por día →
[[Vision-y-convenciones]]. Versión navegable del skill `@campanas_vendedor`.

> **Convención:** tablas/columnas/enums y **código en inglés**; **UI en español**
> (i18n `es`/`en`). Migraciones SIEMPRE al final. **Commit solo cuando se pida.**
>
> **⭐ Se apoya en lo existente:** "Entrenamiento del Agente" = `tracking_template`
> (ver `@contact_tracking`); "seleccionar prospectos" = **bulk assign**; "el Agente
> conversa" = `ContactTrackingJob`. Lo **nuevo** es el agrupador `TrackingCampaign` +
> la capa comercial (score/interés/valor/prioridad/resultado/vendedor). Ver [[Reuso-y-arquitectura]].
>
> ⚠️ **No usar el `Campaign` nativo** de Chatwoot (es de envíos) → modelo nuevo `TrackingCampaign`.

---

## 🧭 Empezar aquí (al retomar)

1. [[Vision-y-convenciones]] — qué es, las 3 preguntas, el flujo de 7 pasos
2. [[Reuso-y-arquitectura]] — qué se reusa vs qué es nuevo + diagrama
3. [[Modelo-de-datos]] — `TrackingCampaign` + `TrackingCampaignProspect`
4. [[Las-7-vistas]] — listado, dashboard ejecutivo, prospectos, cola vendedor, resultados, rendimiento, detalle
5. [[KPIs]] — fórmulas (tasa de respuesta, conversión, autonomía, valor…)
6. [[Bulk-assign-hallazgos]] — revisión del bulk actual (lo que hay que arreglar)
7. [[Fases]] — F1–F8 del MVP
8. [[Pendiente]] — decisiones abiertas y TODOs

---

## 🔗 Relación con otros módulos
- **`@contact_tracking`** — base conversacional (tracking_template, bulk assign, ContactTrackingJob).
- **Kanban (Oportunidades)** — "abrir oportunidad" enlaza a `kanban_process`.
- **`@tickets_cases`** / **Cobranza-ERP** — "cotización / valor" puede enlazar a futuro.
