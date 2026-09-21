# Buscar productos del ERP desde el Agente IA: `{{consulta:}}` con parámetros `?`

Rama: `feat/erp_consulta` (desde `develop`, 21/09/2026). **Solo plan**: nada se programa hasta que el
usuario lo revise.

---

## 1. Qué se pide

1. Una **consulta de productos** en Base de Conocimiento → **Conexión ERP**, que busque en el catálogo del
   ERP del cliente (Contpaq, SAE o Microsip).
2. Usarla desde el prompt de los Agentes IA **permitiendo filtrar**: que el agente conteste "¿tienen
   laptops HP de menos de 15 mil?" con los productos reales del ERP.

**Decisión (usuario, 21/09/2026):** no se crea una directiva nueva: se **extiende `{{consulta:}}`** (la de
`@query_databases`) con parámetros **`?`**, que llena la IA con lo que escribió el cliente. La primera
versión del plan proponía `@productos`; queda solo como atajo opcional (§3.5).

---

## 2. Lo que hay hoy (medido en `develop` y en las bases, solo lectura)

**En el código** (módulo `@query_databases`):

| Pieza | Qué hace |
|---|---|
| `ExternalDb::QueryLibrary` | consultas predefinidas por ERP, con esquemas verificados en vivo. **Todas de cobranza** (saldo, facturas vencidas, pagos, límite, recordatorio). **No hay de productos.** |
| `QueryRunner` + adaptadores | solo `SELECT`, parámetros con bind seguro (Firebird) o literal tipado escapado (SQL Server), tope de filas |
| `{{consulta:nombre(param=…)}}` | directiva **determinista**: reemplaza el texto por el resultado de una consulta; los parámetros los escribe quien arma el prompt |
| `AiQueryService` (Modo B) | la IA elige una consulta `ai_enabled` y llena sus parámetros por *function calling*; **nunca ve ni escribe SQL**. Lo usa el Bot de Cobranza |

Falta: una consulta de productos, y una directiva cuyos **filtros salgan de lo que escribe el cliente**
(`{{consulta:}}` no sirve: sus parámetros son fijos en el prompt).

**En las bases de la cuenta 2** (conexiones que ya existen):

| ERP | Productos | Tablas | Precio | Existencia |
|---|---|---|---|---|
| **SAE** (#13, Firebird) | 178 | `INVE01` (CVE_ART, DESCR, LIN_PROD, UNI_MED, STATUS…) | `PRECIO_X_PROD01` (CVE_ART, CVE_PRECIO, PRECIO) + `PRECIOS01` (listas) | `INVE01.EXIST` (total) y `MULT01` (por almacén) |
| **Microsip** (#14, Firebird) | 181 | `ARTICULOS` (NOMBRE, ESTATUS, LINEA_ARTICULO_ID…) + `CLAVES_ARTICULOS` (clave) + `LINEAS_ARTICULOS` | `PRECIOS_ARTICULOS` (por `PRECIO_EMPRESA_ID`) | `SALDOS_IN` (por almacén y periodo) |
| **Contpaq Comercial** (#12, SQL Server) | 97 | `admProductos` (CCODIGOPRODUCTO, CNOMBREPRODUCTO, CDESCRIPCIONPRODUCTO, CSTATUSPRODUCTO, clasificaciones…) | `CPRECIO1`…`CPRECIO10` en el mismo producto | `admExistenciaCosto`: **entradas y salidas por periodo y ejercicio**, no un total (decisión 2) |

---

## 3. La idea: `{{consulta:}}` con parámetros `?`

### 3.1 Hoy vs. con `?`

```
 HOY (sin cambios)                               CON "?"
 ─────────────────                               ───────
 {{consulta:sae/saldo_cliente}}                  {{consulta:sae/buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}}
   · parámetros fijos en el prompt                 · los "?" los llena la IA con el mensaje del cliente
     (el RFC sale del contacto: erp_rfc)            · los valores fijos siempre ganan
   · sin IA: el prompt, con el resultado           · el agente REDACTA con sus reglas, citando los
     insertado, ES la respuesta                      datos tal cual
```

**Compatibilidad:** una `{{consulta:}}` **sin ningún `?`** se comporta exactamente como hoy. La cobranza no
cambia.

### 3.2 El recorrido con `?`

```
 Cliente: "¿tienen laptops HP de menos de 15 mil?"
    │
    ▼
 Agente:  {{consulta:sae/buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}}
    │
    ▼  1. La IA llena SOLO los "?" (function calling con los parámetros de la consulta; sin SQL):
    │       { texto: "laptop hp", precio_max: 15000 }
    │  2. Se suman los fijos:  linea = COMPUTO
    ▼
 QueryRunner ── SELECT de la consulta, parámetros con bind, solo lectura, tope de filas ──► ERP (SAE)
    │
    ▼  3. Filas reales:
    │     LAP-HP-240  HP 240 G9 Core i5 · $13,499 · 4 en existencia
    │     LAP-HP-250  HP 250 G10 Core i3 · $11,299 · sin existencia
    ▼
 4. El agente redacta con SUS reglas (tono, etiquetas) y la regla de fidelidad
    "Tenemos la HP 240 G9 (Core i5) en $13,499, con 4 disponibles…"
```

- Si el mensaje no pide nada que la consulta pueda responder ("gracias", "¿y el envío?"), la IA devuelve
  `usar: false` y el agente contesta como siempre.
- Si faltan datos que el cliente no dio (un `?` obligatorio sin valor), el agente **pregunta** en vez de
  consultar a ciegas.

### 3.3 La sintaxis

```
{{consulta:nombre(param=valor, otro=?)}}
             │          │         └── "?" = lo llena la IA desde el mensaje del cliente
             │          └──────────── valor fijo = lo pone quien arma el agente (siempre gana)
             └─────────────────────── nombre de la consulta (en Conexión ERP)
{{consulta:sae/nombre(…)}}             con prefijo de conexión (tipo de ERP o nombre), como hoy
```

Para productos, con la consulta nueva `buscar_productos`:

| Parámetro | Fijo (ejemplo) | Con `?` |
|---|---|---|
| `texto` | — | palabras del cliente: nombre, descripción o código |
| `codigo` | — | un código exacto si lo da |
| `linea` | `linea=COMPUTO` (varias: `A\|B`) | — (normalmente fijo) |
| `precio_min`, `precio_max` | `precio_max=50000` | lo que diga el cliente |
| `con_existencia` | `con_existencia=si` | "¿cuáles tienen disponibles?" |
| `lista` | `lista=2` (por defecto 1) | — |
| `max` | `max=5` (tope 10) | — |

- Funciona suelta en el prompt o como **fuente de una ruta**:
  `@ruta(catalogo #productos: precios, modelos, existencias): {{consulta:buscar_productos(texto=?, precio_max=?)}}`

### 3.4 La respuesta

- El modelo recibe el prompt del agente (sin las directivas) + los resultados como **información exacta**
  (código, nombre, precio de la lista elegida, existencia) + la **regla de fidelidad** del modo Datos de
  Google Sheets: precios y existencias tal cual; sin resultados, se dice; nada de "parecidos" inventados.
- Se guarda en el historial, así "¿y la más barata?" se entiende en el siguiente mensaje.

### 3.5 Atajo opcional `@productos(…)`

Si se quiere algo más fácil de escribir, `@productos(linea=COMPUTO)` puede ser un **alias** de
`{{consulta:buscar_productos(linea=COMPUTO, texto=?, codigo=?, precio_min=?, precio_max=?, con_existencia=?)}}`.
Decisión 1.

### 3.6 Encontrado al revisar el motor: `{{consulta:}}` como fuente de una ruta

`KnowledgeBaseResponseService#perform_erp_query` arma la respuesta con **todo** el `complementary_prompt`
del agente, no con la fuente de la ruta elegida. En un agente con rutas, la respuesta sería el Entrenamiento
completo (con sus `@ruta`). Se corrige en la F2: con rutas, se usa la directiva de la ruta del turno.

---

## 4. En Conexión ERP (la pantalla)

La consulta aparece como una más de cada conexión, **"buscar_productos"**, sembrada por el `QuerySeeder`
según el tipo de ERP:

```
Conexión ERP › SAE Servicios › Consultas
  saldo_cliente · facturas_vencidas · pagos_periodo · sobre_limite · recordatorio_vencidas
  ▸ buscar_productos   (nueva)   [Probar]
        Lista de precios:  [ 1 · Público ▾ ]
        Existencia:        [ total ▾ ]   (SAE: total o un almacén)
        Solo activos:      [✓]
```

- Se puede **probar en la Consola ERP**: escribir "laptop hp" y ver qué devolvería.
- El SQL se ve pero no hace falta tocarlo: la búsqueda arma los filtros alrededor.

---

## 5. Dónde vive

```
 KnowledgeBase::Directives ── {{consulta:…}} ──► modo :erp_query (como hoy)
        │
 KnowledgeBaseResponseService#perform_erp_query
        ├── sin "?"  → ConsultaDirectiveRenderer (como hoy: determinista, sin IA)
        └── con "?"  → ExternalDb::AskedParams   (IA → valores de los "?", function calling)
                       QueryRunner               (fijos + de la IA → SELECT → filas)
                       redacción con el prompt del agente + regla de fidelidad + historial
```

Se reutiliza: `ConsultaDirectiveRenderer` (sintaxis, conexión, RFC del contacto), `QueryRunner` (solo
`SELECT`, binds, tope), los adaptadores, el *function calling* de `AiQueryService`, `EngineConfig` (modelo),
el comprobador del Asistente (`ValidatorService`) y el autocompletado de directivas (`/`).

---

## 6. Riesgos

| Riesgo | Cobertura |
|---|---|
| Inyección SQL | la IA no escribe SQL; filtros como parámetros; comodines de `LIKE` escapados; solo `SELECT` (QueryRunner) |
| El cliente saca productos fuera de lo permitido | los valores fijos siempre ganan; la IA solo llena los `?` |
| Romper la cobranza que ya usa `{{consulta:}}` | sin `?` el camino es el de hoy, sin tocar; spec de regresión |
| Precio o existencia inventados | los datos van como información exacta + regla de fidelidad; sin resultados → se dice |
| Catálogos grandes lentos | tope de filas, `LIKE` sobre columnas del producto, `max` ≤ 10 |
| Contpaq no tiene existencia total | decisión 2 |
| ERP caído o lento | falla suave: el agente dice que no pudo consultar y no inventa |

---

## 7. Fases (días hábiles)

| Fase | Entrega | Cómo se verifica | Días |
|---|---|---|---|
| **F0** ✅ La consulta | `buscar_productos` en `QueryLibrary` para SAE, Microsip y Contpaq (verificada en vivo, solo lectura) + siembra; filtros opcionales (texto por palabras con comodines escapados, línea, precios, existencia, lista, max) | spec por ERP; prueba contra las 3 conexiones | 1,5 |
| **F1** ✅ El `?` en la sintaxis | `ConsultaDirectiveRenderer` reconoce `param=?`; sin `?` todo igual | specs de parseo + regresión de cobranza | 0,5 |
| **F2** ✅ El agente | `AskedParams` (IA llena los `?`), consulta, redacción con fidelidad e historial; `{{consulta:}}` de ruta usa la directiva de la ruta (§3.6) | specs con la IA simulada; regresión de cobranza | 1,5 |
| **F3** Comprobador y autocompletado | el Asistente valida `{{consulta:…(…=?)}}` (consulta existe, parámetros válidos, conexión) y la ofrece en `/` | specs del comprobador; Vitest | 1 |
| **F4** La pantalla | `buscar_productos` en Conexión ERP (lista de precios, existencia, solo activos) + probar en Consola ERP | Vitest + navegador | 1 |
| **F5** Prueba real | agente con `{{consulta:buscar_productos(texto=?, precio_max=?)}}` en "Agents IA Test" contra SAE | conversación de punta a punta | 0,5 |

**Total: 6 días hábiles.**

### 7.1 F0 hecha (21/09/2026): lo que apareció al probar en vivo (solo lectura)

| Hallazgo | Arreglo |
|---|---|
| La gem `fb` **no puede mandar un parámetro NULL** a un `CAST(? AS …)` ("specified column is not permitted to be null"); los filtros opcionales son justo `(CAST(? AS …) IS NULL OR …)` | `QueryRunner`: un parámetro vacío se escribe `NULL` en el SQL en vez de mandarse como `?` (seguro: `NULL` es una palabra fija) |
| Firebird deduce el tipo de cada `?` por la columna con que se compara (NOT NULL → el `?` tampoco admite NULL) | en Firebird **cada** uso de un parámetro lleva `CAST` |
| Con `charset NONE`, Firebird entrega los textos en la página de Windows ("p\\xFAblico", "ca\\xF1\\xF3n") | el adaptador los convierte a UTF-8 y manda los parámetros en Windows-1252 (así "cañón" encuentra "cañón"). **Arregla también los nombres con tilde de las consultas de cobranza.** |
| Productos sin nombre (basura de captura) | no salen |

Resultados en vivo: SAE 50 productos (todo) · "toshiba" 1 · existencia y ≤ $1,000: 19. Microsip "cañón" 1 · línea
Armas lista 2: 6 · con existencia 46. Contpaq "mouse" 5 · con existencia 29. Un intento de inyección
(`x' OR 1=1 --`) devuelve 0 filas en SAE y Contpaq.

### 7.2 F2 hecha (21/09/2026)

`ExternalDb::AskedParams` (la IA llena solo los `?`, modelo del inbox con piso `:router`, JSON) +
`ExternalDb::AskedConsulta` (fijos ganan, posicional y RFC del contacto, `max` 5 / tope 10) + el motor
(`perform_erp_asked`: redacta con los datos exactos, regla de fidelidad, historial; §3.6 arreglado: con rutas
se usa la directiva de la ruta). La sintaxis `{{consulta:…}}` ya no llega al modelo (`Directives.strip_tokens`).

Probado con la IA y las bases reales (sin escribir nada): "¿tienen aire acondicionado toshiba?" → texto;
"cascos de menos de 500 que tengan disponibles" → texto + precio_max + con_existencia; "gracias" → no consulta.
Dos arreglos de búsqueda que salieron de ahí:

| Caso real | Arreglo |
|---|---|
| "cascos" no encontraba "Casco de Baseball" | cada palabra va a su singular (la búsqueda es "contiene": la raíz encuentra ambos) |
| el catálogo dice "AIERE ACONDICIONADO TOSHIBA": con todas las palabras, nada | si no hay nada, se busca por palabra y se ordena por la palabra más específica (1 / cuántos la tienen); al modelo se le avisa "COINCIDENCIA PARCIAL" para que lo presente como "podría interesarle" |

La consulta **no se agrega sola** a las conexiones existentes: se agrega con el botón **"Sembrar consultas"**
de cada conexión (agrega las que faltan por nombre). Aparte: a Microsip le falta `facturas_vencidas` porque la
librería nunca la tuvo para Microsip (pendiente fuera de esta rama).

---

## 8. Decisiones para el usuario

1. **¿Atajo `@productos(…)`?** (§3.5). Propuesta: sí, como alias; la forma completa `{{consulta:…=?}}` sigue
   sirviendo para cualquier consulta.
2. **Existencia en Contpaq:** no hay un total; hay entradas y salidas por periodo. Propuesta: calcularla del
   ejercicio actual (entradas − salidas), **o** en Contpaq no mostrar existencia en esta versión.
3. **Lista de precios por defecto:** la 1. ¿Con o sin IVA? (Contpaq/SAE guardan el precio sin impuesto.)
4. **Productos sin existencia:** propuesta: se muestran con "sin existencia", salvo `con_existencia=si`.
5. **Cuántos productos por respuesta:** propuesta 5 (tope 10), para no saturar un WhatsApp.
6. **Imágenes del producto** (Contpaq `CIDFOTOPRODUCTO`, SAE `CVE_IMAGEN`): fuera de esta versión.
