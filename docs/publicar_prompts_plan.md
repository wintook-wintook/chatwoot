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
 GET  /api/v1/accounts/:id/published_prompts            lista (búsqueda, categoría)
 GET  /api/v1/accounts/:id/published_prompts/:pid       detalle (prompt completo, solo lectura)
```
- En el Asistente, opción **"Partir de un prompt publicado"**: tarjetas con título,
  descripción, autor (nombre de la cuenta, decisión D2), versión, descargas.
- Vista de detalle: el prompt completo en solo lectura antes de bajarlo.

### F5 — Bajar a mi cuenta
```
 POST /api/v1/accounts/:id/published_prompts/:pid/install   → crea TrackingTemplate
```
- Crea el agente con lo que viaja, `published_prompt_id` apuntando al origen, nombre
  único en la cuenta, `downloads_count + 1`.
- Se llama solo desde el Asistente. Tras crear el agente, el Asistente abre la
  conversación sobre él: le cuenta qué se bajó, qué falta configurar (bandeja,
  requisitos detectados) y pregunta lo necesario para adecuar el prompt a la cuenta.
- Quién puede bajar: administradores de la cuenta (decisión D4).

### F6 — (opcional) Archivos adjuntos
- Copiar los `ai_agent_attachments` del agente publicado a la cuenta que baja, si D3 = sí.

### F7 — (opcional) Aviso de versión nueva
- En la ficha de un agente bajado: "El autor publicó la v3" + ver diferencias. Nunca se
  pisa solo.

## Decisiones abiertas

| #  | Pregunta | Propuesta por defecto |
|----|----------|-----------------------|
| D1 | ¿Permiso en `custom_attributes` o columna propia `can_publish_prompts`? | `custom_attributes` (sin migrar `users`) |
| D2 | ¿Qué se muestra como autor en la Galería? | Nombre de la cuenta, no el correo |
| D3 | ¿Los archivos adjuntos viajan? | No en la primera versión (F6 después) |
| D4 | ¿Quién puede bajar prompts en la cuenta destino? | Solo administradores |
| D5 | ¿La Galería es para todas las cuentas o el super admin elige cuáles la ven? | Todas |
| D6 | ¿El super admin puede despublicar un prompt ajeno? | Sí, desde una lista en el super admin (F4 bis) |
| D7 | ¿Las copias se enteran de versiones nuevas (F7)? | Sí, solo como aviso |
