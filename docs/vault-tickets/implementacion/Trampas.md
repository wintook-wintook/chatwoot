---
titulo: ⚠️ Trampas descubiertas (CRÍTICO al retomar)
tipo: trampa
tags: [tickets, trampas, gotchas, critico]
---

## ⚠️ Decisiones técnicas / trampas descubiertas (CRÍTICO al retomar)

1. **`assignee_type` necesita `_prefix: :assignee`** — colisiona con el enum `origin` (ambos tienen valor `bot`, generan método `bot?`). Sin el prefijo, el modelo no carga. Métodos resultantes: `assignee_bot?`, `assignee_agent?`, etc.

2. **`default-sidebar.js` vs `default-sidebar.jsx`** — EXISTEN AMBOS. Webpack resuelve `.js` primero al importar sin extensión. Editar SIEMPRE el `.js`. Editar solo el `.jsx` no tiene efecto (perdimos tiempo con esto).

3. **Iconos Fluent limitados** — solo existen ~205 iconos en `app/javascript/shared/components/FluentIcon/dashboard-icons.json`. Iconos válidos usados: `clipboard`, `list`, `document`, `settings`. NO existen: `task-list-square-ltr`, `list-bar`, `data-bar-vertical`, `ticket-diagonal`, `arrow-sort-up`, `arrow-sort-down` (solo existe `arrow-sort`; para asc/desc usar `chevron-up`/`chevron-down`). Sí existen: `search`, `dismiss`, `chevron-up`, `chevron-down`, `number-symbol`. Verificar SIEMPRE contra ese JSON antes de usar un icono. **Cómo se resuelve el nombre:** `Icon.vue` busca la clave `${icon}-${type}` con `type` = `outline` por defecto, y si no la encuentra **lanza excepción** — no cae en un icono vacío, revienta el render del componente que lo contiene. Ejemplo real: `icon="save-copy"` no existe (sí `save` y `copy`) y habría tirado la barra de filtros entera.

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

13. **⚠️ `rails db:migrate` dispara `annotate` y se come comentarios ajenos** — el hook post-migrate re-anota TODOS los modelos, y al reescribir el bloque `== Schema Information` **borra los comentarios propios que estén pegados justo debajo** (sin línea en blanco de por medio). Al correr la migración de F0 borró la documentación de `palabra_sinonimo.rb`, `sinonimo_semantico.rb` y `ai_agent_assistant_session.rb`, que no tenían nada que ver con el cambio. **Siempre revisar `git status` después de migrar** y revertir los modelos ajenos (`git checkout -- <archivo>`); si el comentario es tuyo y quieres conservarlo, déjalo separado del bloque de anotación.

14. **Puppeteer: `el.click()` sintético NO cambia las pestañas del detalle** — los
   `woot-tabs-item` son `<li class="tabs-title"><a>` **sin href**, y el handler lo pone
   Vue: un `element.click()` desde `page.evaluate` devuelve OK y no pasa nada (se pierde
   una vuelta creyendo que la pestaña no existe). Hay que clicar con el **mouse real**
   sobre sus coordenadas: `getBoundingClientRect()` → `page.mouse.click(x, y)`. Mismo
   patrón que la trampa #15 con los `<form @submit.prevent>`.

15. **⚠️ Probar el módulo de Reuniones contra el servidor local ESCRIBE en el Google
   Calendar real** — desde F3, dar de alta una reunión encola el espejo y Sidekiq crea
   el evento de verdad, con invitación por correo a quien esté en `attendee_emails`.
   Correr la regresión de la API de F1 tal cual dejó 4 eventos reales en el calendario
   del usuario (dos con un "cliente" inventado). **Antes de tocar la API de reuniones
   contra el server local: preguntar, usar un correo propio de prueba y borrar el
   evento al terminar.** Para probar la lógica sin tocar Google, inyectar un doble
   redefiniendo `GoogleMirrorService#service` y `ReconcileService#service_for`
   (ver `f3_test.rb` en el scratchpad).

16. **Puppeteer: el label de la pestaña incluye el badge** — con contador, el texto
   del tab es `"Tareas\n    \n        1"`, así que comparar `=== 'Tareas'` falla en
   cuanto el ticket tiene datos (y el test pasa a clicar el ítem **del sidebar** que
   se llama igual, aterrizando en la bandeja de tareas). Comparar siempre la
   **primera línea** del `textContent` y restringir el selector a `li.tabs-title a`.

17. **El enum `filter_type` de `CustomFilter` va POR POSICIÓN** — se guarda el entero, no
   el nombre. Un tipo nuevo se agrega **SIEMPRE AL FINAL** (`conversation: 0, contact: 1,
   report: 2, case_ticket: 3`). Insertarlo en medio le cambia el tipo a **todos los filtros
   guardados que ya existen, en todas las cuentas**, sin error ni aviso: los que valían 1
   pasan a leerse como el tipo insertado. Misma familia que el bitfield de `features.yml`.
   `spec/models/custom_filter_spec.rb` fija los cuatro valores para que romperlo falle ahí.

18. **`custom_filters` show/update/destroy no reciben `filter_type`** — el controlador
   nativo buscaba el registro dentro del scope acotado por `params[:filter_type]`, pero en
   esas acciones el tipo viaja **dentro del cuerpo** (`custom_filter[filter_type]`), no en
   la query string. Caía al default `'conversation'` y devolvía **404 sobre vistas que el
   usuario sí puede ver** — incluso siendo su dueño. No se notaba porque el frontend nativo
   nunca edita filtros y al borrar manda `?filter_type=` a mano. Corregido: la búsqueda por
   id se acota por cuenta y visibilidad, no por tipo.

19. **El entorno `test` apunta a la MISMA base que development** — `config/database.yml`
   pediría `chatwoot_test`, pero `POSTGRES_DATABASE=chatwoot_dev` está en el entorno y el
   modo test también se lo come. De ahí el `ActiveRecord::EnvironmentMismatchError` en cada
   corrida de RSpec. Los specs pasan porque hay transacciones con rollback, pero cualquier
   spec que haga `commit`, corra en otro proceso o toque algo fuera de la transacción
   **escribe en la base de desarrollo**. Verificar con
   `rails runner -e test "puts ActiveRecord::Base.connection.current_database"`.

20. **`db:migrate` regenera `schema.rb` con tablas de OTRAS ramas** — la base de dev es
   compartida, así que el schema dumpeado trae tablas que no existen en la rama actual
   (p. ej. `ai_agent_assistant_sessions`, `tracking_template_versions`). Commitearlo mete en
   `develop` un schema que declara tablas de ramas sin mergear. Tras cada migración: revisar
   `git diff db/schema.rb` y **dejar solo lo propio**, editando a mano si hace falta.


## 🔗 Relacionado
- [[Pruebas-en-browser]] · [[Feature-flag-case_management]] · [[Historial-de-implementacion]] · [[Vistas-guardadas]]
