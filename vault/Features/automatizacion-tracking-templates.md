# Feature: `assign_tracking_template` en Automatizaciones

**Fecha:** 2026-04-20
**Tag:** `proyecto@automatizacion_tracking`
**Skill:** `.claude/commands/proyecto@automatizacion_tracking.md`
**Respaldos:** `.claude/backups/automatizacion_tracking/`

## Qué hace

Nueva acción en automatizaciones que selecciona una plantilla de seguimiento del canal (inbox)
especificado en las condiciones de la regla (`inbox_id = Canal`). Al dispararse, crea un
`ContactTracking` para el contacto de la conversación.

## Archivos modificados

### Backend

**`app/models/automation_rule.rb`**
- Agregado `assign_tracking_template` a `actions_attributes` (whitelist).

**`app/services/action_service.rb`**
- Método `assign_tracking_template(params)`:
  - Busca plantilla por ID en `@account.tracking_templates`.
  - Verifica que el contacto no tenga tracking activo.
  - Crea `ContactTracking` con datos de la plantilla.
  - `scheduled_for = Time.current + 5.minutes`.
  - `retry_interval_value: 1, retry_interval_unit: 'days'`.
  - Rescata `StandardError` y loguea sin bloquear.

### Frontend

**`constants.js`**
- Nueva entrada en `AUTOMATION_ACTION_TYPES`:
  `{ key: 'assign_tracking_template', label: 'Asignar plantilla de seguimiento', inputType: 'search_select' }`.

**`automationHelper.js`** (`getActionOptions`)
- Nuevo parámetro `trackingTemplates`.
- `assign_tracking_template: trackingTemplates || []` en `actionsMap`.

**`useAutomation.js`**
- Getter: `const trackingTemplates = useMapGetter('trackingTemplates/getTemplates')`.
- `getActionDropdownValues(type, conditions = [])` — nuevo param `conditions`: filtra templates por
  `inbox_id` de las condiciones cuando `type === 'assign_tracking_template'`. Sin condición inbox →
  muestra todas las plantillas.

**`AddAutomationRule.vue` y `EditAutomationRule.vue`**
- `:dropdown-values="getActionDropdownValues(action.action_name, automation.conditions)"`.

## Lógica de filtrado

Condición `inbox_id = [Canal X]` → dropdown muestra solo plantillas donde
`template.inbox_id === X`. Sin condición inbox → muestra todas las plantillas disponibles.

**Why:** evitar que el usuario seleccione una plantilla de un canal incorrecto.
**How to apply:** si se extiende la acción o hay bugs de filtrado, revisar
`getActionDropdownValues` en `useAutomation.js` líneas ~218-246.
