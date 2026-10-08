# Publicar prompts de Agentes IA — Plan

Rama: `feat/publicar_prompts` (sale de `develop`, 05/10/2026)

## Objetivo

Un usuario **autorizado desde el super admin** puede publicar el prompt de uno de sus
Agentes IA. Cualquier otra cuenta lo ve en una **Galería de prompts** y lo baja a la suya
como un agente nuevo y suyo, para adecuarlo a sus necesidades.

- **La Galería y la descarga viven SOLO dentro del Asistente de Agentes IA** (decisión
  del 05/10/2026). Bajar un prompt arranca ahí mismo la conversación con el Asistente para
  adecuarlo a la cuenta. No hay botón "Bajar" en la lista de Agentes IA ni en la ficha.

- Solo el usuario autorizado ve el botón **Publicar**. Los demás no ven nada de publicar.
- Bajar un prompt crea una **copia**: lo que la otra cuenta cambie no toca el original, y
  lo que el autor cambie después tampoco toca las copias ya bajadas.

```
 SUPER ADMIN                     CUENTA A (autor autorizado)          CUENTA B, C, ...
 ───────────                     ───────────────────────────          ────────────────
 Usuario #15                     Agentes IA
 [x] Puede publicar prompts ──►    Agente "Ventas grúas"
                                   [ Publicar ] ─────────┐
                                                         ▼
                                            ┌───────────────────────┐
                                            │  published_prompts    │  (foto del prompt,
                                            │  "Ventas grúas" v1    │   sin datos de A)
                                            └──────────┬────────────┘
                                                       │
                                                       ▼
                                                 Asistente de Agentes IA
                                                   └ Galería de prompts
                                                     [ Bajar a mi cuenta ]
                                                       │
                                                       ▼
                                                 Agente nuevo en B (copia)
                                                 + el Asistente lo adecua
                                                   conversando
```

## Lo que hay hoy (revisado en el código)

- El agente es `TrackingTemplate` (`app/models/tracking_template.rb`). El prompt vive en
  `complementary_prompt` + `training_structure` (se regenera sola del texto), más
  `objective`, `ai_context`, `keyword_actions`, `tags`, intervalos.
- Hay campos **atados a la cuenta** que no pueden viajar tal cual: `inbox_id`, `user_id`,
  `kbase_hook_id`, `calendar_integration_ids`, `booking_calendar_ids`, `whatsapp_templates`
  y los archivos `ai_agent_attachments`.
- El super admin de usuarios es Administrate (`app/dashboards/user_dashboard.rb`,
  `SuperAdmin::UsersController`). La tabla `users` ya tiene `custom_attributes` (jsonb).
- Ya existe un `ImportModal.vue` en la pantalla de Agentes IA (importar .md): la Galería
  puede convivir con él.

## Qué viaja y qué no

```
 TrackingTemplate de A                     PublishedPrompt               Agente nuevo en B
 ─────────────────────                     ───────────────               ─────────────────
 name                       ──────────►    title (editable al publicar)  name (+ " (copia)" si choca)
 objective                  ──────────►    objective                     objective
 ai_context                 ──────────►    ai_context                    ai_context
 complementary_prompt       ──────────►    prompt                        complementary_prompt
 keyword_actions            ──────────►    keyword_actions               keyword_actions
 retry_interval_*           ──────────►    retry_interval_*              retry_interval_*
 slots_presentation/tz      ──────────►    settings                      settings
 ── atados a la cuenta ──
 inbox_id, user_id                 ✗                                     vacíos (B los elige)
 kbase_hook_id                     ✗                                     vacío
 calendar_* / booking_*            ✗                                     vacíos
 whatsapp_templates                ✗                                     vacíos
 ai_agent_attachments              ✗ (F6, decisión D3)                   aviso: "faltan archivos"
 tags                              ✗ (son de A)                          vacías
```

Las directivas del prompt que apuntan a recursos de A (`{{nombre_archivo}}`,
`{{doc:}}`, `{{hoja:}}`, `{{consulta:}}`, Base de Conocimiento) **se dejan en el texto**
y al bajar se muestra una lista "Esto tienes que configurar en tu cuenta". No se
reescribe el prompt a escondidas.

## Modelo de datos

```
 users                              published_prompts
 ─────                              ─────────────────
 custom_attributes                  id
   can_publish_prompts: true  ◄──── user_id            (autor)
                                    account_id         (cuenta del autor)
                                    tracking_template_id (origen, nullable si se borra)
                                    title, description, category
                                    objective, ai_context, prompt
                                    keyword_actions, settings (jsonb)
                                    requirements (jsonb: directivas detectadas)
                                    version (int), status (published|unpublished)
                                    downloads_count
                                    published_at, timestamps

 tracking_templates  + published_prompt_id (nullable)  ← de qué publicación salió la copia
```

El permiso va en `users.custom_attributes['can_publish_prompts']` (sin migración en
users). Si se prefiere columna propia, es la decisión D1.

## Fases (una por una, con OK entre cada una)

### F0 — Permiso en el super admin
- Casilla **"Puede publicar prompts de Agentes IA"** en el formulario de usuario del
  super admin (`UserDashboard` FORM/SHOW + `resource_params` del controller).
- `User#can_publish_prompts?`.
- Se manda al frontend en el perfil (`current_user`), para mostrar/ocultar el botón.
- Prueba: marcar/desmarcar en `/super_admin/users/:id/edit` y ver el valor en el perfil.

**✅ Hecho (05/10/2026)**

- Qué se hizo:
  - `User#can_publish_prompts?` / `can_publish_prompts=` (`app/models/user.rb`): lee y
    escribe `custom_attributes['can_publish_prompts']` como verdadero/falso, sin borrar
    las otras llaves de `custom_attributes`.
  - `UserDashboard`: campo `can_publish_prompts` (casilla) en la ficha y en el formulario
    de edición del super admin. Administrate lo permite solo por estar en FORM_ATTRIBUTES.
  - `_user.json.jbuilder`: el perfil manda `can_publish_prompts` siempre (true/false), así
    el frontend lo lee de `currentUser` sin revisar `custom_attributes`.
- Por qué es seguro: el usuario no puede darse el permiso él mismo; la API de perfil no
  acepta `custom_attributes`. Solo pueden escribirlo el super admin y la Platform API
  (que ya es de nivel administrador de la instalación).
- Pila de pruebas:
  1. Super admin → Users → editar un usuario → marcar **Can publish prompts** → guardar.
     La ficha muestra `true`.
  2. Con ese usuario, `GET /api/v1/profile` → `"can_publish_prompts": true`.
  3. Desmarcar → `false`. Un usuario que nunca se tocó → `false`.
  - Ya probado: getter/setter en memoria (marcar, desmarcar, `custom_attributes` vacío)
    y `GET /api/v1/profile` del servidor de dev → `false`. Falta probar la casilla en el
    navegador.

### F1 — Tabla `published_prompts` + modelo
- Migración, modelo `PublishedPrompt`, columna `tracking_templates.published_prompt_id`.
- Servicio `PublishedPrompts::Snapshot`: arma la foto del agente aplicando la tabla
  "Qué viaja" y detecta las directivas que piden configuración (`requirements`).
- Specs del servicio (ojo: RSpec corre contra chatwoot_dev, nada destructivo).

**✅ Hecho (05/10/2026)**

- Qué se hizo:
  - Migración `20261005120000_create_published_prompts`: tabla `published_prompts` y
    `tracking_templates.published_prompt_id`. Si el autor borra su agente, la publicación
    sigue viva (`tracking_template_id` queda vacío). Si se borra la publicación, las copias
    siguen vivas (`published_prompt_id` queda vacío). Un agente tiene **una** publicación
    (índice único): republicar sube `version`, no crea otra.
  - `PublishedPrompt` (`app/models/published_prompt.rb`): estados `published|unpublished`,
    categorías `ventas cobranza soporte agenda atencion otros`, scopes `published`,
    `by_category`, `search` (título o descripción), `ordered`.
  - `PublishedPrompts::Snapshot`: arma la foto según la tabla "Qué viaja". Los ajustes
    vacíos (p. ej. `timezone: ""`) no se copian.
  - `PublishedPrompts::Requirements`: detecta lo que hay que configurar. Usa las mismas
    expresiones del motor (`KnowledgeBase::Directives`, `SheetLookup`,
    `ConsultaDirectiveRenderer`, `AgentAttachments`), así no se desfasan.

    | Directiva en el prompt | kind | name |
    |---|---|---|
    | `{{doc:X}}` | google_doc | X |
    | `{{hoja:X}}`, `{{hoja_buscar: X \| …}}` | google_sheet | X |
    | `{{consulta:conn/nombre(…)}}` | erp_query | conn/nombre |
    | `{{nombre}}` | attachment | nombre |
    | `@buscar_foro(X)` | knowledge_source | X |
    | `@soporte_contpaq(X)` | contpaq_support | X |
    | `@discourse` / `@buscar_articulo` | discourse_integration / article | — |
    | `@agendar_calendar` / `@buscar_predefinidas` | calendar / canned_responses | — |

- `schema.rb` armado a mano solo con lo de esta rama (el dump traía tablas de otras).
- Pila de pruebas:
  - Ya probado con el runner: los 12 tipos de directiva en un texto de prueba; 4 agentes
    reales (#10368 y #10238 Grúas → hoja «Servicio Gruas» + calendario; #11833 y #11678
    ADAM → foro «Foro_Sentidos_Creativos» + calendario); guardar una publicación, buscarla,
    rechazar una segunda del mismo agente y validar campos malos. Todo dentro de una
    transacción que se deshizo (quedaron 0 publicaciones).
  - Specs escritos (`spec/services/published_prompts/`), **sin correr**: RSpec usa la base
    de dev. No escriben nada (usan `build`).

### F2 — API para publicar (solo autorizado)
```
 GET    /api/v1/accounts/:id/tracking_templates/:tid/publication   estado + requisitos que se publicarían
 POST   /api/v1/accounts/:id/tracking_templates/:tid/publication   publica o saca versión nueva
 DELETE /api/v1/accounts/:id/tracking_templates/:tid/publication   despublica
```
- Policy: si el usuario no tiene `can_publish_prompts` → 403, aunque llame a mano.
- Republicar = misma publicación, `version + 1` (las copias ya bajadas no cambian).

**✅ Hecho (05/10/2026)**

- Qué se hizo:
  - Ruta `resource :publication` anidada en `tracking_templates` (`config/routes.rb`).
  - `TrackingTemplates::PublicationsController`: primero revisa
    `Current.user.can_publish_prompts?` (403 si no, aunque sea administrador); luego busca
    el agente **solo en la cuenta actual** (otro → 404).
  - `PublishedPrompts::Publisher`: `publish!` toma la foto, pone autor y fecha, `version` 1
    la primera vez y +1 cada vez que se vuelve a publicar (también tras despublicar).
    Lo que no se manda (`nil`) conserva el título/descripción/categoría anterior; el título
    vacío cae al nombre del agente. `unpublish!` solo cambia el estado: la fila, el
    contador y las copias se conservan.
- Respuesta (las tres acciones):
  ```json
  { "publication": { "id", "title", "description", "category", "version", "status",
                     "downloads_count", "published_at", "requirements" } | null,
    "preview": { "requirements": [ … lo que se publicaría con el prompt de hoy … ] },
    "categories": ["ventas", "cobranza", "soporte", "agenda", "atencion", "otros"] }
  ```
- Pila de pruebas (ya corrida con el runner contra el agente #10368, cuenta 2, usuario #1,
  dentro de una transacción deshecha; quedaron 0 publicaciones y el permiso en `false`):

  | Paso | Esperado | Resultado |
  |---|---|---|
  | GET/POST sin permiso | 403 | ✅ |
  | GET con permiso, nunca publicado | `publication: null`, preview «Servicio Gruas» + calendario | ✅ |
  | POST título/descr./categoría | 201, v1, published | ✅ |
  | POST vacío | v2, conserva título y descripción | ✅ |
  | POST categoría inventada | 422 | ✅ |
  | DELETE | unpublished, v2 | ✅ |
  | POST otra vez | published, v3 | ✅ |
  | Agente que no es de la cuenta | 404 | ✅ |

  Spec escrito (`spec/controllers/api/v1/accounts/tracking_templates/publications_controller_spec.rb`),
  sin correr por la base de dev.

### F3 — Botón Publicar en la ficha del agente
- Solo visible si `currentUser.can_publish_prompts`.
- Modal nativo de Chatwoot: título, descripción corta, categoría, vista de lo que **no**
  viaja y lista de requisitos detectados. Estado: "Publicado v2 · 14 descargas".
- Botón "Despublicar".

**✅ Hecho (05/10/2026)**

- Dónde quedó el botón: en las **acciones de cada fila de la lista de Agentes IA**
  (ícono de compartir, junto a Asistente / Editar / Borrar), no dentro de la ficha. Así
  se publica sin abrir el agente y no se toca `EditTemplate.vue` (167 avisos de lint
  previos). Junto al nombre aparece la etiqueta **«Publicado v2»**. Las dos cosas solo
  las ve el usuario con `can_publish_prompts`.
- Qué se hizo:
  - `PublishPromptModal.vue` (nuevo): con `woot-modal`, `woot-modal-header`,
    `woot-label`, `woot-button` y `woot-loading-state` (componentes nativos). Al abrir
    pide `GET …/publication`, rellena título (o el nombre del agente), descripción y
    categoría de la versión anterior, y muestra:
    - el estado: «Publicado · v2 · 14 descargas» / «Despublicado · …»;
    - qué **no** se publica;
    - qué tendrá que configurar quien lo baje (`preview.requirements`, ya traducido:
      «Hoja de Google: Servicio Gruas», «Calendario para agendar», …).
    - Botones: Publicar / Publicar versión nueva, Despublicar (si está publicado), Cancelar.
  - `Index.vue`: botón, etiqueta y el modal; al publicar/despublicar recarga la lista.
  - `api/trackingTemplates.js`: `getPublication`, `publish`, `unpublish`.
  - Backend: `TrackingTemplate has_one :publication`; el JSON de la lista trae
    `publication: { status, version }` (o `null`), con `includes` para no hacer N+1.
  - i18n `TRACKING_TEMPLATES.PUBLISH.*` en es (México, con tú) y en.
- Pila de pruebas:
  - Ya probado: webpack «Compiled successfully» y el bundle servido trae las claves
    nuevas; la lista de la cuenta 2 trae `publication: null` en los 15 agentes, y con
    una publicación (en transacción deshecha) `{"status":"published","version":1}`.
  - **Falta en el navegador** (develop.wintook.com):
    1. Sin la casilla del super admin: la lista se ve igual que antes (sin botón ni etiqueta).
    2. Marcar la casilla al usuario → recargar → aparece el ícono de compartir en cada fila.
    3. Abrir en Grúas #10368 → requisitos «Hoja de Google: Servicio Gruas» y «Calendario
       para agendar» → Publicar → alerta «Prompt publicado» y etiqueta «Publicado v1».
    4. Abrir otra vez → «Publicar versión nueva» → «Publicado v2».
    5. Despublicar → desaparece la etiqueta.

```
 ┌─ Publicar prompt ───────────────────────────────┐
 │ Título       [ Ventas de grúas              ]   │
 │ Descripción  [ Cotiza y agenda visitas...   ]   │
 │ Categoría    [ Ventas            ▾ ]            │
 │                                                 │
 │ No se publica: bandeja, calendarios, archivos,  │
 │ plantillas de WhatsApp, etiquetas.              │
 │ Quien lo baje tendrá que configurar:            │
 │  • {{catalogo_pdf}}  (archivo)                  │
 │  • {{hoja:precios}}  (Google Sheets)            │
 │                                                 │
 │                     [Cancelar]  [Publicar]      │
 └─────────────────────────────────────────────────┘
```

### F4 — Galería dentro del Asistente de Agentes IA (todas las cuentas)

> Cambio del 05/10/2026: la Galería **no** va junto a Importar en la lista de Agentes IA;
> va dentro del Asistente. Al llegar a esta fase se revisa cómo entra hoy el Asistente
> (armar desde cero, importar .md) para que "partir de un prompt publicado" sea una
> entrada más del mismo lugar.

```
 GET  /api/v1/accounts/:id/contact_trackings/assistant/published_prompts        lista (q, category)
 GET  /api/v1/accounts/:id/contact_trackings/assistant/published_prompts/:pid   detalle (prompt completo)
```
- En el Asistente, opción **"Partir de un prompt publicado"**: tarjetas con título,
  descripción, autor (nombre de la cuenta, decisión D2), versión, descargas.
- Vista de detalle: el prompt completo en solo lectura antes de bajarlo.

**✅ Hecho (05/10/2026)**

```
 Asistente de Agentes IA — barra de arriba
 [ Crear desde instrucciones (.md) ] [ 🌐 Prompts publicados ] [ + Nuevo Agente IA ]
                                              │
                                              ▼
 ┌─ Prompts publicados ───────────────────────────────────────┐
 │ [ Buscar por título o descripción ] [ Todas las categorías ▾]│
 │ ┌──────────────────────────────────────────────────────────┐ │
 │ │ Agente de grúas  (Ventas)                                │ │
 │ │ Cotiza remolques y agenda el servicio                    │ │
 │ │ Grúas SSUSA · v2 · 14 descargas                          │ │
 │ └──────────────────────────────────────────────────────────┘ │
 │   clic ──► detalle: requisitos · objetivo · contexto ·       │
 │            Entrenamiento completo (solo lectura) · Volver     │
 └──────────────────────────────────────────────────────────────┘
```

- Qué se hizo:
  - Las rutas cuelgan de `contact_trackings/assistant/` (no de la cuenta suelta): la
    Galería es parte del Asistente, y piden lo mismo que él, **administrador** (D4).
    Un agente (rol) recibe 401, como en el resto del Asistente.
  - `ContactTrackings::AssistantPublishedPromptsController`: `index` (solo publicadas,
    de todas las cuentas, sin el texto del prompt, tope 200, `own: true` en las de la
    cuenta actual) y `show` (con objetivo, contexto, prompt, palabras clave y ajustes;
    despublicada → 404). Autor = nombre de la cuenta, nunca el correo (D2).
  - `PublishedPromptsModal.vue` (nuevo, en `views/contactTrackings/assistant/`): lista con
    búsqueda (espera 300 ms al teclear) y categoría; detalle de solo lectura. Si la
    publicación se despublica entre la lista y el clic, vuelve a la lista actualizada.
  - `Assistant.vue`: botón **«Prompts publicados»** junto a «Crear desde instrucciones».
  - `api/assistant.js`: `getPublishedPrompts`, `getPublishedPrompt`.
  - i18n `TRACKING_ASSISTANT_VIEW.GALLERY.*` (es/en); categorías y requisitos reusan
    `TRACKING_TEMPLATES.PUBLISH.*` de la F3.
- **Arreglo de la F1 encontrado aquí:** ADAM #11833 no se podía publicar: su objetivo mide
  371 caracteres y `ApplicationRecord` le pone 255 a toda columna `string` que no declare
  su largo. `PublishedPrompt` ahora valida `objective` hasta 500, igual que
  `TrackingTemplate`. (El prompt más largo de la base mide 18,738; el tope de `text` es
  20,000, el mismo que ya tienen los agentes.)
- Pila de pruebas (runner, transacción deshecha; cuenta 2 publica Grúas #10368 y ADAM
  #11833, la cuenta 3 consulta):

  | Paso | Esperado | Resultado |
  |---|---|---|
  | Lista desde la cuenta 3 | 2 publicaciones, autor = nombre de la cuenta, `own: false`, sin `prompt` | ✅ |
  | `q=grúas` | solo «Agente de grúas» | ✅ |
  | `category=atencion` | solo ADAM | ✅ |
  | Detalle de Grúas | prompt de 3,276 caracteres + requisitos | ✅ |
  | Lista desde la cuenta 2 | `own: true` | ✅ |
  | Despublicar ADAM → detalle | 404; la lista baja a 1 | ✅ |
  | Usuario con rol agente | 401 | ✅ |

  Spec escrito (`spec/controllers/api/v1/accounts/contact_trackings/assistant_published_prompts_controller_spec.rb`), sin correr.
  - **Falta en el navegador:** Asistente → «Prompts publicados» → buscar, filtrar, abrir
    uno, Volver. (Para que haya algo que ver, primero publica uno con la F3.)

### F5 — Bajar a mi cuenta
```
 POST /api/v1/accounts/:id/contact_trackings/assistant/published_prompts/:pid/install   → crea TrackingTemplate
```
- Crea el agente con lo que viaja, `published_prompt_id` apuntando al origen, nombre
  único en la cuenta, `downloads_count + 1`.
- Se llama solo desde el Asistente. Tras crear el agente, el Asistente abre la
  conversación sobre él: le cuenta qué se bajó, qué falta configurar (bandeja,
  requisitos detectados) y pregunta lo necesario para adecuar el prompt a la cuenta.
- Quién puede bajar: administradores de la cuenta (decisión D4).
- **Se baja de a uno** (pedido del usuario, 05/10/2026): se elige un prompt en la
  Galería, se abre su detalle y se baja ese. No hay "bajar todos" ni selección múltiple.

**✅ Hecho (05/10/2026)**

```
 Galería ─► clic en un prompt ─► detalle ─► [ ⬇ Bajar a mi cuenta ]
                                                   │ POST …/published_prompts/:id/install
                                                   ▼
                                  TrackingTemplate nuevo en la cuenta (copia)
                                  downloads_count + 1 en la publicación
                                                   │
                                                   ▼
                     Asistente: carga la copia (Estructura + Entrenamiento)
                     y el chat abre con:
                       «Bajé "Agente de grúas" a tu cuenta… Antes de usarlo, configura:
                        - La bandeja (canal) donde va a atender
                        - Hoja de Google: Servicio Gruas
                        - Calendario para agendar
                        Cuéntame de tu negocio… Con eso adecuo el Entrenamiento.»
```

- Qué se hizo:
  - `PublishedPrompts::Installer`: crea **un** agente en la cuenta con nombre, objetivo,
    contexto, Entrenamiento, palabras clave y ajustes de la publicación; `user` = quien lo
    baja; `published_prompt_id` = la publicación. Sin bandeja, calendarios, Base de
    Conocimiento, plantillas ni etiquetas. Nombre libre en la cuenta: «Título», si no
    «Título (2)», «(3)»… Todo en una transacción; la descarga se suma en SQL
    (`update_counters`) para que dos cuentas a la vez no se pisen.
  - `POST …/contact_trackings/assistant/published_prompts/:id/install` (administrador;
    despublicada → 404) → `{ tracking_template: { id, name }, requirements }`.
  - `PublishedPromptsModal.vue`: botón **«Bajar a mi cuenta»** solo en el detalle; emite
    `installed`.
  - `Assistant.vue` (`onPromptInstalled`): cierra la Galería, recarga los agentes, abre la
    copia con `loadTemplate` (guardar la reemplaza a **ella**, nunca al original), deja en
    el chat el mensaje de bienvenida y cambia la columna izquierda al chat.
  - i18n `GALLERY.INSTALL*` e `INTRO_*` (es/en).
- Pila de pruebas (runner, transacción deshecha; la cuenta 2 publica, la cuenta 3 baja):

  | Paso | Esperado | Resultado |
  |---|---|---|
  | Bajar «Agente de grúas» | 201, agente #nuevo en la cuenta 3, requisitos | ✅ |
  | La copia | usuario que bajó, `published_prompt_id`, sin bandeja/kbase/calendarios/etiquetas; zona horaria, reintentos y presentación de horarios copiados | ✅ |
  | Mismo prompt y objetivo; Estructura regenerada | sí | ✅ |
  | Agentes nuevos en la cuenta | exactamente 1 | ✅ |
  | Bajarlo otra vez | «Agente de grúas (2)» | ✅ |
  | Descargas | Grúas 2, ADAM 0 (no se bajó) | ✅ |
  | Agente original del autor | intacto en la cuenta 2 | ✅ |
  | Bajar uno despublicado | 404 | ✅ |
  | Usuario con rol agente | 401 | ✅ |

  Spec escrito (`spec/services/published_prompts/installer_spec.rb`), sin correr.
  - **Falta en el navegador:** con un prompt publicado (F3), desde OTRA cuenta: Asistente →
    «Prompts publicados» → abrir uno → «Bajar a mi cuenta» → alerta «… ya está en tus
    Agentes IA», el Asistente lo muestra cargado y el chat con el mensaje de bienvenida.
    Contestarle al chat → el Asistente adecua el Entrenamiento → Guardar (reemplaza la copia).

### F6 — Archivos adjuntos
- Copiar los `ai_agent_attachments` del agente publicado a la cuenta que baja, si D3 = sí.

**✅ Hecho (05/10/2026)** — D3 resuelta: **sí viajan, pero solo los que el autor marca.**

```
 Ventana Publicar                         published_prompt_files        Agente bajado
 ┌──────────────────────────────┐        (copia propia, al publicar)   (copia propia, al bajar)
 │ Archivos del agente que se    │
 │ publican                       │
 │ [x] catalogo_pdf  catalogo.pdf ├──────► catalogo_pdf ───────────────► Archivos: catalogo_pdf
 │ [ ] logo_interno  logo.png     │        (logo_interno no viaja)       → {{catalogo_pdf}} funciona
 └──────────────────────────────┘
```

- Qué se hizo:
  - Tabla `published_prompt_files` (`published_prompt_id`, `name`; borrado en cascada) y
    modelo `PublishedPromptFile` (`has_one_attached :file`, mismo formato de nombre que
    `AiAgentAttachment`). `PublishedPrompt has_many :files`.
  - `PublishedPrompts::FileCopier`: copia el archivo (lo descarga y lo sube como blob
    nuevo con `create_and_upload!`). No se comparte el blob: borrar en un lado nunca deja
    sin archivo al otro.
  - `Publisher#publish!(attachment_ids:)`: copia **solo** los elegidos y los quita de
    `requirements`. `attachment_ids` ausente (`nil`) = vuelve a copiar los mismos nombres
    de la versión anterior; `[]` = ninguno. Un id de otro agente se ignora (se busca solo
    entre los archivos de ESTE agente). Todo en una transacción con la publicación.
  - `Installer`: el agente bajado recibe sus propios `AiAgentAttachment` (cuenta destino,
    mismo nombre), así sus `{{nombre}}` funcionan sin configurar nada.
  - API: `GET …/publication` trae `attachments` (`referenced`: el prompt lo usa;
    `included`: va en la versión publicada) y `publication.files`; la Galería trae `files`.
  - Ventana Publicar: casillas con nombre, archivo y tamaño. Vienen marcados los que el
    prompt usa (primera vez) o los de la versión publicada (republicar), con el aviso
    «Cualquier cuenta que baje el prompt recibirá una copia…». La lista «tendrá que
    configurar» se actualiza al marcar/desmarcar.
  - Galería (detalle): «Incluye estos archivos del agente».
- Pila de pruebas (runner, transacción deshecha + borrado de los archivos subidos;
  agente Grúas #10368 con 2 archivos de prueba, la cuenta 3 baja):

  | Paso | Esperado | Resultado |
  |---|---|---|
  | Ver publicación | catalogo_pdf `referenced`, logo_interno no; requisito «Archivo: catalogo_pdf» | ✅ |
  | Publicar con catalogo_pdf | 1 archivo; ya no figura en requisitos | ✅ |
  | La copia publicada | blob distinto, mismo contenido | ✅ |
  | El autor cambia su archivo | lo publicado no cambia | ✅ |
  | Galería | trae `files: [catalogo_pdf]` | ✅ |
  | Bajar en la cuenta 3 | el agente nuevo tiene catalogo_pdf, de la cuenta 3, mismo contenido | ✅ |
  | Republicar sin `attachment_ids` | v2 con el archivo NUEVO del autor | ✅ |
  | Republicar con `[]` | sin archivos; vuelve el requisito | ✅ |
  | `attachment_ids` de otro agente | se ignora | ✅ |

  Spec escrito (`spec/services/published_prompts/publisher_files_spec.rb`), sin correr.
  - **Nota de prueba:** dentro de una transacción que se deshace, `attach(io:)` no sube el
    archivo (Rails lo sube al confirmar). Por eso `FileCopier` usa `create_and_upload!`.
  - **Falta en el navegador:** en un agente con archivos, Publicar → ver las casillas →
    publicar → en otra cuenta, Galería muestra los archivos → Bajar → pestaña «Archivos»
    del agente nuevo.

### F7 — Aviso de versión nueva
- En la ficha de un agente bajado: "El autor publicó la v3" + ver diferencias. Nunca se
  pisa solo.

**✅ Hecho (05/10/2026)** — D7 resuelta: sí, solo como aviso. Como los prompts se bajan
desde el Asistente, el aviso también vive ahí (no en la ficha).

```
 Agentes IA (lista)                         Asistente (agente bajado cargado)
 Agente de grúas  [v3 disponible] ──🪄──►   ┌────────────────────────────────────────────┐
                                            │ El autor publicó la versión 3 del prompt…  │
                                            │ (tienes la 1)               [ Ver cambios ] │
                                            └───────────────────────┬────────────────────┘
                                                                    ▼
                                    ┌─ Versión 3 disponible ──────────────────────────┐
                                    │ +12 / −3 líneas respecto de tu Entrenamiento     │
                                    │ − línea tuya                                     │
                                    │ + línea de la v3                                 │
                                    │ [ Ignorar esta versión ] [ Cargar en el Asistente ]│
                                    └──────────────────────────────────────────────────┘
       Cargar → el texto va al EDITOR sin guardar · Ignorar → no avisa hasta la v4
```

- Qué se hizo:
  - Migración `20261005190000_add_published_prompt_version_to_tracking_templates`: qué
    versión bajó (o ya revisó) cada copia. Las copias que ya existían se dan por al día
    (no se sabe qué versión bajaron).
  - `Installer` guarda la versión al bajar.
  - `TrackingTemplate#published_prompt_update` → `{ published_prompt_id, version,
    current_version }` si la publicación sigue publicada y es más nueva; si no, `nil`.
    Va en el JSON de la lista de agentes.
  - `POST …/assistant/published_prompts/:id/seen` (`template_id`): marca la versión como
    revisada. Solo una copia de la cuenta que salió de ESA publicación (otra → 404). No
    toca el Entrenamiento.
  - Lista de Agentes IA: etiqueta **«v3 disponible»** con la ayuda «Ábrelo en el
    Asistente para ver los cambios».
  - Asistente: aviso arriba de las columnas + `PublishedUpdateModal.vue` (nuevo), que
    compara el Entrenamiento del editor con el de la versión nueva (`diffHunks`, el mismo
    formato que Versiones/Optimizar). «Cargar en el Asistente» pone el texto en el editor
    **sin guardar** y avisa «revísala y guarda si te sirve». Solo el Entrenamiento: ni
    archivos ni definición.
- Pila de pruebas (runner, transacción deshecha; Grúas #10368 publicado, bajado en la
  cuenta 3):

  | Paso | Esperado | Resultado |
  |---|---|---|
  | Tu copia #12151 (bajada antes de la F7) | versión 1, sin aviso | ✅ |
  | Recién bajada | versión 1, sin aviso | ✅ |
  | El autor publica hasta v3 | aviso `{version: 3, current_version: 1}` | ✅ |
  | «Ignorar» (`seen`) | 200, sin aviso | ✅ |
  | El autor publica v4 | aviso `{4, 3}` | ✅ |
  | El autor despublica | sin aviso | ✅ |
  | `seen` con un agente que no salió de esa publicación | 404 | ✅ |

  Spec escrito (`spec/models/tracking_template_published_prompt_update_spec.rb`), sin correr.
  - **Falta en el navegador:** con una copia bajada, que el autor publique otra versión →
    etiqueta en la lista → abrir en el Asistente → aviso → Ver cambios → Cargar (editor
    cambia, nada guardado) / Ignorar (el aviso desaparece).

## Decisiones abiertas

| #  | Pregunta | Propuesta por defecto |
|----|----------|-----------------------|
| D1 | ¿Permiso en `custom_attributes` o columna propia `can_publish_prompts`? | `custom_attributes` (sin migrar `users`) |
| D2 | ¿Qué se muestra como autor en la Galería? | Nombre de la cuenta, no el correo |
| D3 | ¿Los archivos adjuntos viajan? | ✅ Resuelta en F6: sí, solo los que el autor marca |
| D4 | ¿Quién puede bajar prompts en la cuenta destino? | Solo administradores |
| D5 | ¿La Galería es para todas las cuentas o el super admin elige cuáles la ven? | Todas |
| D6 | ¿El super admin puede despublicar un prompt ajeno? | Sí, desde una lista en el super admin (F4 bis) |
| D7 | ¿Las copias se enteran de versiones nuevas (F7)? | ✅ Resuelta en F7: sí, solo como aviso, en el Asistente |
