# Buscar productos del ERP desde el Agente IA: directiva `@productos`

Rama: `feat/erp_consulta` (desde `develop`, 21/09/2026). **Solo plan**: nada se programa hasta que el
usuario lo revise.

---

## 1. Qué se pide

1. Una **consulta de productos** en Base de Conocimiento → **Conexión ERP**, que busque en el catálogo del
   ERP del cliente (Contpaq, SAE o Microsip).
2. Una **directiva** para el prompt de los Agentes IA, **`@productos`**, que permita **filtrar**: que el
   agente conteste "¿tienen laptops HP de menos de 15 mil?" con los productos reales del ERP.

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

## 3. La idea

```
 Cliente: "¿tienen laptops HP de menos de 15 mil?"
    │
    ▼
 Agente IA con @productos(linea=COMPUTO)            ← filtro FIJO que puso quien arma el agente
    │
    ▼  1. La IA saca los filtros del mensaje (function calling, sin SQL):
    │       { texto: "laptop hp", precio_max: 15000 }
    │  2. Se suman al filtro fijo de la directiva:  linea = COMPUTO
    ▼
 ProductSearch (por ERP) ── SELECT parametrizado, solo lectura, tope de filas ──► ERP
    │
    ▼  3. Resultados reales:
    │     LAP-HP-240  HP 240 G9 Core i5 · $13,499 · 4 en existencia
    │     LAP-HP-250  HP 250 G10 Core i3 · $11,299 · sin existencia
    ▼
 4. El agente redacta con SUS reglas (tono, etiquetas), citando solo esos datos
    "Tenemos la HP 240 G9 (Core i5) en $13,499, con 4 disponibles…"
```

### 3.1 Dos niveles de filtro

| Nivel | Quién lo pone | Ejemplo | Para qué |
|---|---|---|---|
| **Fijo** (en la directiva) | quien arma el agente | `@productos(linea=COMPUTO, con_existencia)` | que un agente solo ofrezca una parte del catálogo |
| **Del mensaje** | la IA, leyendo al cliente | texto, código, precio mínimo y máximo, solo disponibles | buscar lo que el cliente pidió |

**El fijo siempre gana:** el cliente no puede ampliar lo que el agente tiene permitido. Si pide algo de otra
línea, la búsqueda sale vacía y el agente responde que no lo maneja.

### 3.2 La sintaxis

```
@productos                                   todo el catálogo de la conexión del agente
@productos(sae)                              de una conexión, por tipo de ERP o por nombre
@productos(linea=COMPUTO)                    filtro fijo por línea o clasificación
@productos(sae, linea=COMPUTO, con_existencia, lista=2, max=5)
```

| Filtro fijo | Significado |
|---|---|
| `linea=…` | línea (SAE, Microsip) o clasificación (Contpaq); se pueden varias: `linea=A\|B` |
| `con_existencia` | solo productos con existencia > 0 |
| `lista=N` | qué lista de precios mostrar (por defecto la 1) |
| `max=N` | cuántos productos como máximo (por defecto 5, tope 10) |

- Funciona suelta en el prompt o como fuente de una ruta: `@ruta(catalogo #productos: precios, existencias, qué modelos tienen): @productos(linea=COMPUTO)`.
- Sin prefijo, la conexión es la **única** de la cuenta; si hay varias, el comprobador del Asistente avisa
  que hay que elegir una (como hoy con `{{consulta:}}`).

### 3.3 Los filtros del mensaje (lo que saca la IA)

Una sola llamada con *function calling*, igual que `AiQueryService`:

```json
{ "texto": "laptop hp", "codigo": null, "precio_min": null, "precio_max": 15000,
  "solo_disponibles": false, "orden": "precio_asc" }
```

- La IA **nunca escribe SQL**: solo llena este objeto. El SQL es fijo, por ERP, con parámetros.
- `texto` se busca palabra por palabra en nombre, descripción y código (`LIKE` con los comodines escapados).
- Si el mensaje no pide productos ("gracias", "¿y el envío?"), la IA devuelve `buscar: false` y el agente
  contesta como siempre.

### 3.4 La respuesta

- El modelo redacta con el prompt del agente (sus reglas siguen valiendo) y recibe los productos como
  **información exacta**: código, nombre, precio de la lista elegida, existencia.
- **Regla de fidelidad**, como el modo Datos de Google Sheets: precios y existencias se citan tal cual, y si
  no hay resultados se dice, sin inventar ni "parecidos".
- Se guarda en el historial de la conversación, así "¿y la más barata?" se entiende.

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
 Directivas (KnowledgeBase::Directives) ── detecta @productos(...) ──► modo :product_search
        │
 KnowledgeBaseResponseService#perform_product_search
        │   1. ExternalDb::ProductFilters   (IA → filtros del mensaje, function calling)
        │   2. ExternalDb::ProductSearch    (filtro fijo + del mensaje → SELECT por ERP → filas)
        │   3. redacción con el prompt del agente + regla de fidelidad
        ▼
     send_reply
```

Se reutiliza: `QueryRunner` (solo `SELECT`, binds, tope), los adaptadores, `EngineConfig` (modelo),
`OpenaiChat`, el comprobador del Asistente (`ValidatorService`) y el autocompletado de directivas (`/`).

---

## 6. Riesgos

| Riesgo | Cobertura |
|---|---|
| Inyección SQL | la IA no escribe SQL; filtros como parámetros; comodines de `LIKE` escapados; solo `SELECT` (QueryRunner) |
| El cliente saca productos fuera de lo permitido | el filtro fijo de la directiva siempre gana |
| Precio o existencia inventados | los datos van como información exacta + regla de fidelidad; sin resultados → se dice |
| Catálogos grandes lentos | tope de filas, `LIKE` sobre columnas del producto, `max` ≤ 10 |
| Contpaq no tiene existencia total | decisión 2 |
| ERP caído o lento | falla suave: el agente dice que no pudo consultar y no inventa |

---

## 7. Fases (días hábiles)

| Fase | Entrega | Cómo se verifica | Días |
|---|---|---|---|
| **F0** La consulta | `buscar_productos` en `QueryLibrary` para SAE, Microsip y Contpaq (verificada en vivo) + siembra | spec por ERP; prueba en vivo solo lectura contra las 3 conexiones | 1,5 |
| **F1** La búsqueda | `ProductSearch`: filtros fijos + del mensaje → SQL por ERP, comodines escapados, orden, tope | specs de cada filtro e inyección | 1 |
| **F2** La directiva | `@productos(...)`: sintaxis, conexión, comprobador del Asistente, autocompletado `/`, fuente de ruta | specs de parseo y del comprobador | 1 |
| **F3** El agente | `ProductFilters` (IA → filtros) + modo en el motor + redacción con fidelidad + historial | specs con la IA simulada | 1,5 |
| **F4** La pantalla | `buscar_productos` en Conexión ERP (lista de precios, existencia, solo activos) + prueba en Consola | Vitest + navegador | 1 |
| **F5** Prueba real | agente con `@productos` en "Agents IA Test" contra SAE | conversación de punta a punta | 0,5 |

**Total: 6,5 días hábiles.**

---

## 8. Decisiones para el usuario

1. **El nombre:** `@productos` (en el pedido decía `@produtos`). ¿Así?
2. **Existencia en Contpaq:** no hay un total; hay entradas y salidas por periodo. Propuesta: calcularla del
   ejercicio actual (entradas − salidas), **o** en Contpaq no mostrar existencia en esta versión.
3. **Lista de precios por defecto:** la 1. ¿Con o sin IVA? (Contpaq/SAE guardan el precio sin impuesto.)
4. **Productos sin existencia:** propuesta: se muestran con "sin existencia" salvo que la directiva diga
   `con_existencia`.
5. **Cuántos productos por respuesta:** propuesta 5 (tope 10), para no saturar un WhatsApp.
6. **Imágenes del producto** (Contpaq `CIDFOTOPRODUCTO`, SAE `CVE_IMAGEN`): fuera de esta versión.
