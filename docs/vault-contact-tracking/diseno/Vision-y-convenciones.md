---
titulo: Visión y convenciones — Contact Tracking
tipo: diseno
tags: [contact-tracking, vision]
---

# Visión y convenciones

## Qué es

**Contact Tracking** es un sistema de **re-enganche automático de contactos** donde
un **agente IA** (no un humano) intenta contactar al cliente en momentos programados,
con reintentos configurables, a través de WhatsApp / Email / API. Cada "tracking" es
la asociación **(contacto + objetivo + programación)** que se ejecuta sola.

Diferencia clave con la asignación normal de Chatwoot: aquí el "agente" es la IA y el
seguimiento es proactivo y programado, no reactivo.

## Casos de uso

- Re-contactar clientes que no respondieron (campañas de re-enganche).
- Recordatorios de cita / cotización con reintentos hasta `max_attempts`.
- Asignar un "Agente IA" (una `tracking_template`) a un **conjunto filtrado** de
  contactos de una sola vez → ver [[Bulk-assign]].
- Cargar seguimientos en lote desde Excel/CSV → ver [[Importacion-excel-csv]].

## Capas

| Capa | Dónde | Detalle |
|---|---|---|
| Datos | `contact_trackings`, `tracking_templates` | [[Modelo-de-datos]] |
| Modelo / ciclo de vida | `app/models/contact_tracking.rb` | [[Ciclo-de-vida]] |
| Servicios | `app/services/contact_trackings/*` + import | [[Servicios-y-jobs]] |
| Jobs | `app/jobs/contact_tracking*` | [[Servicios-y-jobs]] |
| API | controllers en `api/v1/accounts/*` | [[API-y-rutas]] |
| Frontend | `dashboard/...` (Vue + Vuex) | [[Frontend]] |

## Convenciones

- **Código/columnas/enums en inglés; UI en español** (i18n `es` y `en`).
- **1 tracking activo por contacto**: índice único parcial
  `index_unique_active_tracking_per_contact` sobre `(contact_id, status)` para
  estados `pending/scheduled/active/paused`.
- **Sin feature flag**: el módulo está siempre activo (no hay entrada en
  `config/features.yml`). Hay flags de comportamiento por **env var** → [[API-y-rutas]].
- **Migraciones siempre al final**, una por cambio (ver lista en [[Modelo-de-datos]]).
- **Commit solo cuando se pida.**

## Marcadores en el código

Casi todos los archivos del módulo abren con un comentario `proyecto@contact_tracking`
(o variantes `proyecto@bulk_tracking_assign`, `proyecto@import_seguimiento`,
`proyecto@tracking_templates`, `proyecto@bot_seguimiento_calendar`). Útil para
`grep -rn "proyecto@contact_tracking" app/`.
