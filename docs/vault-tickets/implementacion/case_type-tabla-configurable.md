---
titulo: ⭐ case_type ahora es tabla configurable (NO enum)
tipo: implementación
tags: [tickets, case_type, arquitectura, breaking]
---


Todo lo de arriba era el **diseño**. Esta sección documenta lo que **realmente se construyó** en la rama `feat/tickets`, con rutas exactas y los problemas que se resolvieron durante la implementación.

## ⭐ CAMBIO ARQUITECTÓNICO: `case_type` ahora es configurable por cuenta (NO es enum)

El diseño original tenía `case_type` como **enum fijo** (`support, commercial, ...`). Se rediseñó a una **tabla `case_types` configurable por cuenta** (como labels/teams de Chatwoot). **El enum `case_type` YA NO EXISTE en `CaseTicket`** — no buscarlo.

**Modelo de datos actual:**
- Tabla `case_types`: `account_id`, `name`, `color` (hex), `position`. Modelo `CaseType` con `ensure_defaults_for(account)` (lazy seed: crea 5 tipos por defecto si la cuenta no tiene ninguno).
- `case_tickets.case_type_id` → FK a `case_types` (nullable; `dependent: :nullify` al borrar un tipo).
- `CaseTicket` tiene `belongs_to :case_type, optional: true`. **Ya no hay enum ni `validates :case_type`.**

**Migraciones del rediseño:**
- `20260604000004_create_case_types.rb`
- `20260604000005_add_case_type_id_to_case_tickets.rb`
- `20260604000006_migrate_case_types_data.rb` — crea los 5 tipos por cuenta (solo cuentas con tickets/reglas), reasigna `case_tickets` por el viejo entero del enum, convierte las condiciones de `case_rules` (`value` slug→id), y **elimina la columna enum vieja `case_type`**.

**Archivos nuevos del rediseño:**
- Backend: `app/models/case_type.rb`, `app/controllers/api/v1/accounts/case_types_controller.rb` (CRUD), ruta `resources :case_types`.
- Frontend: `api/caseTypes.js`, vista `views/gestorTickets/TicketTypes.vue` (CRUD + paleta de 8 colores + color picker), ruta `gestorTickets_types`, item de sidebar "Tipos de caso" (icono `tag`, label `SIDEBAR.TICKET_TYPES`).
- Store `caseTickets` extendido: estado `types`, getters `getTypes`/`getTypesUIFlags`, actions `fetchTypes/createType/updateType/deleteType`, mutations `SET_CASE_TYPES`/`SET_CASE_TYPES_UI_FLAG`.

**Cómo cambió todo lo demás:**
- **Filtro de lista** (`Index.vue`): `TYPE_FILTERS` era constante hardcoded; ahora es computed desde `store getTypes`. El filtro envía `case_type_id` (no `case_type`).
- **Badges de tipo** (Index/Detail/Panel): antes `$t('CASE_TICKETS.TYPES.${key}')` con clases Tailwind fijas; ahora `ticket.case_type.name` con color inline `:style="{ backgroundColor: ticket.case_type.color }"` y texto blanco. El `ticket.case_type` del JSON es `{ id, name, color }` (o null).
- **RuleEngine**: `field_value('case_type')` devuelve `@ticket.case_type_id` (id), y las condiciones guardan `value` = id del tipo (string). El builder de reglas (`TicketRules.vue`) puebla el dropdown de `case_type` desde `store getTypes` (value=id, label=name).
- **Métricas** (`by_type`): el helper `type_counts` agrupa por `case_type_id` y devuelve `{ nombre_del_tipo => count }`. La dona de tipos usa esos nombres directamente como labels.
- **Modal de creación** (`CaseTicketModal.vue`): el `<select>` de tipo se llena desde `store getTypes`; envía `case_type_id`.
- **OrchestratorService**: `create_for_manual(case_type_id:, ...)` y `find_or_create_from_message` usan `default_case_type` (= primer tipo de la cuenta vía `ensure_defaults_for`).
- **i18n**: la sección `CASE_TICKETS.TYPES` ya NO tiene los slugs (support/commercial); ahora tiene las claves de la página de gestión (TITLE, CREATE_BUTTON, NAME_LABEL, COLOR_LABEL, DELETE_CONFIRM, HELP).

> ⚠️ Al retomar: si ves código que hace `ticket.case_type` esperando un string, o `CaseTicket.case_types` (enum), está DESACTUALIZADO. `case_type` es una asociación a `CaseType`; usar `case_type_id` para filtros/comparaciones y `case_type.name`/`.color` para mostrar.



## 🔗 Relacionado
- Diseño original: [[Modelo-de-datos]]
- [[Trampas]] · [[Historial-de-implementacion]]
