# Plan — Adaptar un prompt a la cuenta: pestaña «Configurar»

> Rama: `feat/adaptar_prompts_publicados` (desde `develop` @ `ec0960ea`) · Estado: **plan para revisar, sin código** · 20/10/2026

---

## 1. Qué se pidió

En el Asistente de Agentes IA, una **pestaña nueva entre «Entrenamiento» y «Versiones»** con un
**formulario dinámico** que pida lo que le falta al prompt para funcionar en *esta* cuenta:

- las directivas que apuntan a cosas que la cuenta no tiene (docs, hojas, archivos, etiquetas…);
- el **valor de las variables** del prompt (nombre del negocio, horario, teléfono…).

Caso principal: **un prompt bajado de la Galería de publicados**. También sirve para un prompt
pegado o cargado.

**Decisión tomada — variables con la opción A:** una variable es la marca que ya existe,
`<PENDIENTE: Nombre del negocio>`. No se inventa sintaxis nueva.

---

## 2. Lo que hay hoy (revisado en el código)

| Pieza | Dónde | Qué hace | Qué le falta |
|---|---|---|---|
| Lista de requisitos | `PublishedPrompts::Requirements` | Saca del texto docs, hojas, fuentes, ERP, adjuntos, calendario, predefinidas | No cruza con la cuenta destino; no ve etiquetas, tipos de caso ni variables |
| Dónde se muestra | `Assistant.vue#installedIntro` | Al bajar, la lista sale **como texto en el chat** | No se puede resolver nada desde ahí |
| ¿Existe en la cuenta? | `KnowledgeBase::Directives` (líneas 140-150) | Ya sabe preguntar por tipo si la fuente existe | Nadie lo usa para la copia bajada |
| Comprobador | `Assistant::ValidatorService` | Fuente, tipo de caso, etiqueta, ERP, hoja_buscar, calendario | No revisa adjuntos `{{nombre}}` ni directivas fuera de una ruta |
| Marca de dato faltante | `Assistant::PendingMarkers` (B9) | `<PENDIENTE: x>` es **bloqueante**: el Asistente no guarda con marcas | Una marca por lugar: 5 apariciones = 5 marcas |
| Bajar | `PublishedPrompts::Installer` | `create!` de la copia + archivos | **No pasa por el comprobador**: la copia puede nacer con marcas |
| Versión nueva (F7) | `Assistant.vue#loadPublishedVersion` | Pone el texto nuevo del autor en el editor | **Pisa lo que se adaptó**: se vuelve a empezar |

### Dos hallazgos que condicionan el diseño

```
 ① EL AUTOR NO PUEDE TENER MARCAS EN SU AGENTE
    Su agente está vivo: guardar con <PENDIENTE:> se bloquea (B9). Entonces el
    texto publicado HOY nunca trae variables.
    ⇒ Las variables se marcan AL PUBLICAR, solo en la copia publicada (F4).
      El agente del autor no cambia.

 ② LA COPIA BAJADA PUEDE QUEDAR CON MARCAS Y FUNCIONANDO
    Installer usa create! (sin comprobador) y la ficha del agente no valida B9.
    Si alguien le asigna bandeja sin configurar, el agente le escribe al
    cliente "<PENDIENTE: horario>" tal cual (ya pasó el 15/09/2026).
    ⇒ Hace falta un candado mientras queden marcas (F5).
```

---

## 3. Cómo se ve

```
┌ Entrenamiento ┬ Configurar (5) ┬ Versiones ┬ Cambios ┐
│                                                      │
│  Datos de tu negocio                                 │
│  Nombre del negocio (3 lugares) [ Grúas del Norte ]  │  ← <PENDIENTE: …> agrupadas
│  Horario                        [ L-V 9 a 18     ]   │     por etiqueta
│                                                      │
│  Archivos y fuentes                                  │
│  {{doc:Precios}}   [ Crear «Precios» ] [ Elegir ▾ ]  │  ← crear AHÍ MISMO o usar
│  {{hoja_buscar:Grúas}}    ✔ ya existe                │    uno de ESTA cuenta
│  {{catalogo}}             [ Subir archivo ]          │  ← pestaña Archivos
│                                                      │
│  Etiquetas y tipos de caso                           │
│  #cotizacion              [ Crear ] [ Usar otra ▾ ]  │
│  @crear_ticket(Ventas)    [ Soporte ▾ ] Crear tipo ↗ │
│                                                      │
│  Fuera del Asistente                                 │
│  Calendario               ⚠ Conectar en Ajustes ↗    │  ← enlace en otra pestaña
│  Bandeja                  ⚠ Asignar en la ficha ↗    │    del navegador
│                                                      │
│  [ Ya lo creé, revisar otra vez ]                    │
│               [ Aplicar al Entrenamiento ]           │
└──────────────────────────────────────────────────────┘
```

### 3.1 Crear lo que falta, o el enlace para crearlo

El Asistente **ya crea algunas cosas sin salir de la pantalla**, en el editor de rutas
(`assistant/RouteFields.vue`). Se reutiliza eso mismo; lo demás lleva un enlace.

| Falta | En «Configurar» | Se reusa |
|---|---|---|
| `{{doc:X}}`, `{{hoja:X}}`, `@buscar_foro(X)`, `@soporte_contpaq(X)` | **[Crear «X»]** ahí mismo · o [Elegir otro ▾] | `AddSourceModal` con `initial: { source_type, name }` (desde `sourceFromDirective`) |
| `{{hoja_buscar: H \| …}}` | **[Crear hoja «H»]** ahí mismo | `AddSourceModal` con `{ source_type: 'google_sheet', name: H }` |
| Etiqueta `#x` | **[Crear]** ahí mismo · o [Usar otra ▾] | `CreateLabelButton` |
| Adjunto `{{nombre}}` | **[Subir archivo]** ahí mismo | `api/aiAgentAttachments.js` (el agente bajado ya está guardado) |
| `@discourse` | enlace ↗ Integraciones › Discourse | `integrationFromDirective` + `settings_applications_integration` |
| `{{consulta:conn/nombre}}` | enlace ↗ Base de Conocimiento › Conexiones ERP | ver D7 |
| `@crear_ticket(tipo=X)` | [Elegir tipo ▾] · enlace ↗ Tickets › Tipos (`gestorTickets_types`) | solo administrador; si no lo eres: «pídeselo a un administrador» |
| `@agendar_calendar` | enlace ↗ `google_calendar` y asignarlo en la ficha | — |
| `@buscar_predefinidas` | enlace ↗ `canned_list` | — |
| Bandeja | enlace ↗ ficha del agente | ver D7 |

**Reglas de los enlaces**

- Se abren **en otra pestaña del navegador** (`$router.resolve(...).href`, `target="_blank"`). Así
  no se pierde el Entrenamiento que estás configurando.
- **Al volver** a la pestaña del Asistente (evento `focus` de la ventana), y con cada
  `ASSISTANT_SOURCES_CHANGED` (el evento que ya refresca el Asistente al crear algo), se pide otra
  vez el inventario y lo creado pasa a ✔ sin recargar. Por si eso no alcanza, está el botón
  «Ya lo creé, revisar otra vez».
- Lo creado **con el mismo nombre** que pide el prompt queda resuelto sin tocar el texto. Si se
  elige otro, se reescribe al Aplicar.
- Hoy Base de Conocimiento y la ficha del agente **no aceptan parámetros en la URL**: el enlace
  lleva a la lista y desde ahí se usa «Agregar». Para que abran directo la pestaña o el modal
  correcto, ver D7.

---

## 4. El principio: el formulario escribe en el texto

```
  texto del Entrenamiento ──► F0 Inventario ──► lista de pendientes
          ▲                     (texto + cuenta)        │
          │                                             ▼
          │                                     pestaña Configurar
          │                                        (respuestas)
          │                                             │
          └──── F1 Aplicar (servidor reemplaza) ◄───────┘
                     │
                     ├─► versión nueva en «Versiones» y «Cambios» (fuente: Configurado)
                     ├─► respuestas guardadas en el agente (F6, para versiones nuevas)
                     └─► comprobador otra vez → el contador baja
```

- **El motor no cambia**: sigue leyendo `complementary_prompt`. Lo configurado queda escrito en él.
- **Reemplaza el servidor, no el navegador**: una sola regla para las directivas (las mismas
  expresiones que `Requirements` y el motor), probada con RSpec.
- **Nada se aplica solo**: aplicar es un botón; deshacer = «Versiones».

---

## 5. Fases (una por una, con OK entre cada una)

### F0 — Inventario: qué falta en ESTA cuenta

Servicio nuevo `ContactTrackings::Assistant::AdaptationInventory.new(text, account:, template:)`.
Junta lo que ya detecta `PublishedPrompts::Requirements`, le agrega lo que no ve y cruza todo con la cuenta.

| Tipo | Se detecta con | «Ya existe» si… | Cómo se resuelve |
|---|---|---|---|
| Variable `<PENDIENTE: X>` | `PendingMarkers::RE` (agrupadas por etiqueta X) | nunca: siempre pide valor | texto |
| `{{doc:X}}` / `{{hoja:X}}` | `KnowledgeBase::Directives` | `google_source?` | elegir otro doc/hoja de la cuenta |
| `@buscar_foro(X)` / `@soporte_contpaq(X)` | ídem | fuente activa con ese nombre | elegir fuente |
| `{{hoja_buscar: H \| …}}` | `SheetLookup::DIRECTIVE_RE` | hoja `H` conectada | elegir hoja (columnas: las revisa `SheetLookupChecks`) |
| `{{consulta:conn/nombre}}` | `ConsultaDirectiveRenderer` | `ExternalDbQuery` existe | elegir consulta · si no hay conexión: enlace |
| Adjunto `{{nombre}}` | `AgentAttachments::DIRECTIVE` | archivo en la pestaña Archivos del agente | subir archivo |
| Etiqueta `#x` de ruta y `[ETIQUETAS]` | `RouteMap` / `TagDictionary` | `account.labels` | crear · elegir otra |
| `@crear_ticket(tipo=X)` | igual que `check_ticket_types` | `CaseType` | elegir tipo · crear |
| `@agendar_calendar` | `Requirements::FLAGS` | el agente tiene calendario asignado | enlace a Ajustes/ficha |
| `@buscar_predefinidas` | ídem | hay respuestas predefinidas | enlace |
| `@discourse` / `@buscar_articulo` | ídem | `discourse_hook?` / `items?` | enlace |
| Bandeja | `template.inbox_id` | asignada | enlace a la ficha |

Cada pendiente sale como
`{ key, kind, name, status: ok|missing, fix: text|select|upload|create_inline|link, options: [...], link: { route_name, params, query }, admin_only, occurrences, line }`.
`key` es estable (`var:Nombre del negocio`, `doc:Precios`); es la llave que usan F1 y F6.
`link` es el nombre de la ruta, no la URL armada: el navegador la resuelve con `$router.resolve`
(ver 3.1).

- Las directivas se leen **en todo el texto**, no solo en las líneas `@ruta(...)`. Así se cubre el
  hueco del comprobador con `{{doc:X}}` escrito en la prosa.
- Sin IA, y con el mismo costo que el comprobador.
- **Pila de pruebas (RSpec)**: un prompt con cada tipo, contra una cuenta que tiene la mitad →
  `ok` / `missing` correctos; marcas repetidas → un solo pendiente con `occurrences: 3`.

### F1 — API: inventario y aplicar

```
POST /api/v1/accounts/:id/contact_trackings/assistant/adaptation
     { text, tracking_template_id? }            → { items: [...] }

POST /api/v1/accounts/:id/contact_trackings/assistant/adaptation/apply
     { text, answers: { "doc:Precios": "Lista 2026", "var:Horario": "L-V 9 a 18" } }
                                                → { text, items, validation }
```

- Es `POST` con `text` porque el borrador puede no estar guardado (igual que el comprobador).
- **Reemplazos exactos**: `{{doc:Precios}}` → `{{doc:Lista 2026}}`; todas las
  `<PENDIENTE: Horario>` → `L-V 9 a 18`. Un valor vacío deja la marca.
- **Crear** (etiqueta, tipo de caso) va por los endpoints que ya existen. `apply` solo reescribe el texto.
- Responde con el comprobador ya corrido.
- **Pila de pruebas**: request specs. Además, aplicar dos veces da el mismo texto, y un valor con
  `}}` o `>` no rompe la directiva.

### F2 — Pestaña «Configurar (n)»

- `draftTab = 'configure'`, entre `editor` y `versions` (`Assistant.vue` ~línea 1905).
- Va en un **componente aparte**, `assistant/ConfigureTab.vue`, armado con componentes nativos:
  `woot-button`, `woot-input`, el select nativo y la subida de la pestaña Archivos.
  Nada de `?.` ni `??` en el `<template>` (webpack 4).
- Agrupa los pendientes en cuatro bloques: Datos de tu negocio · Archivos y fuentes ·
  Etiquetas y tipos de caso · Fuera del Asistente.
- Lo que ya existe se muestra con ✔ y plegado.
- Crear ahí mismo reusa `AddSourceModal`, `CreateLabelButton` y `sourceDirective.js` (los mismos
  de `RouteFields.vue`). Los enlaces se abren en otra pestaña del navegador y, al volver, se revisa
  otra vez (3.1).
- «Aplicar al Entrenamiento» → `draft` nuevo → `autosaveDraft` → queda como versión, y en
  «Cambios» se registra con la fuente nueva `LOG_SOURCE_CONFIGURED: "Configurado"` → `validateDraft()`.
- El contador `(n)` se recalcula con cada cambio del texto. Usa el mismo debounce del comprobador.
- i18n en es y en, hablando de tú.
- **Pila de pruebas**: pegar un prompt con 2 marcas + 1 doc inexistente → (3) → llenar → (0) →
  el comprobador queda sin B9.

### F3 — Al bajar de la Galería, se abre «Configurar»

- `onPromptInstalled`: después de `loadTemplate`, si hay pendientes se usa `draftTab = 'configure'`.
- El mensaje del chat cambia: deja de traer la lista de pendientes y apunta a la pestaña
  («Te faltan 5 cosas; están en Configurar»).
- `PublishedPromptsModal` (la Galería) muestra antes de bajar **cuántas cosas tendrás que
  configurar**, con el inventario cruzado contra tu cuenta.

### F4 — Al publicar, el autor marca sus variables

Sin esta fase, los prompts publicados nunca traen variables (hallazgo ①).

```
 Ventana Publicar
 ┌──────────────────────────────────────────────────────┐
 │ Datos de tu negocio (quien lo baje los va a llenar)  │
 │                                                      │
 │  Texto en tu prompt        Se llamará                │
 │  [ Grúas del Norte    ]    [ Nombre del negocio ]  ✕ │  aparece 3 veces
 │  [ 81 1234 5678       ]    [ Teléfono           ]  ✕ │  aparece 1 vez
 │  + Agregar                                           │
 └──────────────────────────────────────────────────────┘
```

- `Snapshot` reemplaza cada texto por `<PENDIENTE: Se llamará>` **solo en la copia publicada**
  (`prompt` y `ai_context`). El agente del autor no cambia.
- Se guarda en `published_prompts.variables` (jsonb, migración nueva). Al republicar, la ventana
  sale prellenada.
- Si un texto no aparece en el prompt, se avisa y no se publica así.
- **Pila de pruebas**: publicar Grúas #10368 con 2 variables → la publicación tiene las marcas y
  el agente del autor no → bajar → «Configurar (2+…)».

### F5 — Candado: una copia con marcas no le escribe al cliente

Hay dos opciones (ver D2):

- **(a)** La ficha del agente y la asignación (bandeja, asignar en lote, automatización) no
  dejan activar un agente con marcas, y avisan «Te falta configurar: …».
- **(b)** El motor, como red de seguridad, no manda un mensaje que contenga `<PENDIENTE`.

Se recomiendan **las dos**: (a) explica qué falta y (b) cubre caminos que no se vieron.

### F6 — Versión nueva del autor: no se pierde lo configurado

- `tracking_templates.adaptation_answers` (jsonb) guarda lo último aplicado:
  `{ "var:Horario": "L-V 9 a 18", "doc:Precios": "Lista 2026" }`.
- `loadPublishedVersion` → el texto nuevo trae otra vez las marcas → «Configurar» sale
  **prellenada** con las respuestas de antes → un clic en Aplicar. Solo se piden a mano las
  variables nuevas de esa versión.
- **Pila de pruebas**: bajar v1 → configurar → el autor publica v2 con una variable más →
  cargar v2 → solo esa queda vacía.

### F7 — El chat conoce la pestaña (opcional)

- «Analizar» / «Analiza mi prompt»: si hay pendientes de configuración, la respuesta lo dice
  y lleva a la pestaña, en lugar de explicarlos uno por uno.
- El Asistente puede **proponer variables** en un prompt pegado (por ejemplo «"Grúas del Norte"
  parece el nombre del negocio») → botón «Convertir en variable». Requiere IA: va al final.

---

## 6. Orden sugerido

```
 F0 ─► F1 ─► F2 ─► F3        ← ya sirve: directivas faltantes en prompts bajados o pegados
                    │
                    └─► F4 ─► F5   ← variables reales en lo publicado + candado (van juntas)
                               │
                               └─► F6 ─► F7
```

F4 y F5 se entregan juntas: en cuanto se publiquen prompts con marcas, el candado tiene que estar.

---

## 7. Decisiones abiertas

| # | Pregunta | Recomendación |
|---|---|---|
| D1 | ¿La pestaña se muestra siempre o solo con pendientes? | Solo con pendientes, o en un agente bajado aunque ya esté completo (para ver ✔) |
| D2 | Candado F5: ¿(a), (b) o las dos? | Las dos |
| D3 | ¿Se crean desde el formulario etiquetas y tipos de caso? | Sí (son un nombre). Docs, hojas, ERP y calendario no: enlace |
| D4 | Variables al publicar: ¿las marca el autor a mano o las propone la IA? | A mano en F4; la propuesta con IA en F7 |
| D5 | ¿El nombre de la pestaña es «Configurar»? | «Configurar». Otras: «Adaptar», «Por configurar» |
| D6 | ¿Las variables de un prompt pegado (no publicado) también se recuerdan (F6)? | Sí: `adaptation_answers` vive en el agente, venga de donde venga |
| D7 ✅ aprobada 20/10 | ¿Se agregan parámetros en la URL para que el enlace abra directo? `knowledgeSources/Index.vue` leería `?tab=erp` y `?nuevo=google_doc&nombre=X`; `trackingTemplates/Index.vue` leería `?edit=<id>` y llamaría a `goToEditForm` | Sí, es un cambio chico. Sin él, el enlace igual lleva a la pantalla correcta, pero cuesta un clic más |

---

## 8. Registro por fase

Al cerrar cada fase se agrega aquí qué se hizo, cómo funciona, la pila de pruebas y cómo
pedírselo al Asistente.

### F0 — Inventario ✅ (20/10/2026)

**Qué se hizo**

- `app/services/contact_trackings/assistant/adaptation_inventory.rb` (nuevo): recibe el texto del
  Entrenamiento, la cuenta y, si existe, el agente guardado. Devuelve la lista de lo que pide el
  prompt y si la cuenta lo tiene.
- `ExternalDb::ConsultaDirectiveRenderer#connection_for` (nuevo, una línea): devuelve la conexión
  del ERP de una `{{consulta:}}`, para ofrecer las otras consultas de esa conexión.
- No cambian el motor, el comprobador ni la pantalla. Todavía nadie lo llama: lo usará la F1.

**Cómo funciona**

Con este Entrenamiento, en una cuenta que tiene el doc «Precios» y la etiqueta `cotizacion`:

```
Eres el asistente de <PENDIENTE: Nombre del negocio>.
@ruta(ventas #cotizacion: quiere precio): {{doc:Precios}} -> @crear_ticket(tipo=Ventas)
Manda {{catalogo}} si lo pide. Agenda con @agendar_calendar.
Despídete como <PENDIENTE: Nombre del negocio>.
```

sale:

| Bloque | Pendiente | Estado | Cómo se resuelve |
|---|---|---|---|
| Datos de tu negocio | Nombre del negocio (2 lugares) | falta | escribir el valor |
| Archivos y fuentes | `{{doc:Precios}}` | ✔ | — |
| Archivos y fuentes | `{{catalogo}}` | falta | subir archivo |
| Etiquetas y tipos | `#cotizacion` | ✔ | — |
| Etiquetas y tipos | `@crear_ticket(tipo=Ventas)` | falta | elegir tipo · enlace a Tickets › Tipos (administrador) |
| Fuera del Asistente | calendario | falta | enlace a Google Calendar |
| Fuera del Asistente | bandeja | falta | enlace a la ficha del agente |

Detalles:
- Un `{{doc:}}` o `{{hoja:}}` que existe pero con Google desactivado en la cuenta sale
  «falta», con el motivo `google_disabled`, porque el motor tampoco lo usaría.
- Un tipo de caso escrito como `<PENDIENTE:>` no se pide dos veces: sale solo como variable.

**Pila de pruebas**

- `spec/services/contact_trackings/assistant/adaptation_inventory_spec.rb`: **16 ejemplos, 0 fallas**.
  Cubren variables agrupadas, doc, hoja, foro, hoja_buscar, Google desactivado, ERP sin conexión
  y con conexión, adjuntos, etiquetas de ruta y de `[ETIQUETAS]`, tipo de caso, calendario,
  predefinidas, discourse, bandeja y el orden por bloque.
- `consulta_directive_renderer_spec.rb`: 5 ejemplos, 0 fallas (no se rompió nada).
- rubocop sin hallazgos en los 3 archivos.
- Sobre un agente real (solo lectura): copia bajada **#12151** «PRUEBA Variables — Universidad
  Demo (2)», cuenta 2 → pide la etiqueta `#inscripcion_enviada` (línea 44), ofrece crearla o
  elegir otra de la cuenta, y avisa que no tiene bandeja.

**Cómo pedírselo al Asistente**

Todavía no se puede: no hay pantalla. Se verá en la pestaña «Configurar» a partir de la F2.

### F1 — API: inventario y aplicar ✅ (20/10/2026)

**Qué se hizo**

- `app/services/contact_trackings/assistant/adaptation_applier.rb` (nuevo): recibe el texto y las
  respuestas `{ llave => valor }` y devuelve el texto reescrito, más qué se aplicó y qué no (con el
  motivo).
- `app/controllers/api/v1/accounts/contact_trackings/assistant_adaptation_controller.rb` (nuevo) y
  dos rutas en `config/routes.rb`:
  - `POST …/contact_trackings/assistant/adaptation` `{ text, tracking_template_id? }` → `{ items }`
  - `POST …/contact_trackings/assistant/adaptation/apply` `{ text, answers, tracking_template_id? }`
    → `{ text, applied, rejected, items, validation }`
- `api/assistant.js`: `getAdaptation(text, templateId)` y `applyAdaptation(text, answers, templateId)`,
  para la F2.
- Los endpoints **no guardan nada**. El navegador pone el texto en el editor y se guarda como
  cualquier cambio, quedando en Versiones y Cambios. Permiso: administrador, igual que el resto del Asistente.

**Cómo funciona**

| Llave | Antes | Respuesta | Después |
|---|---|---|---|
| `var:horario` | `<PENDIENTE: Horario>` (todas) | `L-V 9 a 18` | `L-V 9 a 18` |
| `google_doc:precios` | `{{doc:Precios}}` | `Lista 2026` | `{{doc:Lista 2026}}` |
| `sheet_lookup:gruas` | `{{hoja_buscar: Gruas \| marca=? \| precio}}` | `Grúas 2026` | `{{hoja_buscar: Grúas 2026 \| marca=? \| precio}}` |
| `erp_query:sae/saldo` | `{{consulta:sae/saldo(rfc=?)}}` | `saldo_cliente` | `{{consulta:sae/saldo_cliente(rfc=?)}}` |
| `label:cotizacion` | `@ruta(ventas #cotizacion: …)` y `#cotizacion` | `#Cotizar` | `#cotizar` en los dos lugares (no toca `#cotizacion_vieja`) |
| `case_type:ventas` | `@crear_ticket(tipo=Ventas, prioridad=alta)` | `Comercial` | `@crear_ticket(tipo=Comercial, prioridad=alta)` |

Casos especiales:

- **No se aplica**, y vuelve en `rejected`:
  - `invalid`: un valor que cerraría la directiva (`}}` en un doc, `(` en un foro) o una
    etiqueta con espacios;
  - `pending`: un valor que es otra `<PENDIENTE:>`;
  - `too_long`: más de 500 caracteres;
  - `not_found`: la llave ya no está en el texto, por ejemplo al aplicar dos veces;
  - `not_applicable`: calendario, bandeja o predefinidas, que se configuran en otra pantalla.
- **Un valor vacío** deja la marca como estaba.
- **Aplicar dos veces da el mismo texto.**

**Pila de pruebas**

- `adaptation_applier_spec.rb`: **12 ejemplos**. Cubren cada clase de llave, idempotencia, valores
  que rompen la directiva, `\1` escrito tal cual, vacío y `not_applicable`.
- `assistant_adaptation_controller_spec.rb`: **5 ejemplos**. Cubren el permiso, el inventario con y
  sin agente, que no se cruce con un agente de otra cuenta, aplicar con comprobador, que no guarda,
  y que ignora respuestas que no son texto.
- Con F0: **33 ejemplos, 0 fallas**. rubocop y eslint sin hallazgos.
- Sobre la copia real **#12151** (cuenta 2, sin guardar): faltaban `#inscripcion_enviada` y la
  bandeja → se aplicó `label:inscripcion_enviada = demo` → solo queda la bandeja. La línea 44
  quedó `#demo — la respuesta en la que entregaste la liga.` y el agente guardado no cambió.

**Cómo pedírselo al Asistente**

Todavía no se puede: no hay pantalla. Llega con la F2 (pestaña «Configurar»).

### F2 — Pestaña «Configurar» + D7 ✅ código (20/10/2026) · ⏳ falta probar en el navegador

**Qué se hizo**

- `views/contactTrackings/assistant/ConfigureTab.vue` (nuevo): la pestaña. Agrupa lo que falta
  en «Datos de tu negocio», «Archivos y fuentes», «Etiquetas y tipos de caso» y «Fuera del
  Asistente». Lo que ya existe queda plegado en «Ya lo tienes (n)».
- `Assistant.vue`:
  - la pestaña entre Entrenamiento y Versiones, con el contador ámbar de lo que falta;
  - el inventario se pide cada vez que corre el comprobador y al volver a esta pestaña del
    navegador si faltaba algo;
  - lo aplicado entra al editor y se guarda como versión **«Configurado»**.
- D1 (aplicada así): la pestaña se ve si falta algo, si el agente fue bajado de la Galería
  (aunque ya esté completo) y mientras se está en ella.
- Crear ahí mismo reusa lo del editor de rutas: `AddSourceModal` (con el tipo y el nombre
  puestos), `CreateLabelButton` y la subida de `api/aiAgentAttachments.js`. El archivo se sube
  con el nombre exacto que pide `{{nombre}}`.
- Versión «Configurado»: `TrackingAssistantSession::VERSION_SOURCES` suma `configured`.
  `autosave!` y `PUT …/assistant/autosave` aceptan `source: 'configured'` y `notes`. Esa versión
  no la pisa el siguiente autoguardado, y en «Cambios» se ve como «Configurado» con lo aplicado
  (`var:horario → L-V 9 a 18`).
- **D7**:
  - `settings/knowledgeSources/Index.vue` lee `?tab=erp|sources` y
    `?nuevo=<tipo>&nombre=X`, que abre el alta con el tipo y el nombre puestos;
  - `settings/trackingTemplates/Index.vue` lee `?edit=<id>` y abre la ficha de ese agente.
- i18n en es y en (`TRACKING_ASSISTANT_VIEW.CONFIGURE.*`, `DRAFT_TAB_CONFIGURE`,
  `LOG_SOURCE_CONFIGURED`).

**Cómo funciona**

```
 Pegas o bajas un prompt ─► el comprobador corre ─► también el inventario
                                                        │
       ┌ Entrenamiento ┬ Configurar (3) ┬ Versiones ┬ Cambios ┐
       │  Datos de tu negocio                                 │
       │   Dato · Horario            [ L-V 9 a 18        ]    │
       │  Archivos y fuentes                                  │
       │   Google Doc · {{doc:Precios}} [Crear «Precios»] [o usa uno ▾] │
       │  Fuera del Asistente                                 │
       │   Calendario para agendar · @agendar_calendar  Configurar ↗ │
       │  [Ya lo creé, revisar otra vez]   [Aplicar al Entrenamiento] │
       └──────────────────────────────────────────────────────┘
```

- **Crear «Precios»** abre el alta de Base de Conocimiento ya llena. Al guardar, la fila pasa a
  «Ya lo tienes».
- **Configurar ↗** abre otra pestaña del navegador. Al volver, se revisa sola.
- **Aplicar** reescribe el texto en el servidor (F1). Queda en el editor y en Versiones y Cambios
  como «Configurado». Lo que no se pudo aplicar sale en un aviso con el motivo.

**Pila de pruebas**

- RSpec: **72 ejemplos, 0 fallas**. Son los 33 de F0 y F1, `tracking_assistant_session_spec` y
  `assistant_autosave_spec`, este con 2 nuevos: «Configurado» queda como su propia versión con
  notas y no lo pisa el autoguardado; un `source` desconocido cuenta como edición a mano.
- eslint: `ConfigureTab.vue`, `Assistant.vue`, `api/assistant.js` y `trackingTemplates/Index.vue`
  sin hallazgos. `knowledgeSources/Index.vue` queda con sus mismos 63 hallazgos previos (no se le
  sumó ninguno; no se corrió `--fix`). rubocop sin hallazgos.
- webpack: «Compiled successfully» después del último cambio.
- **Falta en el navegador** (develop.wintook.com):
  1. abrir la copia **#12151** en el Asistente → «Configurar (2)»: `#inscripcion_enviada` y la bandeja;
  2. elegir una etiqueta en «o usa uno» → Aplicar → (1), y en Cambios aparece «Configurado»;
  3. Bandeja «Configurar ↗» → abre la ficha de #12151 en otra pestaña; al volver se revisa;
  4. pegar un prompt con `<PENDIENTE: Horario>` y `{{doc:NoExiste}}` → crear el doc ahí mismo.

**Cómo pedírselo al Asistente**

No se le pide al chat: es una pestaña. Abre el agente (o pega el prompt) y entra en
«Configurar», junto a «Entrenamiento».

### F3 — Bajar de la Galería abre «Configurar» ✅ código (20/10/2026) · ⏳ falta probar en el navegador

**Qué se hizo**

- `Assistant.vue#onPromptInstalled`: después de cargar la copia bajada, se abre la pestaña
  **«Configurar»** (no el editor).
- La presentación del chat ya no lista los requisitos. Ahora dice que lo que falta está en
  «Configurar» y que ahí se crea, se elige o se escribe (`GALLERY.INTRO_CONFIGURE`, que
  reemplaza a `INTRO_SETUP` e `INTRO_INBOX`). Sigue preguntando por el negocio (`INTRO_ASK`).
- `PublishedPromptsModal.vue` (la Galería): al abrir el detalle de un prompt, su Entrenamiento se
  cruza con **tu** cuenta (`POST …/assistant/adaptation`, la F1) y se muestra:
  - «Al bajarlo tendrás que configurar en tu cuenta (n):» con solo lo que falta, más la bandeja,
    que siempre hay que elegir;
  - «Ya tienes: …» con lo que ya existe;
  - que todo se resuelve en «Configurar» al bajarlo.
  - Los archivos que vienen con la publicación no se cuentan como faltantes.
  - Si el cruce falla, se muestra la lista del autor de siempre.

**Cómo funciona**

```
 Galería ─► detalle del prompt ─► «Al bajarlo tendrás que configurar (2):
                                    · Etiqueta: inscripcion_enviada
                                    · La bandeja (canal) donde va a atender»
        ─► Bajar a mi cuenta ─► Asistente con la copia, en la pestaña «Configurar (2)»
                                y en el chat: «lo que falta está en Configurar…»
```

**Pila de pruebas**

- Sobre datos reales (solo lectura): la publicación **#12** «PRUEBA Variables — Universidad Demo»,
  vista desde la cuenta 2 → configurar **2**: la etiqueta `inscripcion_enviada` y la bandeja.
  Coincide con lo que la pestaña muestra en su copia bajada #12151. Es la única publicación en
  `chatwoot_dev`, y es de la misma cuenta 2.
- eslint: `Assistant.vue` y `PublishedPromptsModal.vue` sin hallazgos (los dos estaban en 0).
  Los JSON de i18n son válidos. webpack: «Compiled successfully».
- **Falta en el navegador**: Galería → abrir «PRUEBA Variables — Universidad Demo» → ver
  «configurar (2)» → Bajar → que abra en «Configurar (2)» con el mensaje nuevo en el chat.

**Cómo pedírselo al Asistente**

No se le pide: pasa solo al bajar un prompt de «Prompts publicados».

### F4 — Al publicar, el autor marca sus variables ✅ código (20/10/2026) · ⏳ falta probar en el navegador

**Qué se hizo**

- Migración `20261022120000_add_variables_to_published_prompts`: `published_prompts.variables`
  (jsonb, `[]`). Ya está aplicada en `chatwoot_dev`. En `schema.rb` quedaron solo esta columna y
  la versión; se descartó lo que arrastraban otras ramas.
- `app/services/published_prompts/variables.rb` (nuevo):
  - limpia la lista, cuenta apariciones, valida y reemplaza;
  - reemplaza **solo en la prosa del Entrenamiento**: nunca dentro de `{{…}}`, `@x(…)`,
    líneas `@ruta` ni otra `<PENDIENTE:>`;
  - no distingue mayúsculas, y el texto más largo gana.
- `Publisher#publish!(variables:)`:
  - la copia publicada lleva `<PENDIENTE: nombre>` y el agente del autor no cambia;
  - `nil` reusa las de la versión anterior y `[]` las quita;
  - una variable que no aparece en el Entrenamiento impide publicar (422 con el motivo).
- No se reemplaza en Contexto ni en Objetivo. La pestaña «Configurar» solo edita el
  Entrenamiento: una marca en esos campos no se podría llenar y la copia quedaría bloqueada por la
  F5. La ventana avisa cuando el texto también está ahí, para que el autor lo deje genérico.
- `PublishPromptModal.vue`: nueva sección «Datos de tu negocio». Cada fila es «Texto en tu
  Entrenamiento» → «Se llamará» y muestra «Aparece N veces», o el aviso en ámbar si no aparece.
  Se prellena al republicar.
- i18n en es y en (`TRACKING_TEMPLATES.PUBLISH.VARIABLES.*`) y `config/locales/published_prompts.{es,en}.yml`.

**Cómo funciona**

```
 Agente del autor (no cambia)            Copia publicada
 «Eres el asistente de Grúas del Norte.   «Eres el asistente de <PENDIENTE: Nombre del negocio>.
  Usa {{doc:Grúas del Norte}}.»            Usa {{doc:Grúas del Norte}}.»   ← la directiva no se toca
          │                                         │
  Datos de tu negocio:                     quien lo baja → «Configurar»:
  Grúas del Norte → Nombre del negocio       Nombre del negocio [ Grúas del Sur ]
```

### F5 — Candado: una copia con marcas no le escribe al cliente ✅ (20/10/2026)

**Qué se hizo** (D2: las dos opciones)

- `app/services/contact_trackings/pending_setup.rb` (nuevo): dice si un seguimiento o un agente
  tiene `<PENDIENTE:>` en Entrenamiento, Contexto u Objetivo, y cuáles.
- **(a) La ficha**: `TrackingTemplate` no deja asignar bandeja mientras queden marcas. Solo se
  revisa cuando cambia la bandeja o el texto. La lista de Agentes IA ahora muestra el mensaje del
  servidor («tiene datos por configurar: Nombre del negocio…») en lugar del error genérico.
- **(b) El motor**, en sus tres entradas, sobre la copia del seguimiento:

  | Entrada | Qué pasa con marcas |
  |---|---|
  | `ContactTrackingJob` (primer mensaje) | no envía; seguimiento `failed` con `last_error` que dice qué falta |
  | `TrackingDispatch::SendJob` (campañas) | ídem (vía `fail_claimed`) |
  | `ContactTrackingResponseAnalyzerJob#process_message_for_tracking` (respuestas) | ese seguimiento no contesta (si hay @botseller, sigue él) |

  Hace falta la (b) aunque esté la (a): las campañas crean los seguimientos con `insert!`, sin
  validaciones, y se puede asignar un agente sin bandeja.

**Pila de pruebas (F4 + F5)**

- `variables_spec.rb` (7):
  - reemplaza sin distinguir mayúsculas;
  - no toca directivas, `@ruta` ni marcas;
  - el texto más largo gana y no se reemplaza dentro de una marca nueva;
  - cuenta solo en la prosa, limpia la lista, y avisa los problemas.
- `publisher_variables_spec.rb` (6):
  - la copia lleva las marcas y el autor no cambia; el Contexto no se toca;
  - republicar reusa las variables y `[]` las quita;
  - no publica con una variable inexistente;
  - **de punta a punta**: publicar → bajar en otra cuenta → «Configurar» pide `var:nombre del negocio` y `var:teléfono`.
- `pending_setup_spec.rb` (6):
  - marcas sin repetir y mensaje de qué falta;
  - la ficha no deja asignar bandeja con marcas y sí después;
  - no traba otras ediciones;
  - `ContactTrackingJob` no envía y deja el seguimiento fallido;
  - el analizador no contesta.
- `send_job_spec.rb` (+1): la campaña no llama a Meta y deja el seguimiento fallido con el motivo.
- Todo lo de publicar y adaptar: **116 de 117**. La que falla es
  `assistant_published_prompts_controller_spec` «hides unpublished ones», por el entorno: espera la
  Galería vacía y encuentra la publicación real #12 de `chatwoot_dev`, porque las pruebas usan la
  base de dev. No se tocó ese controlador.
- rubocop sin hallazgos en lo nuevo. `contact_tracking_job.rb` y
  `contact_tracking_response_analyzer_job.rb` siguen con sus hallazgos previos (106 y 28), sin
  sumar ninguno. Al hacer commit, el hook de pre-commit los va a marcar: ver
  [[project_edittemplate_lint_baseline]].
- eslint: `PublishPromptModal.vue` y `trackingTemplates/Index.vue` sin hallazgos. webpack: «Compiled successfully».
- **Falta en el navegador**:
  1. publicar un agente con «Grúas del Norte → Nombre del negocio» y ver «Aparece N veces»;
  2. bajarlo en otra cuenta y ver la variable en «Configurar»;
  3. intentar asignarle bandeja antes de llenarla y ver el mensaje.

**Cómo pedírselo al Asistente**

No se le pide: los datos se marcan en la ventana «Publicar prompt» de la ficha del agente.

### F6 — Versión nueva del autor: no se pierde lo configurado ✅ código (20/10/2026) · ⏳ falta probar en el navegador

**Qué se hizo**

- Migración `20261023120000_add_adaptation_answers_to_tracking_templates`:
  `tracking_templates.adaptation_answers` (jsonb, `{}`). Aplicada en `chatwoot_dev`. En
  `schema.rb` y en los modelos quedaron solo las líneas propias; se descartaron lo de otras ramas
  y las anotaciones que la herramienta reescribió.
- `POST …/adaptation/apply` con `tracking_template_id`: guarda en el agente lo que **sí** se
  aplicó (`{ "var:horario" => "L-V 9 a 18" }`). Lo rechazado no se guarda. Es lo único que ese
  endpoint escribe.
- `AdaptationInventory`: a lo que falta y ya se había configurado antes en ese agente le agrega
  `remembered` con el valor.
- `ConfigureTab.vue`: prellena esos campos y avisa «Algunos campos ya traen lo que configuraste
  antes en este agente».
- `Assistant.vue#loadPublishedVersion` (el «Ver cambios» de una versión nueva del autor) ahora
  abre «Configurar», no el editor.
- D6 (aplicada así): se recuerda en cualquier agente guardado, venga o no de la Galería.

**Cómo funciona**

```
 v1 bajada ─► Configurar: Nombre del negocio = Grúas del Sur ─► Aplicar
                                   └─► adaptation_answers {"var:nombre del negocio": "Grúas del Sur"}
 el autor publica v2 (con un dato nuevo: Horario) ─► Ver cambios ─► «Configurar (2)»
     Nombre del negocio [ Grúas del Sur ]   ← prellenado
     Horario            [               ]   ← lo único nuevo
```

### F7 — El chat conoce la pestaña, y la IA propone variables ✅ código (20/10/2026) · ⏳ falta probar en el navegador

**Qué se hizo**

- `AnalysisTurn#configure_line`: la respuesta a «Analiza mi prompt» agrega, debajo de lo que marca
  el comprobador, «**Falta configurar en tu cuenta** (n): … Resuélvelo en la pestaña
  «Configurar»». No repite la lista y no cuenta archivos, porque el turno no sabe qué agente es.
  Clave `tracking_assistant.analysis.configure` (es y en).
- `ContactTrackings::Assistant::VariableSuggestions` (nuevo):
  - el modelo de la cuenta (integración OpenAI, el mismo del Asistente) señala qué textos son
    datos de un negocio concreto: nombre, teléfonos, horario, dirección, personas, precios;
  - el servidor descarta lo que no aparece tal cual en la prosa (inventado o mal copiado) y lo
    muy corto;
  - limpia los nombres;
  - no escribe nada.
- Endpoints:
  - `POST …/adaptation/suggest_variables` `{ text }` → `{ variables: [{ text, label, count }] }`;
  - `POST …/adaptation/mark_variables` `{ text, variables }` → el texto con
    `<PENDIENTE: nombre>`, con el mismo reemplazo protegido que al publicar (F4). No guarda.
- `ConfigureTab.vue`: la sección «¿Trae datos de otro negocio?» tiene el botón «Buscar datos de
  negocio con IA» y la lista con casillas y nombres editables. «Convertir en variables (n)» hace
  que pasen a «Datos de tu negocio» para poner los tuyos. Queda como versión «Configurado».

**Cómo funciona**

```
 Pegas el prompt de otra empresa ─► Configurar ─► Buscar datos de negocio con IA
   ☑ Grúas del Norte (2 lugares)   [ Nombre del negocio ]
   ☑ 81 1234 5678    (1 lugar)     [ Teléfono           ]
   ☐ L-V 9 a 18      (1 lugar)     [ Horario            ]
   [ Convertir en variables (2) ] ─► «Datos de tu negocio»: Nombre del negocio [ ____ ] …
```

**Pila de pruebas (F6 + F7)**

- `assistant_adaptation_controller_spec.rb` (+5, 11 en total):
  - aplicar recuerda solo lo aplicado y el inventario lo devuelve como `remembered` en la versión nueva;
  - sin agente no recuerda nada;
  - `mark_variables` no toca la directiva y la variable aparece para llenar;
  - rechaza un texto que no está;
  - `suggest_variables` devuelve lo propuesto.
- `variable_suggestions_spec.rb` (4):
  - filtra lo inventado y lo corto;
  - limpia los nombres;
  - sin integración de OpenAI no llama;
  - si el modelo falla, lo dice.
- `analysis_turn_spec.rb` (+2): el análisis manda a «Configurar» con el conteo, y los archivos no cuentan.
- **Toda la carpeta del Asistente + adaptar + publicar + candado: 638 de 638.**
- rubocop y eslint sin hallazgos en lo nuevo. webpack: «Compiled successfully».
- **Sin llamada real al modelo**: las pruebas lo simulan. La primera vez que se use el botón en
  el navegador es la prueba real (una llamada por clic, con el modelo del Asistente).
- **Falta en el navegador**:
  1. pegar un prompt con datos de otra empresa → «Buscar datos de negocio con IA» → convertir
     dos → llenarlos → Aplicar;
  2. con la copia #12151: aplicar algo, simular una versión nueva y ver los campos prellenados;
  3. «Analiza mi prompt» con algo faltante → ver la línea que manda a «Configurar».

**Cómo pedírselo al Asistente**

- «Analiza mi prompt» ya avisa si falta configurar algo y manda a la pestaña.
- Los datos de otro negocio se buscan con el botón de la pestaña «Configurar», no por el chat.

### Ajustes tras la primera revisión ✅ código (20/10/2026)

**Qué se hizo**

- **Las etiquetas ya no se piden.** El `#cotizacion` de una ruta, o los de `[ETIQUETAS]`, no son
  etiquetas de Chatwoot que haya que crear: son marcas que van en el mensaje y que una
  automatización lee. Se quitaron del inventario (`scan_labels`), del aplicador (`label:`
  vuelve como `not_applicable`) y de la pestaña (botón «Crear» y «Usar otra»). El bloque
  quedó como «Tipos de caso» (`case_types`), con lo de `@crear_ticket(tipo=X)`.
- **«Nuevo agente IA» limpia «Configurar».** Antes se quedaba con lo del agente analizado
  antes; ahora se vacía al empezar uno nuevo y al abrir otra conversación de «En construcción».
- **Versiones y Cambios escondidas** por el momento (`SHOW_HISTORY_TABS = false` en
  `Assistant.vue`). El historial se sigue guardando.

- **El comprobador tampoco revisa que la etiqueta exista** (pedido el mismo día). Se quitó
  `label_not_found` (rutas) y la parte de `[ETIQUETAS]` de `TagDictionary.check`; en el editor
  de rutas, el aviso «Esta etiqueta no existe» y su botón «Crear». Se queda el aviso de
  `#pago_confirmado` de `@confirmar_servicio(requiere=pago)`: esa sí es una etiqueta de
  Chatwoot que una persona le pone a la conversación.

**Pila de pruebas:** inventario, aplicador, controlador, análisis, comprobador, TagDictionary y
auditoría ajustados; 979 ejemplos de contact_trackings, 1 falla ya conocida y ajena (Galería
«hides unpublished ones», por la publicación #12 real de chatwoot_dev).
