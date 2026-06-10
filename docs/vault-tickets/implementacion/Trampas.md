---
titulo: ⚠️ Trampas descubiertas (CRÍTICO al retomar)
tipo: trampa
tags: [tickets, trampas, gotchas, critico]
---

## ⚠️ Decisiones técnicas / trampas descubiertas (CRÍTICO al retomar)

1. **`assignee_type` necesita `_prefix: :assignee`** — colisiona con el enum `origin` (ambos tienen valor `bot`, generan método `bot?`). Sin el prefijo, el modelo no carga. Métodos resultantes: `assignee_bot?`, `assignee_agent?`, etc.

2. **`default-sidebar.js` vs `default-sidebar.jsx`** — EXISTEN AMBOS. Webpack resuelve `.js` primero al importar sin extensión. Editar SIEMPRE el `.js`. Editar solo el `.jsx` no tiene efecto (perdimos tiempo con esto).

3. **Iconos Fluent limitados** — solo existen ~205 iconos en `app/javascript/shared/components/FluentIcon/dashboard-icons.json`. Iconos válidos usados: `clipboard`, `list`, `document`, `settings`. NO existen: `task-list-square-ltr`, `list-bar`, `data-bar-vertical`, `ticket-diagonal`, `arrow-sort-up`, `arrow-sort-down` (solo existe `arrow-sort`; para asc/desc usar `chevron-up`/`chevron-down`). Sí existen: `search`, `dismiss`, `chevron-up`, `chevron-down`, `number-symbol`. Verificar SIEMPRE contra ese JSON antes de usar un icono.

4. **Labels del sidebar van en `settings.json` bajo `SIDEBAR.*`** — el componente prepend `SIDEBAR.` al label. Por eso las claves son simples (`TICKETS`, `ALL_TICKETS`) en `settings.json`, NO rutas largas tipo `CASE_TICKETS.SIDEBAR.X`.

5. **`shouldShowSecondarySidebar` en `Sidebar.vue`** — el sidebar secundario respeta una preferencia de UI del usuario que puede ocultarlo. Para forzarlo (igual que Kanban), las rutas `gestorTickets_*` se agregaron al array `alwaysShowRoutes`.

6. **`:on-close` del modal** — debe ser `:on-close="() => $emit('close')"`, NO `:on-close="$emit('close')"`. La segunda forma ejecuta el emit en el render y cierra el modal al instante de abrirlo.

7. **Modal sin tamaño `large`** — `Modal.vue` solo define `medium` (900px). Usar `size="medium"`; `size="large"` no aplica ancho.

8. **`Modal.vue` aplica CSS global `self-center` a todo `<form>`** — el bloque `.modal-container form { @apply pt-4 pb-8 px-8 self-center; }` afecta a CUALQUIER `<form>` dentro de un modal (no es scoped). El `self-center` (align-self: center) impide que el form ocupe el ancho completo → queda angosto y centrado con margen lateral irregular (se nota al comparar un form corto vs uno largo). **Solución:** en el form propio agregar las clases Tailwind `self-stretch w-full` (o `align-self: stretch; width: 100%; box-sizing: border-box;` en CSS). El `px-8` global = 32px ya coincide con el `px-8` del `woot-modal-header`. Aplica a cualquier modal con formulario del proyecto.

9. **Las vistas deben llenar el ancho con `flex-1 w-full`** — el router monta las vistas dentro de `<section class="flex flex-1 h-full">` en `Dashboard.vue`. Una vista cuyo div raíz NO tenga `flex-1 w-full` se queda con su ancho de contenido y deja **espacio en blanco a la derecha** (muy visible en dark mode, el body queda claro). Raíz correcta: `flex flex-col flex-1 w-full h-full overflow-hidden`. `kanbanBoard.vue` usa el mismo patrón.

10. **Migración a Tailwind + dark mode (hecha)** — las 7 vistas/componentes se reescribieron de SCSS scoped + `var(--*)` a clases Tailwind utility-first con variante `dark:`. El proyecto tiene esta versión ya migrada (igual que `reports/overview`). Patrón de color del proyecto: cards `bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700`, texto `text-slate-800 dark:text-slate-100` / `text-slate-600 dark:text-slate-300`, badges `bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300`, fondos suaves `bg-green-50 dark:bg-green-900/20`. **No usar `<style scoped>` con `var(--color-*)`** — rompe dark mode (colores fijos sobre fondo oscuro).

11. **⚠️ Feature flags = bitfield ordenado por posición en `config/features.yml`** — `app/models/concerns/featurable.rb` usa **FlagShihTzu** sobre la columna `accounts.feature_flags` (bigint, 64 bits). El mapeo bit→feature se construye así:
    ```ruby
    FEATURE_LIST = YAML.safe_load(.../features.yml')
    FEATURES = FEATURE_LIST.each_with_object({}) { |f, r| r[r.keys.size + 1] = "feature_#{f['name']}".to_sym }
    ```
    El bit de cada feature = su **índice (orden) en el YAML**. ⇒ **Agregar features SIEMPRE al final del archivo.** Insertar/eliminar/reordenar en medio desplaza los bits y **corrompe los flags ya guardados de TODAS las cuentas**. (Al cierre había 52 features; `case_management` quedó en bit 53.)

12. **`FEATURE_LIST` es constante congelada al boot** — tras editar `config/features.yml`, el server Puma en ejecución NO conoce la feature nueva hasta reiniciar (la constante se evalúa una vez al cargar el concern). Reinicio limpio: `touch tmp/restart.txt` (puma tiene `plugin :tmp_restart` en `config/puma.rb`). Un `rails runner` arranca proceso nuevo y SÍ la ve de inmediato (útil para seedear/togglear sin tocar el server).



## 🔗 Relacionado
- [[Pruebas-en-browser]] · [[Feature-flag-case_management]] · [[Historial-de-implementacion]]
