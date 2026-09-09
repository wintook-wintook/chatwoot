# Fuente de Base de Conocimiento: WordPress

**Conectar un sitio WordPress a la Base de Conocimiento para que los Agentes IA
respondan con su contenido — indexando solo lo que se elige**

| | |
|---|---|
| **Rama de trabajo** | `feat/kbase_wordpress` (sale de `develop`) |
| **Estado** | solo plan — no hay código escrito |
| **Fecha** | 09/09/2026 |
| **Acceso** | público: solo la URL del sitio |
| **Migraciones** | ninguna |

---

## Índice

| # | Sección | Para qué |
|---|---|---|
| 1 | [La idea: conectar no es indexar](#1-la-idea-conectar-no-es-indexar) | el modelo en dos pasos y por qué |
| 2 | [Lo medido](#2-lo-medido) | responde "¿tarda? ¿consume?" con datos |
| 3 | [De dónde sale el contenido](#3-de-dónde-sale-el-contenido) | los endpoints, verificados |
| 4 | [Qué se elige y cómo se guarda](#4-qué-se-elige-y-cómo-se-guarda) | la regla, las excepciones |
| 5 | [Contenido nuevo](#5-contenido-nuevo) | el problema que trae elegir a mano |
| 6 | [El sincronizador](#6-el-sincronizador) | limpieza, troceo, lotes, incremental |
| 7 | [La directiva](#7-la-directiva) | cómo la usa un Agente IA |
| 8 | [El frontend](#8-el-frontend) | pantallas |
| 9 | [Modelo de datos](#9-modelo-de-datos) | dónde vive cada cosa |
| 10 | [Fases](#10-fases) | roadmap en días hábiles |
| 11 | [Archivos que toca](#11-archivos-que-toca) | mapa de cambios |
| 12 | [Riesgos y decisiones pendientes](#12-riesgos-y-decisiones-pendientes) | lo que falta definir |
| 13 | [Lo que NO entra](#13-lo-que-no-entra) | límites del alcance |

---

## 1. La idea: conectar no es indexar

Conectar un sitio baja **solo los títulos**. Recién después se elige qué se
indexa, y solo eso se vectoriza.

```
  ┌─ 1 · CONECTAR ────────────────── 3 segundos, sin vectorizar nada ──┐
  │   Se bajan los títulos, las fechas y las categorías. Nada más.     │
  │   213 KB para un sitio de 1.106 entradas.                          │
  └────────────────────────────┬───────────────────────────────────────┘
                               ▼
  ┌─ 2 · ELEGIR ───────────────────────────────────────────────────────┐
  │   ☑ Soporte (113)   ☑ Guías (27)   ☐ Novedades (380)   ← la regla  │
  │   ──────────────────────────────────────────────────────────────   │
  │   ☑ Cómo actualizar a la última versión           07/09/2026       │
  │   ☑ Firebird 5: compatibilidad con Kontrolya      22/08/2026       │
  │   ☐ Comunicado de prensa Q3                       14/08/2026  ←    │
  │                                            la excepción, a mano    │
  └────────────────────────────┬───────────────────────────────────────┘
                               ▼
  ┌─ 3 · VECTORIZAR ─── solo lo elegido, y solo eso se baja completo ───┐
```

### 1.1 Por qué, y no es por ahorrar

El ahorro de tiempo ya estaba resuelto por otro lado (§2.2: 17 segundos el sitio
entero, con lotes). **Lo que este modelo arregla es la calidad de la respuesta.**

El manual del motor lo dice en su §6: con umbral 0.20 sobre un corpus amplio,
*"lo más parecido casi siempre existe"*. Traducido: si se vectorizan las 1.106
entradas de un blog —incluidas las novedades de 2019 y los comunicados de
prensa— el agente **siempre** va a encontrar algo, y va a contestar con eso.

```
  ÍNDICE COMPLETO                      ÍNDICE ELEGIDO
  1.106 entradas                       40 guías de soporte
       │                                    │
  "¿cómo actualizo?"                   "¿cómo actualizo?"
       │                                    │
  encuentra un comunicado de           encuentra la guía correcta —
  prensa de 2019 que menciona          o no encuentra nada, que es
  "actualización" y contesta           una respuesta honesta
  con eso
```

> **Un corpus chico y elegido contesta mejor que uno grande.** No es una
> optimización de recursos: es una mejora de la respuesta.

Y hay un tercer beneficio que hoy no existe en ninguna fuente: **el usuario ve qué
sabe su agente**. Puede responder "¿de dónde sacó eso?" mirando una lista.

### 1.2 Lo que este modelo NO puede ser

Son 1.106 títulos. Una lista con casillas que haya que revisar una por una no la
mira nadie, y un mes después está desactualizada.

Por eso la elección es **de a dos niveles**:

```
  la CATEGORÍA es la regla        →  cubre el 95% con dos clics
  la LISTA es para excepciones    →  sacar lo que sobra, meter lo suelto
```

---

## 2. Lo medido

Todo se midió el 09/09/2026 contra `wordpress.org/news` (sitio real de 1.106
entradas) y contra la API de embeddings real.

### 2.1 El listado pesa 115× menos que el contenido

```
  100 entradas, contenido completo    2.328.494 bytes
  100 entradas, solo títulos             20.211 bytes
  ────────────────────────────────────────────────────
  los 1.106 títulos del sitio        3,2 s · 213 KB · 12 páginas
```

Se pide con `?_fields=id,title,date,categories,link`, que WordPress soporta de
fábrica. Conectar un sitio es instantáneo y no cuesta un centavo.

### 2.2 Vectorizar: cuánto tarda y por qué hoy tardaría 14 minutos

```
  entradas del sitio          1.106
  HTML crudo, promedio       24.700 caracteres
  texto limpio, promedio      6.286 caracteres   ← el 75% era markup
  chunks por entrada           2,07
  sitio completo              2.286 chunks

  ┌──────────────────────────────────────────────────────────────┐
  │  latencia medida contra la API real                          │
  ├──────────────────────────────────────────────────────────────┤
  │  1 chunk por petición      367 ms  (354 · 284 · 464)         │
  │  100 chunks en un lote     671 ms  →  7 ms por chunk         │
  └──────────────────────────────────────────────────────────────┘

  uno por petición  ██████████████████████████████████  14,0 min
  en lotes de 100   █                                    0,3 min
```

**El motor hoy hace lo primero.** `KnowledgeEmbeddable#generate_embedding`
(`app/jobs/knowledge_embeddable.rb:18`) manda **un chunk por petición HTTP**:

```ruby
request.body = { model: 'text-embedding-3-small', input: text }.to_json
```

Con Google Docs nunca se notó —un documento son 2 o 3 chunks, medio segundo—
pero un sitio lo convierte en minutos de un worker de Sidekiq ocupado. Ya existe
un `embed_batch` que agrupa, pero vive en `Cases::Ai::BaseService` (el módulo de
Tickets) y ningún job de la Base de Conocimiento lo usa.

### 2.3 El costo es irrelevante

```
  sitio COMPLETO      2.286 chunks   1.867.662 tokens   USD 0,04
  selección típica      290 chunks     237.000 tokens   USD 0,005
```

**Cuatro centavos el sitio entero.** El costo no debe influir en ninguna decisión
de diseño; lo que importa es el worker ocupado y —sobre todo— la calidad de la
búsqueda.

### 2.4 Respuesta corta

| Pregunta | Respuesta |
|---|---|
| ¿Conectar tarda? | 3 segundos. No vectoriza nada. |
| ¿Vectorizar tarda? | Con lotes, 2 segundos una selección típica; 17 s el sitio entero. Sin lotes, 14 minutos. |
| ¿Consume recursos? | En dinero no: medio centavo. En worker sí, y por eso los lotes son fase propia. |
| ¿Y un sitio 10× más grande? | Escala lineal, pero el modelo de elegir hace que el índice **no** crezca 10×. Ese es el punto. |

---

## 3. De dónde sale el contenido

Los tres endpoints se probaron el 09/09/2026: **200 sin credencial**.

| Contenido | Endpoint | Credencial |
|---|---|---|
| Entradas | `/wp-json/wp/v2/posts` | no |
| Páginas | `/wp-json/wp/v2/pages` | no |
| Productos | `/wp-json/wc/store/v1/products` | no |

### 3.1 WooCommerce: la Store API, no la clásica

```
  wc/store/v1/products   →  200   Store API, pública        ✅
  wc/v3/products         →  401   API clásica, exige clave
```

Con la clásica habría que pedir claves de consumidor, y el requisito es que
alcance con la URL. La Store API existe para los bloques de tienda del propio
sitio, así que es pública por diseño.

### 3.2 Lo que WordPress ya filtra por nosotros

```
  ?_fields=id,title,date,categories,link   solo lo del listado     ✅
  ?categories=3,7                          solo esas categorías    ✅
  ?include=412,588                         traer entradas sueltas  ✅
  ?exclude=412,588                         quitar sueltas          ✅
  ?modified_after=<fecha>                  solo lo cambiado        ✅
  ?per_page=100&page=N                     paginado
  X-WP-Total / X-WP-TotalPages             el total, en cabeceras
```

Nada se filtra del lado nuestro, y el avance que se muestra es real porque sale
de `X-WP-TotalPages`.

### 3.3 El sitio que dice 403

Un tercer sitio probado devolvió **403 en todos los endpoints**: hay
instalaciones que bloquean la API REST por plugin de seguridad o firewall.

No es raro y no puede descubrirse en producción. **Al conectar se hace una
llamada de prueba** y, si falla, se dice qué pasó y qué revisar.

---

## 4. Qué se elige y cómo se guarda

La regla es la categoría; la lista es para las excepciones. Eso se guarda en
`knowledge_sources.config` (ya es `jsonb`):

```json
{
  "site_url": "https://misitio.com",
  "content_types": ["posts", "pages"],
  "categories": [3, 7],
  "excluded_ids": [412, 588],
  "included_ids": [901],
  "last_synced_at": "2026-09-09T14:00:00Z",
  "config_fingerprint": "a1b2c3…",
  "last_error": null
}
```

```
  categories    ┃ la REGLA — entra todo lo de estas categorías
  excluded_ids  ┃ excepción hacia afuera — sacar de lo que la regla trae
  included_ids  ┃ excepción hacia adentro — meter algo que la regla no cubre
```

### 4.1 El catálogo de títulos NO se guarda

Se vuelve a pedir cada vez que se abre la pantalla de selección: son 3 segundos y
213 KB. Guardarlo obligaría a mantenerlo sincronizado y a resolver qué pasa
cuando el sitio cambia — un problema entero que no hace falta tener.

Lo que se guarda son **decisiones**, no contenido. Ocupan bytes y no se
desactualizan.

### 4.2 `config_fingerprint`

Hash de lo que afecta al contenido: tipos, categorías, `excluded_ids`,
`included_ids`. Si cambia, el próximo sync ignora `modified_after` y rehace todo.

Sin eso, alguien agrega una categoría, sincroniza, y no pasa nada — en silencio,
que es el modo de falla que este módulo tiene que evitar.

---

## 5. Contenido nuevo

Elegir a mano trae un problema que indexar todo no tenía: **¿qué pasa cuando
publican una entrada nueva?**

Si hay que ir a aprobarla, nadie va a ir. El sitio crece, el agente se queda
viejo, y nadie se entera.

**La decisión tomada:** la categoría es la regla, así que lo nuevo que caiga en
una categoría elegida **entra solo** — y se avisa.

```
   publican "Actualizar a Firebird 5" en Soporte
                    │
                    ▼
        ¿Soporte está elegida?
           │              │
          sí             no
           │              │
           ▼              ▼
     entra al índice   queda afuera
     y se avisa:       (aparece en la lista para
                        elegirla si se quiere)
     ┌──────────────────────────────────────────┐
     │ 🌐 Blog Kontrolya                         │
     │ 7 entradas nuevas de Soporte se           │
     │ agregaron al índice.        [ Ver cuáles ]│
     └──────────────────────────────────────────┘
```

Es coherente con el modelo: **quien decide es la regla que el usuario ya fijó**,
no una aprobación caso por caso que se va a olvidar. Y el aviso existe para que
"entra solo" no sea "entra a escondidas".

Una entrada en `excluded_ids` no vuelve a entrar aunque su categoría esté
elegida: la excepción manual gana sobre la regla, siempre.

---

## 6. El sincronizador

`WordpressSyncJob`, con `GoogleDocSyncJob` de molde. Con una diferencia de fondo
que impide copiarlo:

```
  GOOGLE DOC                          WORDPRESS
  ─────────────────────               ─────────────────────────────
  1 fuente = 1 documento              1 fuente = las entradas elegidas
  chunks 0..N de ese documento        cada entrada tiene sus chunks
  se rebaja entero cada vez           conviene bajar solo lo cambiado
```

### 6.1 El recorrido

```
   ┌─────────────────────────────────────────────────────────────────┐
   │ 0 · RESOLVER         qué ids entran, según categories +          │
   │                      included_ids − excluded_ids                 │
   └───────────────────────────┬─────────────────────────────────────┘
                               ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 1 · BAJAR            solo esas entradas, completas               │
   │                      ?include=… paginado · ?modified_after si    │
   │                      es resync y el fingerprint no cambió        │
   └───────────────────────────┬─────────────────────────────────────┘
                               ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 2 · LIMPIAR          quitar <script> <style>, etiquetas,         │
   │                      shortcodes y entidades                      │
   │                      ← acá se cae el 75% del volumen             │
   └───────────────────────────┬─────────────────────────────────────┘
                               ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 3 · TROCEAR          4.000 caracteres, 400 de solape             │
   │                      (los mismos que ya usa Google Docs)         │
   └───────────────────────────┬─────────────────────────────────────┘
                               ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 4 · VECTORIZAR       EN LOTES DE 100  ← la pieza que falta hoy   │
   └───────────────────────────┬─────────────────────────────────────┘
                               ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │ 5 · UPSERT           knowledge_items + borrar los huérfanos:     │
   │                      lo despublicado Y lo que se deseleccionó    │
   └─────────────────────────────────────────────────────────────────┘
```

El paso 5 tiene un caso que no existía antes: **deseleccionar tiene que borrar**.
Si alguien saca una categoría del índice y sus chunks quedan, el agente sigue
contestando con contenido que el usuario cree haber quitado. Es la peor variante
del fallo silencioso, porque la pantalla dice una cosa y el motor hace otra.

### 6.2 Lo que hay que construir en `KnowledgeEmbeddable`

Un `generate_embeddings(account, textos)` que agrupe, **al lado** del de a uno que
ya existe. No se toca el de a uno: lo usan `canned_response` y `article`, donde no
molesta, y cambiarlo sería arrastrar riesgo a un camino que hoy funciona.

`Cases::Ai::BaseService#embed_batch` resuelve el mismo problema y sirve de
referencia — conserva el orden por `index`, que es lo que hay que cuidar.

### 6.3 Resincronización

```
  ¿cambió el fingerprint?  →  sí  →  rehacer todo
                           →  no  →  ?modified_after=last_synced_at
```

Con una salvedad: **lo borrado no aparece**. Una entrada despublicada deja de
venir en la lista, no llega marcada como borrada. Hay que reconciliar contra los
ids que ya están indexados.

---

## 7. La directiva

Una fuente nueva es una directiva nueva. Se propone `@buscar_sitio(<nombre>)`,
del mismo tipo que `@buscar_foro(<nombre>)`: direccionada por nombre, porque una
cuenta puede tener más de un sitio conectado.

```
  @ruta(soporte #soporte1: no puedo entrar, me da error): @buscar_sitio(Blog Kontrolya)
```

Toca tres lugares del motor:

```
  KnowledgeSource::SOURCE_TYPES        + 'wordpress'
  Directives::SEARCH_DIRECTIVES        + [/@buscar_sitio\(([^)]+)\)/i, :wordpress, true]
  KnowledgeBaseResponseService         + when :wordpress → pgvector por knowledge_source_id
```

> ⚠ **`SOURCE_TYPES` no existe en `develop`.** Se extrajo en
> `feat/motor_agentes_ia`, que todavía no está mergeada. Acá hay que tocar el
> array en línea de la validación. **Cuando las dos ramas se junten**, el spec de
> completitud del Asistente va a fallar hasta que `wordpress` tenga su entrada en
> `InventoryService::SOURCE_DIRECTIVES`. Eso es el guardarraíl funcionando — pero
> conviene resolverlo en el merge y no descubrirlo ahí.

---

## 8. El frontend

Con los componentes nativos, sobre las pantallas de `knowledgeSources/` que ya
existen.

### 8.1 Paso 1 — conectar

```
  ┌────────────────────────────────────────────────────────────┐
  │  Conectar un sitio WordPress                           [×] │
  ├────────────────────────────────────────────────────────────┤
  │  Nombre         [ Blog Kontrolya                        ]  │
  │  URL del sitio  [ https://misitio.com                   ]  │
  │                                                            │
  │                                     [ Conectar y revisar ] │
  └────────────────────────────────────────────────────────────┘
```

No hay más que eso. Nada de vectorizar todavía.

### 8.2 Paso 2 — elegir

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  Blog Kontrolya · elegir qué sabe el agente                  [×] │
  │  ✓ Responde. 1.106 entradas · 24 páginas · sin tienda            │
  ├──────────────────────────────────────────────────────────────────┤
  │  ¿Qué tipo de contenido?                                         │
  │    ☑ Entradas (1.106)   ☑ Páginas (24)   ☐ Productos (—)         │
  │                                                                  │
  │  Categorías          (elegir una entra todo lo suyo, y lo nuevo) │
  │    ☑ Soporte (113)   ☑ Guías (27)   ☐ Novedades (380)  …         │
  ├──────────────────────────────────────────────────────────────────┤
  │  [ buscar…                    ]   ( ) todas  (•) solo elegidas   │
  │                                                                  │
  │  ☑ Cómo actualizar a la última versión      Soporte  07/09/2026  │
  │  ☑ Firebird 5: compatibilidad con Kontrolya Soporte  22/08/2026  │
  │  ☐ Comunicado de prensa Q3                  Novedad  14/08/2026  │
  │  ☑ Guía de instalación paso a paso          Guías    02/07/2026  │
  │                                                    … 136 más     │
  ├──────────────────────────────────────────────────────────────────┤
  │  140 de 1.130 elegidas  ·  ≈ 290 fragmentos  ·  ~2 s  ·  USD 0,01│
  │                                                                  │
  │                            [ Cancelar ]  [ Indexar lo elegido ]  │
  └──────────────────────────────────────────────────────────────────┘
```

Cuatro cosas de esa pantalla que no son decorativas:

**La categoría arriba, la lista abajo.** Ese orden es el modelo: primero la regla
con dos clics, después las excepciones. Al revés, son mil casillas.

**El filtro "solo elegidas".** Es lo que hace revisable una lista de mil: se
marca por categoría y se revisa lo que quedó, no lo que hay.

**El renglón de abajo.** Sale de los conteos reales y de los números medidos en
§2. Ver "2 segundos" antes de apretar es la diferencia entre esperar y creer que
se colgó.

**Una casilla desmarcada a mano queda desmarcada** aunque su categoría esté
elegida. La excepción gana sobre la regla, siempre — si no, deseleccionar no
serviría de nada.

### 8.3 Estado de la fuente

```
  ┌────────────────────────────────────────────────────────────┐
  │  🌐 Blog Kontrolya               [ Elegir ]  [ Sincronizar ]│
  │  https://misitio.com                                       │
  │                                                            │
  │  140 entradas elegidas       290 fragmentos                │
  │  última sincronización       hoy 14:32                     │
  │  ● sincronizando             página 3 de 4                 │
  │                                                            │
  │  ┌──────────────────────────────────────────────────────┐  │
  │  │ 7 entradas nuevas de Soporte se agregaron al índice.  │  │
  │  │                                        [ Ver cuáles ] │  │
  │  └──────────────────────────────────────────────────────┘  │
  └────────────────────────────────────────────────────────────┘
```

### 8.4 Cuando falla

```
  ┌────────────────────────────────────────────────────────────┐
  │  ⚠ No se pudo leer el sitio                                │
  │                                                            │
  │  El sitio respondió 403 al pedir /wp-json/wp/v2/posts.     │
  │  Suele pasar cuando un plugin de seguridad bloquea la API  │
  │  de WordPress. Hay que permitir el acceso de lectura a     │
  │  /wp-json/ y volver a probar.                              │
  └────────────────────────────────────────────────────────────┘
```

---

## 9. Modelo de datos

**Ninguna tabla nueva y ninguna migración.** Confirmado el 09/09/2026 contra los
modelos.

| Dónde | Qué guarda |
|---|---|
| `knowledge_sources` | una fila por sitio, `source_type: 'wordpress'`, todo lo demás en `config` (jsonb) |
| `knowledge_items` | un registro por chunk, ligado por `knowledge_source_id` |

`knowledge_items` ya tiene todo lo necesario:

```
  title     → el título de la entrada
  content   → el chunk limpio
  source_id → el id de la entrada en WordPress   (integer)
  metadata  → { wp_type: 'post', url: 'https://…', modified: '…' }
```

Y su índice único encaja sin inventar nada:

```
  idx_knowledge_items_source  (account_id, source_type, source_id, chunk_index) UNIQUE
```

Como `source_id` es entero, **el id de la entrada entra ahí directo** y el par
(entrada, chunk) queda único por construcción. El upsert y el borrado de
huérfanos salen del índice que ya existe.

---

## 10. Fases

```
  F1 ████        Cliente: probe + listado de títulos
  F2 ████        Limpieza de HTML y troceo
  F3 ██          Embeddings en lote  ← sin esto, 14 min
  F4 ████        El job: indexar solo lo elegido, borrar lo deseleccionado
  F5 ████        La directiva en el motor
  F6 ████████    Frontend: conectar y la pantalla de elegir
  F7 ████        Contenido nuevo: regla de categoría + aviso
```

| Fase | Qué entrega | Días | Fechas |
|---|---|---|---|
| **F1** | `WordpressClient`: paginado, los tres endpoints, `probe` que detecta 403 y trae conteos y categorías, y el listado de títulos con `_fields` | 2 | jue 10/09 – vie 11/09 |
| **F2** | Limpieza de HTML y troceo, con specs sobre HTML real de Gutenberg | 2 | lun 14/09 – mar 15/09 |
| **F3** | `generate_embeddings` en lote, sin tocar el de a uno | 1 | mié 16/09 |
| **F4** | `WordpressSyncJob`: resolver ids → bajar → limpiar → trocear → vectorizar → upsert + huérfanos, incluido lo deseleccionado | 2 | jue 17/09 – vie 18/09 |
| **F5** | `@buscar_sitio(...)` en `SOURCE_TYPES`, `SEARCH_DIRECTIVES` y `KnowledgeBaseResponseService` | 2 | lun 21/09 – mar 22/09 |
| **F6** | Conectar, la pantalla de elegir (categorías + lista con buscador y filtro), estado y errores | 4 | mié 23/09 – lun 28/09 |
| **F7** | `modified_after`, `config_fingerprint`, reconciliación de borrados y el aviso de contenido nuevo | 2 | mar 29/09 – mié 30/09 |

**Primer entregable demostrable: F1.** Con solo el cliente se apunta a cualquier
sitio y se ve si responde, cuánto tiene y qué categorías — sin vectorizar nada.
Es además el paso 1 completo del modelo.

**F3 va antes que F4** a propósito: si el job se escribe contra el embedding de a
uno, después hay que reescribirlo.

**F6 creció de 3 a 4 días** respecto de la versión anterior del plan: la pantalla
de elegir es trabajo real —buscador, filtro, selección de a dos niveles— y es la
pieza de la que depende que el modelo funcione.

---

## 11. Archivos que toca

### Nuevos

```
  app/services/wordpress_client.rb              paginado, endpoints, probe, listado
  app/services/wordpress/content_cleaner.rb     HTML → texto
  app/services/wordpress/selection.rb           categories + included − excluded → ids
  app/jobs/wordpress_sync_job.rb                el sincronizador
  app/javascript/.../knowledgeSources/WordpressConnectModal.vue
  app/javascript/.../knowledgeSources/WordpressPickerModal.vue
  spec/services/wordpress_client_spec.rb
  spec/services/wordpress/content_cleaner_spec.rb
  spec/services/wordpress/selection_spec.rb
  spec/jobs/wordpress_sync_job_spec.rb
```

### Modificados

```
  app/models/knowledge_source.rb                + 'wordpress' (array en línea, ver §7)
  app/jobs/knowledge_embeddable.rb              + generate_embeddings (lote)
  app/services/knowledge_base/directives.rb     + @buscar_sitio
  app/services/knowledge_base_response_service.rb  + when :wordpress
  app/controllers/.../knowledge_base_controller.rb + probe, listado, selección
  .../knowledgeSources/AddSourceModal.vue       + la opción WordPress
  .../knowledgeSources/SourceCard.vue           + estado y aviso de contenido nuevo
  i18n es/en
```

---

## 12. Riesgos y decisiones pendientes

### 12.1 Riesgos

| Riesgo | Mitigación |
|---|---|
| **Deseleccionar no borra** y el agente sigue contestando con contenido que el usuario cree haber quitado | Es el caso explícito del paso 5 (§6.1) y va con spec propio: la pantalla y el motor no pueden decir cosas distintas |
| **Un sitio enorme bloquea un worker** | F3 antes que F4; el job pagina, así que se corta y continúa. Y el modelo de elegir hace que el índice no crezca con el sitio |
| **El sitio bloquea la API (403)** | El probe lo detecta al conectar, con un mensaje que dice qué revisar |
| **Gutenberg mete ruido** que la limpieza no contempla | Los specs de F2 se escriben contra HTML real bajado del sitio, no inventado |
| **Contenido despublicado que sigue indexado** | Reconciliación por ids en F7; hasta entonces, el resync completo lo corrige |
| **La lista de mil títulos vuelve inusable la pantalla** | Categoría primero, buscador y filtro "solo elegidas". Si aun así molesta, paginar el listado |
| **El merge con `feat/motor_agentes_ia`** hace fallar el spec de completitud | Escrito en §7: se resuelve agregando `wordpress` a `InventoryService` |

### 12.2 Decisiones pendientes

| # | Decisión | Opciones |
|---|---|---|
| 1 | **Nombre de la directiva** | `@buscar_sitio(...)` · `@buscar_web(...)` · `{{wp:...}}`. Cambiarla después obliga a reescribir Entrenamientos ya guardados |
| 2 | **¿Sincroniza sola?** | Solo con el botón (como Google Docs hoy) · o además un cron diario. Con la regla de categoría de §5, el cron es lo que hace que "entra solo" pase de verdad |
| 3 | **¿Contenido completo o resumen?** | ¿Se vectoriza el `content` o alcanza el `excerpt`? El excerpt es 10× más chico y para muchos blogs alcanza |
| 4 | **Productos de WooCommerce** | ¿Qué campos entran — descripción, precio, stock? El precio cambia seguido y desactualiza el índice |
| 5 | **¿Cuántos sitios por cuenta?** | Direccionado por nombre, como el foro. Confirmar que el índice único de `knowledge_sources` no lo impide |

---

## 13. Lo que NO entra

| Fuera de alcance | Por qué |
|---|---|
| **Escribir en WordPress** | La fuente es de lectura. Publicar desde Chatwoot es otro proyecto |
| **Contenido privado o borradores** | Requiere credenciales; el requisito es que alcance con la URL |
| **La API clásica de WooCommerce** (`wc/v3`) | Exige claves de consumidor. La Store API cubre el caso público |
| **Comentarios de las entradas** | Son opinión de terceros, no documentación de la empresa |
| **Multisite** | Cada sitio de una red se conecta como una fuente aparte |
| **Traducciones (WPML/Polylang)** | Se vectoriza lo que devuelve la API en su idioma por defecto |
| **Aprobar una por una el contenido nuevo** | Decidido en §5: la regla es la categoría. Una aprobación caso por caso se olvida y el índice envejece |

---

## Anexo · Glosario

| Término | Qué es |
|---|---|
| **Chunk** | Un trozo de texto de ~4.000 caracteres, la unidad que se vectoriza |
| **Embedding** | El vector que representa un chunk y permite la búsqueda semántica |
| **Store API** | La API pública de WooCommerce (`wc/store/v1`), sin credenciales |
| **Probe** | La llamada de prueba al conectar: detecta bloqueos y trae conteos y categorías |
| **Fingerprint** | Hash de la selección; si cambia, obliga a reindexar |
| **La regla / la excepción** | La categoría decide en bloque; la casilla individual la corrige |
