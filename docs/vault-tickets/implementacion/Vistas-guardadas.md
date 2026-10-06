---
titulo: Vistas guardadas del Gestor de Casos (filtros con nombre)
tipo: implementacion
tags: [tickets, filtros, vistas, custom_filters]
---

# Vistas guardadas

Un juego de filtros de la cola, guardado con nombre, que se aplica desde un
selector. Rama `feat/tickets_filtros`. Plan completo en
`docs/tickets_filtros_guardados_plan.md`.

## Lo que define el diseño: no se construyó nada de fondo

Chatwoot ya trae el mecanismo — es el que hace funcionar las **carpetas de
Conversaciones** y los **segmentos de Contactos**. Se reusó entero.

```
   YA EXISTÍA                                  LO QUE SE AGREGÓ
   ──────────                                  ────────────────
   tabla  custom_filters                       · case_ticket en el enum
     account_id · user_id · name                 (valor 3, AL FINAL)
     query jsonb · filter_type enum            · columna shared
                                               · scope visible_for
   API    /accounts/:id/custom_filters         · permisos por registro
     index show create update destroy          · shared/user_id/owner_name
                                                 en el payload
   store  store/modules/customViews.js
     getCustomViewsByFilterType(tipo)          · Index.vue: selector, guardar,
                                                 marca de "modificada"
   UI     customviews/AddCustomViews.vue       · SavedViewsModal.vue
          customviews/DeleteCustomViews.vue
```

## Personal vs compartida

`shared` (boolean, default `false`) distingue una vista propia de una visible
para toda la cuenta. El scope es `CustomFilter.visible_for` — mismo criterio que
`Macro.with_visibility`, con `shared` haciendo el papel de `global`.

```
                      ver    aplicar    renombrar/compartir    eliminar
   ─────────────────────────────────────────────────────────────────────
   mía                  ✓        ✓              ✓                 ✓
   compartida, ajena    ✓        ✓              ✗                 ✗
   compartida, ajena
   siendo admin         ✓        ✓              ✓                 ✓
   personal ajena       ✗        ✗              ✗                 ✗
```

La última fila importa: **un administrador NO puede tocar la vista personal de
un agente**. Manda sobre lo compartido, no sobre lo privado.

## Forma del `query`

```json
{ "v": 1, "search": "", "date_range": ["2026-09-01","2026-09-30"],
  "status": "open", "priority": "high", "origin": "",
  "quick": "unassigned", "case_type_id": 6,
  "sort_by": "created_at", "sort_order": "desc" }
```

- `quick` es la pestaña rápida: `mine` · `unassigned` · `all` · `sla_overdue`.
- **No se guardan `page` ni `per_page`**: son navegación, no criterio. Abrir una
  vista siempre empieza en la página 1.
- `v` es la versión del formato. Hoy nadie se ramifica sobre ella; existe para
  que cuando entren filtros nuevos se pueda distinguir "no lo guardó" de "lo
  guardó vacío" en una vista vieja.

Aplicar es **tolerante a propósito**: clave ausente → se deja el default; clave
desconocida → se ignora; `case_type_id` que ya no existe → cae a "Todos los
tipos" con aviso. Esto último no es hipotético: `case_type` es una tabla
configurable por cuenta ([[case_type-tabla-configurable]]) y alguien puede
borrar un tipo que una vista referencia.

## La marca de "modificada"

Con una vista cargada, `isViewDirty` compara el estado actual contra el `query`
guardado en **forma canónica** — claves ordenadas y defaults resueltos. Hace
falta porque el jsonb vuelve del servidor en cualquier orden y "ausente" y
"vacío" tienen que contar como lo mismo; comparando en crudo, la marca se
encendería sola nada más cargar la vista.

## El tope, que sigue abierto

`CustomFilter::MAX_FILTER_PER_USER = 50` cuenta **todos los tipos juntos**: las
vistas de casos comen del mismo presupuesto que las carpetas de Conversaciones y
los segmentos de Contactos de ese usuario. Se dejó en 50 y el pie del modal lo
dice. Volverlo un tope por tipo queda como decisión abierta.

El número que muestra el modal son solo las vistas de casos, **no** el consumo
total contra el tope: contar los otros tres tipos exigiría tres peticiones más
que además pisarían el store (`SET_CUSTOM_VIEW` reemplaza `records`), o exponer
el total desde la API.

## Archivos

| Archivo | Qué hace |
|---|---|
| `db/migrate/20260904180000_add_shared_to_custom_filters.rb` | columna `shared` + índice `(account_id, filter_type, shared)` |
| `app/models/custom_filter.rb` | `case_ticket: 3`, `visible_for`, `owned_by?` |
| `app/policies/custom_filter_policy.rb` | permisos por registro en show/update/destroy |
| `app/controllers/api/v1/accounts/custom_filters_controller.rb` | scope nuevo + autorización del registro |
| `app/views/api/v1/models/_custom_filter.json.jbuilder` | `shared`, `user_id`, `owner_name` |
| `gestorTickets/Index.vue` | selector, guardar como, marca de modificada, engrane |
| `gestorTickets/SavedViewsModal.vue` | renombrar, compartir, eliminar |
| `customviews/AddCustomViews.vue` | tipo como String + casilla `allow-shared` |
| `spec/models/custom_filter_spec.rb` | fija los cuatro valores del enum |
| `spec/requests/api/v1/accounts/custom_filters_shared_spec.rb` | visibilidad y permisos |

## 🔗 Relacionado
- [[Trampas]] · [[UI-y-API]] · [[case_type-tabla-configurable]] · [[Historial-de-implementacion]]
