---
titulo: Índice — Contact Tracking (Seguimientos IA)
tipo: indice
tags: [contact-tracking, indice, moc]
---

# 📞 Contact Tracking — Bóveda de conocimiento

Base de conocimiento del módulo de **seguimientos automáticos con agente IA** de
Wintook/Kontrolya (rama `dashboard_contact_tracking`). Cada nota es atómica y
enlazada con `[[wikilinks]]`. Esta bóveda es la versión **navegable** del skill
`@contact_tracking`; el skill en `~/.claude/commands/contact_tracking.md` quedó como
índice delgado que apunta aquí (para que Claude cargue solo lo relevante).

> **Convención del módulo:** tablas/columnas/enums y **código en inglés**; etiquetas
> de **UI en español** (i18n `es`/`en`). Migraciones siempre al final. **1 solo
> tracking activo por contacto** (índice único). **No hay feature flag**: el módulo
> está siempre activo. Commit solo cuando se pida.

---

## 🧭 Empezar aquí (al retomar)

1. [[Vision-y-convenciones]] — qué es, casos de uso, capas, reglas del módulo
2. [[Ciclo-de-vida]] — 7 estados y transiciones (pause/resume/cancel/complete/fail)
3. [[Estado-actual]] — qué está completo vs parcial vs pendiente
4. [[Archivos-reales]] — mapa exacto de archivos backend/frontend

---

## 📐 Diseño

- [[Vision-y-convenciones]] — propósito, casos de uso, capas, convenciones es/en
- [[Modelo-de-datos]] — `contact_trackings` + `tracking_templates`: columnas, índices, migraciones
- [[Ciclo-de-vida]] — estados, transiciones, scopes, métodos del modelo
- [[Servicios-y-jobs]] — RouterService, BulkAssign, Import, KeywordAction, AvailabilitySlot + jobs
- [[Frontend]] — componentes Vue, stores Vuex, api clients, helpers, composable, i18n
- [[API-y-rutas]] — endpoints REST + variables de entorno

## 🛠️ Implementación (estado real)

- [[Archivos-reales]] — rutas exactas backend + frontend construidas
- [[Bulk-assign]] — asignación masiva por filtro (commit `8cae85fd`), límite 30
- [[Importacion-excel-csv]] — parser nativo XLSX/CSV, normalización E.164, límite 50
- [[Estado-actual]] — qué está hecho y qué falta
- [[Pendiente]] — tareas abiertas e integraciones a medias

---

## 🗺️ Mapa del módulo

```
   CONTACTO ──┬─ tracking individual (TrackingForm) ──┐
              ├─ asignación masiva (BulkAssign) ───────┤
              └─ importación Excel/CSV ────────────────┤
                                                       ▼
                            ContactTracking (status: pending→scheduled→active)
                                                       │
                  ExecutePendingJob (cron */5) ─► ContactTrackingJob (envío IA / plantilla WA)
                                                       │
                        respuesta del contacto ─► ResponseAnalyzerJob ─► RouterService
                                                       │
              ┌────────────────────────────────────────┼─────────────────────────────┐
        :reschedule/:book   :interested/:rejected   :kbase   :botseller   keyword_actions
```
