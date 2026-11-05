# Respuestas predefinidas: categorías, vectorización visible y tabla completa — plan v1.0

Rama `feat/respuestas_predefinidas` (desde develop `5dd93715`, 05/11/2026). D1–D5 decididas
(«si», 05/11/2026).

---

## 1. Cómo funciona hoy

```
 Pantalla  ──POST/PATCH──►  CannedResponsesController  ──►  canned_responses (guardada)
                                                              │ after_commit
                                     ¿nueva, o cambió nombre o contenido?
                                                              │ sí
                                                              ▼
                                         KnowledgeItemSyncJob (Sidekiq)
                                           texto  = "NOMBRE: contenido"
                                           vector = OpenAI text-embedding-3-small (clave de la cuenta)
                                           ──► knowledge_items (título = NOMBRE)
                                                              │
                                                              ▼
                       el agente la encuentra con @buscar_predefinidas(…) por parecido
```

Lo que falla o falta:

| # | Problema | Hoy |
|---|---|---|
| P1 | Sin integración de OpenAI | se guarda, **no se vectoriza y nadie se entera**: el agente nunca la encuentra |
| P2 | Falla la llamada a OpenAI (timeout, 429, clave mala) | solo queda en el log; sin vector, o con el vector **viejo** |
| P3 | Fuente «Respuestas predefinidas» desactivada | el job intenta crear otra, choca con el índice único y truena: no se vectoriza ninguna |
| P4 | «Grupo» = **prefijo del nombre** | `@buscar_predefinidas(PATITAS)` = las que empiezan con «PATITAS». Medido en dev: 4 agentes buscan en `ADAM POLITICA MANEJO DE PRECIOS` y `ADAM POLITICA SOLICITUD DE CORREO`, que **no encuentran ninguna** (se escribió el nombre de una política como si fuera categoría) |
| P5 | La tabla | sin paginación, sin filtros, solo ordena por nombre, no dice si está vectorizada ni cuándo se creó o cambió |

---

## 2. Categorías (P4) — y qué le pasa al motor

### 2.1 La propuesta

Una tabla nueva y una columna:

```
 canned_response_categories            canned_responses
 ─────────────────────────────         ──────────────────────────────
 id · account_id · name (único         … · category_id (nullable) ──┐
   por cuenta) · description ·                                       │
   created_at · updated_at   ◄───────────────────────────────────────┘
```

Una predefinida tiene **una** categoría o ninguna (D1).

### 2.2 El motor: `@buscar_predefinidas(PATITAS)` sigue funcionando

`PATITAS` pasa a significar: **la categoría que se llama PATITAS** y, si no existe categoría con
ese nombre, **lo de siempre (el prefijo)**. Así ningún agente que ya existe cambia de resultado.

```
 @buscar_predefinidas(PATITAS)
        │
        ├─ ¿hay una categoría «PATITAS» en la cuenta?
        │      sí → las predefinidas de esa categoría        (umbral de grupo 0.45, igual que hoy)
        │      no → las que empiezan con «PATITAS» (prefijo) (comportamiento actual)
        │
 @buscar_predefinidas(!PATITAS)  → todas menos esa categoría (o ese prefijo)
 @buscar_predefinidas            → todas (sin cambio)
```

- **Cómo lo sabe la búsqueda sin otra consulta**: la categoría se guarda también en el
  `knowledge_item` (`metadata.category`). Cambiar la categoría de una predefinida **no** pide
  embedding nuevo: solo se actualiza ese dato (sin OpenAI). El nombre de la categoría no entra al
  texto vectorizado (D2).
- **Dónde se toca**: las dos copias de la regla — `KnowledgeBaseResponseService#grouped_items` y
  `KnowledgeBase::CannedGroup` (prueba en seco), amarradas por `canned_group_spec`.
- **Renombrar o borrar una categoría** que usan agentes los rompería en silencio. Por eso: al
  renombrar/borrar, la pantalla dice **qué agentes la usan** (por su Entrenamiento) y pide
  confirmar; y el comprobador del Asistente marca en rojo un `@buscar_predefinidas(X)` que no
  encuentra **ninguna** predefinida (hoy marcaría los 4 agentes de ADAM).

### 2.3 Las predefinidas que ya existen

No se mueven solas. La pantalla **sugiere** categorías a partir de los prefijos que usan los
agentes (`PATITAS` → 14 predefinidas) y la persona las acepta (D3).

---

## 3. Vectorización visible (P1, P3)

Cada predefinida guarda **su estado de vectorización**:

| Estado | Cuándo | En la tabla |
|---|---|---|
| `ready` | tiene vector y está al día | ✓ En la fuente de datos |
| `pending` | se encoló, todavía no termina | ⏳ Vectorizando… |
| `no_key` | la cuenta no tiene OpenAI | ⚠ No está en la fuente de datos: falta activar OpenAI |
| `failed` | OpenAI falló sin remedio (§4) | ✗ No se pudo vectorizar — motivo · [Reintentar] |
| `stale` | cambió y falló: el agente usa el **vector viejo** | ⚠ Desactualizada · [Reintentar] |

```
 Respuestas predefinidas                                   [+ Agregar]
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ ⚠ 12 respuestas no están en la fuente de datos: activa OpenAI en             │
 │   Integraciones. Después vectorízalas una por una con [Vectorizar].           │
 └──────────────────────────────────────────────────────────────────────────────┘
```

**Al activar OpenAI no se vectoriza todo de golpe** (pedido del usuario): cada fila sin vector
tiene **[Vectorizar]** y se hace una por una. Opción a decidir (D4): seleccionar varias con un tope
por vez (p. ej. 20), para cuentas con cientos.

P3 se arregla buscando la fuente aunque esté inactiva (y diciéndolo en la tabla) en lugar de
intentar crear otra.

---

## 4. Cuando falla OpenAI (P2) — la mejor forma

```
 KnowledgeItemSyncJob
   ├─ error PASAJERO (timeout, sin red, 429 límite, 5xx)
   │     → reintenta solo: 5 veces con espera creciente (segundos → minutos, retry_on de Rails)
   │       estado `pending` mientras tanto
   ├─ error PERMANENTE (401 clave inválida, 400 texto inválido, cuota agotada)
   │     → no reintenta: estado `failed` con el motivo en palabras
   └─ agotó los reintentos → `failed` (o `stale` si ya tenía un vector anterior)
```

- El motivo se guarda (`embedding_error`) y la fecha del último intento: la tabla lo muestra.
- **[Reintentar]** por fila: lo mismo que [Vectorizar].
- El vector viejo **no se borra** al fallar (el agente sigue encontrando la versión anterior), pero
  queda marcado `stale` para que se vea.
- Mismo arreglo sirve para los artículos del Centro de Ayuda (usan el mismo job) — D5.

---

## 5. La tabla, como la de contactos

Mismos componentes que Contactos (`vue-easytable` + `TableFooter` con paginación del servidor).

```
 Respuestas predefinidas                                         [+ Agregar] [Categorías]
 [ Buscar nombre o contenido…            ]  Categoría [Todas ▾]  Fuente de datos [Todas ▾]
                                            Prompt propio [Todas ▾]
 ┌───┬──────────────────┬───────────────────────┬──────────┬───────────┬─────────┬─────────┬────────────┐
 │ ☐ │ Nombre ▲         │ Contenido             │ Categoría│ Fuente    │ Creada  │ Cambió  │ Acciones   │
 ├───┼──────────────────┼───────────────────────┼──────────┼───────────┼─────────┼─────────┼────────────┤
 │ ☐ │ PATITAS_CONSULTA │ La consulta cuesta …  │ PATITAS  │ ✓         │ 12/09   │ 03/11   │ ✎ 🗑        │
 │ ☐ │ PATITAS_VACUNAS  │ Aplicamos vacunas …   │ PATITAS  │ ⚠ sin key │ 12/09   │ 12/09   │ ✎ 🗑 [Vect.]│
 │ ☐ │ HORARIO          │ Abrimos de 9 a 18 …   │ —        │ ✗ falló   │ 01/10   │ 04/11   │ ✎ 🗑 [Reint]│
 └───┴──────────────────┴───────────────────────┴──────────┴───────────┴─────────┴─────────┴────────────┘
  Seleccionadas (2): [Cambiar categoría] [Vectorizar] [Eliminar]            ‹ 1 2 3 › · 25 por página
```

- **Ordenar** por nombre, categoría, estado, creada, actualizada (en el servidor).
- **Filtros**: texto (nombre o contenido), categoría (incluye «sin categoría»), estado de
  vectorización, con/sin prompt propio.
- **Acciones**: editar, eliminar (con aviso de qué agentes la buscan por su categoría), vectorizar /
  reintentar; en lote: cambiar categoría, vectorizar (con tope), eliminar.
- **Sin romper el «/» del editor de mensajes**: el mismo `GET canned_responses` sin `page` sigue
  devolviendo la lista completa como hoy; la tabla pide `page`, `sort`, filtros.

---

## 6. Fases

| Fase | Qué | Se puede probar |
|---|---|---|
| **R0** ✅ | Medir en dev y staging: cuántas predefinidas sin vector, cuántos agentes usan grupos, qué prefijos | §6.1 |
| **R1** ✅ | Estado de vectorización + reintentos (§3, §4) + arreglo P3 | una cuenta sin OpenAI ve «no está en la fuente de datos»; al activarla, [Vectorizar] |
| **R2** | Tabla nueva: paginación, orden, filtros, acciones (§5) | ordenar por fecha, filtrar «sin vectorizar» |
| **R3** | Categorías: tabla, modal, columna, filtro, acciones en lote (§2.1, §2.3) | crear «PATITAS» y mover 14 |
| **R4** | Motor: `@buscar_predefinidas(X)` = categoría o prefijo, en las dos copias + spec (§2.2) | un agente con `(PATITAS)` encuentra igual antes y después |
| **R5** | Protección: avisos al renombrar/borrar categoría, comprobador marca grupos vacíos | los 4 agentes de ADAM salen en rojo |

---

## 6.1 R0 — medido ✅ (05/11/2026, solo lectura)

| | dev (`chatwoot_dev`) | staging (`chatwoot_staging_v2`) |
|---|---|---|
| Cuentas con predefinidas | 1 | **125** |
| Predefinidas | 24 | **1 870** (desde 26/05/2022) |
| …en cuentas con OpenAI activo | 24 | **1 368** (81 cuentas) |
| **Vectorizadas** | 24 | **0** |
| Fuentes de predefinidas inactivas (P3) | 0 | 0 |
| Agentes con `@buscar_predefinidas` | 10 (4 con grupos vacíos de ADAM) | 0 de 15 |
| Cuenta con más | — | 318: **386** predefinidas |

**Lo que dice:**
- En staging **ninguna** predefinida está en la fuente de datos, ni siquiera en las 81 cuentas que sí
  tienen OpenAI: llegaron del sistema anterior por carga directa (sin pasar por el callback). Si
  producción es igual, el día que se use `@buscar_predefinidas` el agente no encontraría nada. R1
  tiene que mostrarlo (y el estado tiene que calcularse también para las que nunca tuvieron job).
- **Ya usan el nombre como categoría**: la cuenta 75 escribe `01.VENTAS…`, `02.INSTALACIÓN…`,
  `03.GIROS…` (9 «categorías», 105 predefinidas); la 55 `Folleto…`, `Video…`, `Manual…`; la 170
  `Microsip…`. Esto respalda D3 (sugerir categorías por prefijo), pero el prefijo no basta solo:
  también salen «La», «Cómo», «En», «Error» (primeras palabras, no categorías). La sugerencia
  tiene que pedir confirmación y descartar palabras comunes.
- **Costo de vectorizar** (para D4): una predefinida ≈ 100–300 tokens; las 1 368 de staging ≈ 0.3 M
  tokens ≈ **US$0.01** con `text-embedding-3-small`. El costo no es el problema; el riesgo es el
  límite de llamadas por minuto de OpenAI con cuentas de cientos (386). D4 (una por una + hasta 20
  seleccionadas) se queda; queda abierta, si se quiere, una opción «vectorizar esta categoría» con
  pausa entre llamadas.

---

## 6.2 R1 — estado de vectorización y reintentos ✅ (05/11/2026)

**Qué se hizo.**
- **Migración** `20261106100000` (idempotente): `canned_responses.embedding_status`, `embedding_error`,
  `embedded_at`.
- **`KnowledgeItemSyncJob`**: sin OpenAI → `no_key`; con éxito → `ready` + `embedded_at`; error
  pasajero (sin red, timeout, 429 por límite, 5xx) → `TransientError` con `retry_on` (5 intentos,
  espera creciente) y, al agotarse, `failed`; error permanente (401/403 `invalid_key`, 429
  `insufficient_quota` → `quota`, otro 4xx `http_NNN`) → `failed` con el motivo, sin reintentar.
  **P3 arreglado**: la fuente se busca aunque esté desactivada (ya no intenta crear otra). Los
  artículos usan los mismos reintentos (D5), sin guardar estado.
- **`CannedResponse#embedding_state`**: lo que se muestra se calcula con lo guardado + si tiene vector
  + si la cuenta tiene OpenAI (`ready · pending · missing · no_key · failed · stale`). Las que nunca
  pasaron por el job salen `missing` o `no_key`. Al guardar una queda `pending` hasta que el job
  termina.
- **API**: cada predefinida trae `embedding_state` (2 consultas para toda la lista); `POST
  …/canned_responses/:id/vectorize` y `POST …/canned_responses/vectorize { ids }` (hasta 20, D4).
- **Pantalla** (tabla actual): columna **«Fuente de datos»** (`EmbeddingState.vue`) con el estado en
  palabras, el motivo si falló y **[Vectorizar]** / **[Reintentar]** por fila; aviso arriba con
  cuántas no están en la fuente de datos (sin OpenAI / sin vector / fallidas); mientras alguna se
  vectoriza, la lista se vuelve a leer cada 4 s (tope 15).

**Probado en develop**: las 24 de la cuenta 2 salen «✓ En la fuente de datos».

**Pila de pruebas.** `knowledge_item_sync_job_spec` 6 (no_key, ready, permanente, pasajero hasta
agotar, sin red, fuente desactivada), `canned_response_embedding_state_spec` 2,
`canned_responses_vectorize_spec` 3, `canned_responses_controller_spec` (2 ajustadas: la lista trae
`embedding_state`); 128 en verde (los 4 de `knowledge_base_controller_spec` ya fallaban: 403).
Navegador: `EmbeddingState.spec` 4, `cannedResponses/actions.spec` 3.

**Queda en la tabla** el botón «Generar/Eliminar Entrenamiento» del sistema anterior (servicio
externo `WINTOOK_OPENAI` `setTraining`): R2 decide si se quita.

---

## 7. Riesgos

- **El motor** (R4) es lo delicado: un cambio en `grouped_items` afecta a todos los agentes. Por eso
  categoría **o** prefijo (nunca rompe lo de hoy) y el spec que compara las dos copias.
- **El «/» del editor** carga todas las predefinidas: no se pagina ese uso.
- **Columnas del bot viejo** (`menu`, `opcion`…): no existen en todas las bases; la migración no
  las toca.

---

## 8. Decisiones (todas tomadas el 05/11/2026)

| # | Pregunta | Propuesta |
|---|---|---|
| **D1** ✅ | ¿Una categoría por predefinida o varias (etiquetas)? | **Una** (simple; el motor busca por una) |
| **D2** ✅ | ¿El nombre de la categoría entra al texto vectorizado? | **No** (cambiar categoría no cuesta OpenAI) |
| **D3** ✅ | Predefinidas existentes | **Sugerir** categorías por los prefijos que usan los agentes; la persona acepta |
| **D4** ✅ | Vectorizar varias a la vez | Una por una + seleccionar varias con tope de **20** |
| **D5** ✅ | ¿Mismo arreglo de reintentos para artículos del Centro de Ayuda? | **Sí** (mismo job) |
