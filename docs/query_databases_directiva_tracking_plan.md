# Plan — Directiva `{{consulta:}}` desde el Agente IA de Seguimiento

**Rama:** `feat/query_databases` · **Fecha:** 2026-07-03 · **Estado:** propuesta (sin implementar)

Puente entre el **agente IA de seguimiento** (contact_tracking) y el **Bot Cobrador / ERP**
(query_databases): que una plantilla de seguimiento pueda incrustar el resultado de una
**consulta predefinida** al ERP mediante una directiva, igual que `{{doc:}}` / `{{hoja:}}`.

---

## 1. Objetivo

Hoy el ERP solo se dispara por:
- **Modo A** — cron horario (`ReminderDispatchJob`), independiente del chat.
- **Modo B** — mensaje entrante en un inbox con bot `mode_b_enabled` (`message.rb → ChatResponseJob`),
  independiente de las plantillas de seguimiento.

Falta un tercer disparador: **desde la plantilla del agente de seguimiento**, con control
determinista de qué consulta y con qué parámetros. Ejemplo:

```
Hola {{contact.name}}, tu saldo pendiente es {{consulta:sae/saldo_cliente(rfc=DUVM720209EF7)}}.
```

---

## 2. Estado actual (lo que ya existe y se reutiliza)

```
ExternalDbConnection (SAE, Microsip, Contpaq)      name único por cuenta · erp_type
   └─ has_many ExternalDbQuery                      name único POR conexión · allowlist
                                                    sql_template (:rfc, :dias) · params_schema
                                                    active · ai_enabled · result_format
ErpCollectionBot  → belongs_to connection, opt. query, opt. inbox, mode_b_enabled

ExternalDb::QueryRunner.new(query, params).perform
   → Result(columns, rows, row_count, duration_ms)   solo SELECT · binds tipados · row_limit

KnowledgeBaseResponseService                         (llamado desde tracking, línea 172 del job)
   detect_directive → { mode:, source_name: }        @buscar_predefinidas / {{doc:}} / {{hoja:}} …
   perform → case mode → perform_xxx → send_reply
```

**Reuso clave:** el patrón `detect_directive` + `perform_xxx` + `send_reply` ya está montado
y ya se invoca desde el flujo de seguimiento. Solo hay que **agregar una rama**.

---

## 3. El problema: desambiguación con varios bots/ERPs

`ExternalDbQuery.name` es único **por conexión**, no global. Con SAE + Microsip + Contpaq,
`saldo_cliente` **existe en las tres**. Una directiva pelada `{{consulta:saldo_cliente}}`
es ambigua: hay que decir **contra qué conexión** corre.

```
                       {{consulta:saldo_cliente}}   ← ¿cuál?
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
     SAE.saldo_cliente   Microsip.saldo_cliente  Contpaq.saldo_cliente
```

### Decisión de diseño — resolución HÍBRIDA (recomendada)

```
{{consulta:<conexion>/<nombre>(params)}}     ← prefijo explícito de conexión
{{consulta:<nombre>(params)}}                ← sin prefijo → cae al bot del inbox
```

1. **Con prefijo** (`sae/`, `microsip/`, `contpaq/`): resuelve la `ExternalDbConnection`
   por `erp_type` **o** por `name` (case-insensitive, sin espacios). Gana la explícita.
2. **Sin prefijo**: replica `ChatResponseJob#find_bot(conversation)` — inbox de la
   conversación → `ErpCollectionBot` activo de ese inbox (específico > global) → su conexión.
3. **Ambiguo / sin match / inactivo**: la directiva **no opera**, se loguea y se deja el
   texto sin reemplazar (o se omite el fragmento). Nunca falla la respuesta entera.

> Ventaja del prefijo: una **misma plantilla** puede consultar varios ERPs en un mismo mensaje.
> Ventaja del inbox: plantillas simples de un solo ERP no necesitan escribir el prefijo.

---

## 4. Sintaxis de la directiva

```
{{consulta:nombre}}                         sin parámetros
{{consulta:nombre(valor)}}                  un parámetro posicional → primer param del schema
{{consulta:nombre(rfc=XXX)}}                parámetro nombrado
{{consulta:nombre(rfc=XXX, dias=30)}}       varios nombrados
{{consulta:sae/nombre(rfc=XXX)}}            con prefijo de conexión
```

- Los parámetros se validan contra `params_schema` de la consulta (igual que hoy hace
  `QueryRunner#coerce_params!`): requeridos presentes, tipos coercionados, claves conocidas.
- Los **valores** pueden ser literales o placeholders del contexto de seguimiento ya
  disponibles (p.ej. `rfc={{contact.custom_attributes.rfc}}`), resueltos **antes** de la directiva.

### Regex (en `detect_directive`)

```ruby
%r{\{\{consulta:(?:(?<conn>[a-z0-9_]+)/)?(?<name>[a-z0-9_]+)(?:\((?<args>[^}]*)\))?\}\}}i
```

> ⚠️ Diferencia con `{{doc:}}`/`{{hoja:}}`: pueden aparecer **varias** directivas `{{consulta:}}`
> en un mismo mensaje. Ver §6 (múltiples ocurrencias) — cambia el contrato de `perform`.

---

## 5. Flujo end-to-end

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Plantilla de seguimiento (complementary_prompt / cuerpo del mensaje)       │
│   "Tu saldo es {{consulta:sae/saldo_cliente(rfc={{contact...rfc}})}}"       │
└───────────────┬──────────────────────────────────────────────────────────┘
                │  ContactTrackingResponseAnalyzerJob  (ya llama al service)
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ KnowledgeBaseResponseService                                               │
│   detect_directive → { mode: :erp_query, conn:, name:, args: }             │
│                                                                            │
│   resolve_connection(conn|inbox) ──► ExternalDbConnection                  │
│        │  (prefijo → erp_type/name ; sin prefijo → bot del inbox)          │
│        ▼                                                                    │
│   ExternalDbQuery.active.find_by(connection, name)                         │
│        │  gating: connection.active? && bot activo && (feature?)           │
│        ▼                                                                    │
│   ExternalDb::QueryRunner.new(query, parsed_args).perform                  │
│        │   (SOLO SELECT · binds tipados · row_limit)                       │
│        ▼                                                                    │
│   render_result(query.result_format, Result) ──► texto                     │
│        table   → tabla/lista compacta                                       │
│        summary → 1 valor (p.ej. "$10,234.50")                              │
│        template→ render con {{columna}} (ErpCollectionBot#render_message)  │
└───────────────┬──────────────────────────────────────────────────────────┘
                │  reemplaza la directiva por el texto  → send_reply
                ▼
        Respuesta enviada en la conversación
```

---

## 6. Punto delicado: 1 mensaje puede tener N directivas

Hoy `perform` asume **una** directiva por mensaje (un modo → una respuesta). `{{consulta:}}`
puede aparecer varias veces y **mezclada con texto normal**. Dos opciones:

| Opción | Cómo | Pro | Contra |
|---|---|---|---|
| **A. Interpolación in-place** (recomendada) | Escanear el cuerpo, reemplazar **cada** `{{consulta:...}}` por su resultado, dejar el resto del texto tal cual | Natural para plantillas ("tu saldo es X y tu límite Y"); coexiste con otras directivas | Requiere un paso de render separado del `case mode` actual |
| **B. Modo único** (como `{{doc:}}`) | Solo la primera directiva; genera una respuesta IA con el contexto | Mínimo cambio, reusa `perform` | No permite texto fijo + varias consultas en un mensaje |

> **Recomendación:** Opción A, implementada como un **pre-render** del cuerpo de la plantilla
> ANTES del `case mode` (o como rama propia que hace su propio reemplazo y `send_reply`).
> Así `{{consulta:}}` es *interpolación de datos*, no *modo de búsqueda IA* — encaja mejor
> con su naturaleza determinista.

---

## 7. Renderizado del resultado

Reusar el `result_format` que ya tiene `ExternalDbQuery`:

```
summary   → un solo valor legible.  Ej: fila 1, col 1 → "$10,234.50"
            (para saldos: la consulta ya devuelve 1x1)
table     → lista compacta / tabla.  Ej:
              • Factura A-123 · $4,500 · vence 15/07
              • Factura A-140 · $2,100 · vencida
template  → ErpCollectionBot#render_message(row) con placeholders {{columna}}
            (ya existe el método; extraerlo/compartirlo)
```

- Sin filas → texto configurable ("Sin saldos pendientes ✅") o vacío.
- Truncado por `row_limit` (ya lo aplica el runner).

---

## 8. Seguridad (se hereda, no se relaja)

```
✔ Allowlist       — solo ExternalDbQuery.active nombradas; jamás SQL desde la plantilla
✔ Solo SELECT     — validado en el modelo (sql_is_select_only) y en el runner
✔ Binds tipados   — params → coerce_params! (nunca interpolación de strings)
✔ read_only       — la conexión por defecto es read_only
✔ Gating          — connection.active? · bot activo · (opcional) feature_enabled?('query_databases')
✔ Fail-soft       — directiva inválida → no revienta la respuesta; loguea y sigue
```

Riesgo nuevo a cubrir: que un agente ponga en la plantilla una consulta de **otra cuenta**.
→ Resolver siempre **scoped a `@account`** (`@account.external_db_connections` / `.external_db_queries`).

---

## 9. Modo B / function calling (opcional, fase 2)

Independiente de la directiva determinista. Para que el agente IA de seguimiento **elija**
la consulta por lenguaje natural dentro de una conversación de seguimiento, se expone la tool
`consultar_erp` (ya bocetada en `AiQueryService`), restringida a `queries.ai_enabled`.
No forma parte del MVP de este plan (la directiva `{{consulta:}}` sí).

---

## 10. Cambios de código (mapa)

| Archivo | Cambio |
|---|---|
| `app/services/knowledge_base_response_service.rb` | Rama `:erp_query` en `detect_directive`; `resolve_connection`; `perform_erp_query` / pre-render in-place; `parse_args` |
| `app/services/external_db/query_runner.rb` | Reuso directo (sin cambios, o extraer `render_result`) |
| `app/models/erp_collection_bot.rb` | Extraer/compartir `render_message` para `result_format: template` |
| (opcional) `config/features.yml` | feature `query_databases` para gating por cuenta |
| Docs vault | actualizar `query_databases_pendientes.md` (tildar el pendiente) |

**No** toca: el job de tracking (ya llama al service), migraciones, ni el modelo de datos.

---

## 11. Fases

```
F1  detect_directive + parse (regex, args nombrados/posicionales)         [S]
F2  resolve_connection híbrido (prefijo erp_type/name · fallback inbox)   [M]
F3  perform_erp_query: QueryRunner + render_result (summary/table/templ)  [M]
F4  interpolación in-place de N directivas (Opción A) + fail-soft         [M]
F5  gating + scoping por @account + logging                              [S]
F6  (opcional) tool consultar_erp para Modo B en seguimiento             [L]
```

`[S]`=chico `[M]`=medio `[L]`=grande.

---

## 12. Testeo funcional (borrador)

```
TC1  {{consulta:sae/saldo_cliente(rfc=DUVM720209EF7)}} → "$348.30"
TC2  sin prefijo, inbox con bot SAE → resuelve a SAE
TC3  sin prefijo, inbox sin bot → directiva no opera, resto del texto intacto
TC4  nombre inexistente en la conexión → fail-soft, loguea
TC5  param requerido faltante → fail-soft (no envía SQL roto)
TC6  dos directivas (sae/… y microsip/…) en un mensaje → ambas interpoladas
TC7  result_format=table con N filas → lista compacta truncada a row_limit
TC8  consulta de otra cuenta por id/nombre → NO resuelve (scoping)
TC9  conexión inactiva → no opera
TC10 valor con placeholder {{contact...rfc}} → resuelto antes de la consulta
```

Datos reales disponibles (de `query_databases_pendientes.md`):
SAE `DUVM720209EF7` → saldo $348.30 · Contpaq `DUVM720209EF8` → $10.2M.

---

## 13. Decisiones abiertas (para confirmar antes de codear)

1. **Sintaxis del prefijo:** `sae/nombre` (propuesto) vs `nombre@sae` vs selector aparte.
2. **Fuente de la directiva:** ¿en `complementary_prompt` (como las demás) **y/o** en el
   **cuerpo del mensaje** de la plantilla? (§6 sugiere cuerpo, para interpolar in-place).
3. **Gating:** ¿feature `query_databases` por cuenta, o basta con "existe bot activo"?
4. **Modo B en seguimiento (F6):** ¿entra en v1 o queda para después?
```
