# Integración Google Docs / Sheets en la Base de Conocimiento

> **Estado:** plan de diseño (rama `feat/kbase_google_docs`). No implementado.
> Documento de plan — solo diseño, sin código todavía.

Permitir que **Google Docs** (texto) y **Google Sheets** (tablas) sean fuentes de
conocimiento consultables por el bot, igual que `canned_response` / `article`.

El reto central: el contenido vive **fuera de Chatwoot**, así que **nadie dispara un
`after_commit`**. Hay que detectar los cambios nosotros. Ver [[Flujo-de-vectorizacion]]
(el patrón interno) y [[Sync-Discourse]] (el patrón "en vivo").

---

## 1. Decisiones de diseño (cerradas)

| Tema | Decisión |
|------|----------|
| Actualización de contenido | **Solo manual: botón "Sincronizar ahora"** (POST `.../sources/:id/sync`), como ya hacen canned/articles. Los docs cambian poco → no se justifica automatizar. Polling por `modifiedTime` y push quedan **diferidos** (ver §8). |
| Sheets | Soporte de **ambos modos** (FAQ semántico **y** datos exactos), configurable por fuente. |
| OAuth | Reutilizar el OAuth de Google ya montado para Calendar; sumar scope `drive.readonly`. |
| Embeddings | Mismo pipeline: OpenAI `text-embedding-3-small` (1536) → `knowledge_items` / pgvector. |
| Multi-tenant | Token y OpenAI key **por cuenta** (sin fallback global), como ya hace el job actual. |

### Por qué solo manual (y no cron/push por ahora)

Los documentos/hojas de este caso **se modifican con poca frecuencia**, así que automatizar
la detección de cambios no se justifica todavía. El usuario aprieta "Sincronizar ahora"
cuando editó el archivo. Esto evita: complejidad del cron, llamadas innecesarias a Drive API,
y endpoints públicos.

Si en el futuro hace falta automatizar, hay dos escalones (ambos **diferidos**):

```
DIFERIDO-1: POLLING (modifiedTime)      DIFERIDO-2: PUSH (Drive changes.watch)
  cron lee timestamps → re-sync solo      Google empuja al cambiar → casi tiempo real
  los que cambiaron                        - endpoint HTTPS público
  + sin endpoint público                   - canales que EXPIRAN (cron igual)
  + barato                                 - firma + reintentos
  → primer escalón si se necesita          → solo si se necesita tiempo real puro
```

---

## 2. Flujo general

```
Botón "Sincronizar ahora"  (POST .../sources/:id/sync)   ← único disparador (v1)
        │
        ▼
┌─ GoogleDocSyncJob(action, source_id) ─────────────────────────────────┐
│  1. Refresh token OAuth (Google::RefreshOauthTokenService)            │
│  2. Descarga contenido:                                               │
│       google_doc   → Docs API documents.get  (o export text/plain)    │
│       google_sheet → Sheets API values.get (rango completo)           │
│  3. Chunking (ver §4) → N chunks                                      │
│  4. Embedding por chunk → upsert en knowledge_items                  │
│  5. BORRAR chunks huérfanos (chunk_index >= N)   ←★ clave al actualizar│
│  6. Guardar modified_time + content_hash en metadata                 │
└───────────────────────────────────────────────────────────────────────┘
```

> El `modified_time`/`content_hash` se guardan igual (paso 6) aunque no haya cron: sirven
> para mostrar "última sincronización" en la UI y habilitan el polling diferido sin migrar
> datos después. El cron, si algún día se agrega, solo encolaría este mismo job.

---

## 3. Modelo de datos

### `knowledge_sources`
- `source_type`: ampliar la validación a
  `%w[canned_response discourse article google_doc google_sheet]`.
- `config` (jsonb) guarda:
  ```jsonc
  {
    "file_id": "1AbC...",            // ID del archivo en Drive
    "file_url": "https://docs...",   // para mostrar en UI
    "hook_id": 42,                   // integración Google de la cuenta (token)
    "sheet_mode": "faq" | "data",    // SOLO sheets
    "data_key_column": "SKU"         // SOLO sheets en modo data (columna de lookup)
  }
  ```
- `last_synced_at`, `sync_status`, `sync_jobs_pending`: **ya existen** → se reutilizan.

> Nota: el índice único parcial actual aplica solo a `canned_response`/`article`.
> Las fuentes Google se crean explícitamente desde la UI (como Discourse), pueden ser
> múltiples por cuenta → **no** entran en ese índice único. OK.

### `knowledge_items`
- Sin cambios de schema. Se usan los campos existentes:
  - `source_id` = id del `knowledge_source` (no hay tabla propia del doc).
  - `chunk_index` ≥ 0 (los Google docs sí usan multi-chunk, a diferencia de canned).
  - `metadata`: `{ modified_time, content_hash, chunk_total, row_index?, sheet_tab? }`.

---

## 4. Chunking

### Google Doc (texto)
Partir por longitud con solapamiento, respetando párrafos/encabezados:
```
texto plano → bloques de ~800-1000 tokens, overlap ~100
cada bloque = 1 knowledge_item (chunk_index 0..N-1)
title = título del doc + (encabezado de sección si aplica)
```

### Google Sheet — **modo FAQ** (`sheet_mode: "faq"`)
```
fila 1 = encabezados
cada fila de datos → 1 chunk:  "Pregunta: <colA>\nRespuesta: <colB>..."
→ recuperación semántica fila a fila (ideal para FAQ).
```

### Google Sheet — **modo Datos** (`sheet_mode: "data"`)  ← el caso "mezcla"

Las preguntas reales sobre una tabla son **analíticas**, no semánticas:
- "dame la suma de precios" → **agregación**
- "cuántos son mayores a 1000" → **filtro + conteo**
- "de los clientes, cuáles son de México" → **filtro por columna**

El embedding **no responde nada de esto**: recupera texto parecido, no suma, no cuenta
ni filtra por `> 1000`. Para tablas, los embeddings son la herramienta equivocada.

**El modo Datos tiene 3 piezas:**

```
1) FILAS ESTRUCTURADAS guardadas (datos crudos, tipados)
   → refrescadas por modifiedTime.  SIN embeddings → barato, no cuesta OpenAI.
2) 1 EMBEDDING del encabezado/descripción (solo para "qué hoja usar" si hay varias).
   Casi nunca cambia.
3) HERRAMIENTA de consulta en Ruby que ejecuta sum/count/filter sobre las filas.
```

**Cómo se responde (patrón "LLM traduce → Ruby calcula"):**

```
El LLM NO calcula (es malo en aritmética con muchas filas → alucina números).
El LLM solo TRADUCE la pregunta a una consulta estructurada; Ruby la EJECUTA exacto.

"suma de precios"       → { op: sum,    col: precio }
"mayores a 1000"        → { op: count,  col: precio, where: { > 1000 } }
"clientes de México"    → { op: filter, col: pais,   where: { = "México" } }
        │
        ▼  (function-calling, se engancha en BotSeller::Dispatcher / RouterService
            como herramienta `consultar_hoja`)
Ruby ejecuta sobre las filas guardadas → resultado EXACTO y determinista.
```

Alternativa descartada: pasar todas las filas al LLM para que calcule él.
Solo sirve para hojas chicas y arriesga errores de aritmética → **no recomendado**.

> ⚠️ Decisión abierta (ahora más definida): para que filtros numéricos como `> 1000`
> sean correctos y rápidos, las filas conviene en **tabla `google_sheet_rows`** con
> columnas/valores tipados, no jsonb suelto. jsonb sirve para arrancar (hojas chicas),
> pero el filtrado numérico real pide tipos. Definir antes de Fase 2.

---

## 5. El problema de "qué pasa si se actualizan" (resuelto)

```
ACTUALIZACIÓN (disparada por el botón "Sincronizar ahora")
        │
        ├─ google_doc / sheet FAQ ─────────────────────────────────┐
        │   re-descarga → re-chunk → upsert chunks 0..N-1          │
        │   ★ DELETE knowledge_items WHERE source_id=X AND          │
        │     chunk_index >= N   (borra huérfanos si se ACHICÓ)     │
        │   → SÍ re-embebe (cuesta OpenAI)                          │
        │                                                           │
        └─ sheet modo Datos ───────────────────────────────────────┐
            REFRESCAR FILAS guardadas (google_sheet_rows)           │
            → NO re-embebe (el embedding es solo del encabezado)    │
            → barato, no cuesta OpenAI                              │
        │
ELIMINACIÓN / SIN ACCESO (trashed, 404, 403)
        ▼
   destroy_all de los items/filas de esa fuente + marcar source en error/inactiva
```

El bug latente que esto evita: el `upsert` actual solo toca `chunk_index: 0`. Para docs
multi-chunk hay que **borrar explícitamente los chunks sobrantes** en cada re-sync.

---

## 6. OAuth / scopes

- Reutilizar `Google::RefreshOauthTokenService` y `GOOGLE_OAUTH_CLIENT_ID/SECRET`.
- Scope nuevo: `https://www.googleapis.com/auth/drive.readonly`
  (+ `documents.readonly`, `spreadsheets.readonly` según API que se use).
- El usuario, al conectar una fuente, elige el archivo (idealmente con un **Google Picker**
  en el frontend, o pegando la URL/ID a mano en v1).

---

## 7. Directiva `{{hoja:nombre}}` e invocación desde el bot

Cada conexión Google se invoca desde el `complementary_prompt` del tracking como un
**servicio/directiva**, igual que `@buscar_foro(nombre)`. El nombre **único** de la fuente
es la clave de direccionamiento.

### Sintaxis elegida — prefijo namespaced (Opción B)

```
{{hoja:ventas_2026}}     → Google Sheet llamado "ventas_2026"
{{doc:manual_usuario}}   → Google Doc llamado "manual_usuario"   (misma lógica)
```

**Por qué el prefijo y NO `{{nombre}}` pelado:** el módulo de adjuntos de agentes IA ya
usa `{{nombre}}` para enviar un archivo por nombre (ver módulo AI agent attachments). El
prefijo `hoja:` / `doc:` **evita la colisión**, es autoexplicativo y extensible.

### Cómo se resuelve (paralelo exacto con `@buscar_foro`)

```
complementary_prompt:  ...consulta {{hoja:ventas_2026}} para precios...
        │
        ▼  detect_directive (KnowledgeBaseResponseService) — nuevo match:
   /\{\{hoja:([^}]+)\}\}/i  → { mode: :google_sheet, source_name: "ventas_2026" }
   /\{\{doc:([^}]+)\}\}/i   → { mode: :google_doc,   source_name: "..." }
        │
        ▼  resolución POR NOMBRE (como perform_discourse):
   @account.knowledge_sources.active
     .where(source_type: %w[google_sheet google_doc])
     .where('LOWER(name)=LOWER(?)', source_name).first
        │
        ├─ mode :google_sheet (modo Datos) → servicio "LLM traduce → Ruby calcula" (§4)
        ├─ mode :google_sheet (modo FAQ)   → pgvector semántico
        └─ mode :google_doc                → pgvector semántico
```

### ★ Unicidad del nombre — HAY que forzarla (hoy NO existe)

`KnowledgeSource` no valida nombre único, y la resolución usa `.first` → con nombres
repetidos elige uno **al azar y en silencio**. Para usar el nombre como dirección:

```ruby
validates :name, uniqueness: { scope: :account_id, case_sensitive: false }
```

El prefijo `hoja:`/`doc:` ya separa el espacio de nombres de los adjuntos, así que la
unicidad solo necesita ser **por cuenta** dentro de las fuentes Google.

### UI

En `EditTemplate.vue`, igual que `@buscar_foro` genera un token por fuente Discourse,
generar un token por conexión Google: `{{hoja:${source.name}}}` / `{{doc:${source.name}}}`
en el selector de directivas de la plantilla.

---

## 8. Fases

1. **Fase 1 — Docs + sync manual.** `google_doc`, descarga, chunking, embedding, botón
   "Sincronizar ahora". Manejo de re-chunk y borrado de huérfanos. Directiva `{{doc:nombre}}`.
2. **Fase 2 — Sheets.** Sheets en modo FAQ y modo Datos + directiva `{{hoja:nombre}}`
   (servicio de consulta). Google Picker en UI. Sync **también manual**.
3. **Fase 3 (diferida, opcional) — Automatización.** Cron por `modifiedTime`
   (`GoogleDriveSyncSchedulerJob`) y/o push (`changes.watch`). Solo si los docs empiezan a
   cambiar seguido y el sync manual se vuelve molesto.

---

## 9. Riesgos / decisiones abiertas

- **Lookup exacto de Sheets**: dónde persistir filas (ver §4). Define si Fase 2 es simple o
  necesita tabla nueva.
- **Cuotas de Drive/Docs API**: con sync manual el riesgo es bajo; solo importa si más
  adelante se agrega el cron (Fase 3) → ahí respetar rate limits y agrupar `files.get`.
- **Google Picker** vs pegar ID a mano: UX. v1 puede ser ID/URL manual.
- **Docs muy grandes**: límite de chunks por doc para no disparar costo de embeddings.
- **Validación de unicidad de nombre**: agregar a `KnowledgeSource` (rompe nada existente
  salvo que ya haya nombres duplicados en datos actuales → revisar antes de migrar).

Relacionado: [[Flujo-de-vectorizacion]] · [[Busqueda-semantica]] · [[Arquitectura]] ·
[[RouterService-y-bot]] (cómo el bot consume los items).
