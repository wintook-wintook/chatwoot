# Plan — Consultar BDs externas + Bot Cobrador de Facturas

> **Estado:** PLAN (solo revisión, sin implementar). Rama `feat/query_databases`.
> **Objetivo de negocio:** que un agente/bot de Chatwoot consulte las BDs de los
> ERPs del cliente (Aspel SAE, Microsip, CONTPAQi) y conteste en la conversación.
> **Primer caso concreto:** un **bot cobrador** que responde saldos, facturas
> vencidas y cuentas por cobrar (CXC).

---

## 1. Alcance

### En alcance (v1)
- **Conexión a BD externa por cuenta**, motores **Firebird** (SAE, Microsip,
  Contpaq-Firebird) y **SQL Server** (Contpaq-`sqlData`).
- **Consultas predefinidas parametrizadas** (allowlist; NUNCA SQL arbitrario en runtime).
- **Dos disparadores** que reusan la infraestructura actual:
  1. **Directiva `{{consulta:nombre(param)}}`** en plantillas de seguimiento
     (igual que `{{doc:}}`/`{{hoja:}}`).
  2. **Herramienta del agente IA** (function calling): la IA elige la consulta
     nombrada y rellena el parámetro según el mensaje del cliente.
- **Bot Cobrador** como vertical concreta sobre lo anterior.

### Fuera de alcance (v1, futuro)
- SQL libre / editor de consultas en runtime.
- Escritura en el ERP (todo es **solo-lectura**).
- Firebase (Google) — distinto a Firebird; si algún cliente lo usa, se suma aparte.
- Agente local/túnel — asumimos BD **alcanzable por red** (el cliente da host+puerto+user+pass).

---

## 2. Realidad de las conexiones (de tus ejemplos)

```
SAE (Firebird)        host dragon.serverdb.com : 3050   user sysdba
  └ varias .fdb por empresa:  BDZSERVICIOS100.fdb (Zeus) · SERVICIOS1000.fdb
    (catálogos) · SAE7SERVICIOS.FDB (datos SAE)

Microsip (Firebird)   host dragon.serverdb.com : 3050   user sysdba
  └ C:\Microsip datos\...\BDZSERVICIOS7867676.fdb

Contpaq (adPanchitos) DOBLE motor:
  ├ Firebird  : 3050  BASE_PRINCIPAL_001.FDB  (sysdba)
  └ SQL Server: 6072  db adPanchitos  user sa  (encrypt:false)
```

**Implicaciones de diseño:**
- Firebird se conecta con cadena `host/puerto:/ruta/al/archivo.fdb`. **La ruta es un
  archivo en el server del ERP**, no un nombre lógico → el modelo guarda `database_path`.
- **Una empresa = varias .fdb.** El modelo permite **varias bases por conexión** (o
  varias conexiones), y cada consulta nombrada apunta a una base concreta.
- SQL Server usa `server:puerto` + `database` lógico + opción `encrypt`.
- ⚠️ Los ejemplos traen credenciales por defecto (`sysdba/masterkey`, `sa/...`).
  Recomendación firme: **usuario read-only dedicado** por cliente.

---

## 3. Arquitectura

```
                         CHATWOOT (nube)
┌───────────────────────────────────────────────────────────────────────┐
│  Conversación / Plantilla de seguimiento                               │
│        │                                                               │
│        │  (A) directiva {{consulta:facturas_vencidas(RFC)}}            │
│        │  (B) la IA decide → tool call query_erp(name, params)         │
│        ▼                                                               │
│  ┌──────────────────────────┐      ┌──────────────────────────────┐   │
│  │ ExternalDbResponseService│◄────►│  Bot Cobrador (orquestador)  │   │
│  │  - detecta disparador    │      │  - identifica cliente (RFC)  │   │
│  │  - resuelve consulta+args│      │  - arma respuesta cobranza   │   │
│  └────────────┬─────────────┘      └──────────────────────────────┘   │
│               ▼                                                        │
│  ┌──────────────────────────┐   allowlist + params tipados            │
│  │  ExternalDbQuery (modelo) │   (sin SQL arbitrario)                  │
│  └────────────┬─────────────┘                                          │
│               ▼                                                        │
│  ┌──────────────────────────┐   pool, timeout, LIMIT, read-only       │
│  │  Adaptador por motor      │                                         │
│  │   ├ FirebirdAdapter (fb)  │                                         │
│  │   └ MssqlAdapter(tiny_tds)│                                         │
│  └────────────┬─────────────┘                                          │
└───────────────┼────────────────────────────────────────────────────── ┘
                │ TCP 3050 / 6072  (requiere egress a dragon.serverdb.com)
                ▼
        ERP del cliente (SAE/Microsip/Contpaq .fdb / SQL Server)
```

---

## 4. Modelo de datos (migraciones al final, como siempre)

```
external_db_connections                external_db_queries
─────────────────────────              ─────────────────────────────────────
account_id            FK               account_id              FK
name        "Servicios SAE"            connection_id           FK
engine      firebird|mssql             name        "facturas_vencidas"
host        dragon.serverdb.com        description "Facturas vencidas de un cliente"
port        3050                       sql_template  SELECT ... WHERE rfc = :rfc ...
database_path/database                 params_schema jsonb  [{key,label,type,required}]
username                               row_limit     int (default 200)
password_encrypted (encrypts)          ai_enabled    bool   (expuesta como tool IA)
options jsonb {encrypt:false}          directive_key "facturas_vencidas"
read_only   bool default true          result_format table|summary|template
active      bool                       active        bool
```

- `password` cifrado con `encrypts` (Active Record Encryption, ya usado en el repo).
- `params_schema` describe los parámetros tipados (ej. `rfc`, `codigo_cliente`,
  `dias`) → permite **bind params** (anti-inyección) y que la IA sepa qué rellenar.
- `sql_template` usa **placeholders nombrados** (`:rfc`) que el adaptador convierte a
  parámetros del driver — nunca interpolación de strings.

---

## 5. Capa de ejecución (servicios)

```
ExternalDb::ConnectionAdapter (base)
 ├─ FirebirdAdapter   gem `fb`        cadena "host/port:/ruta.fdb"
 └─ MssqlAdapter      gem `tiny_tds`  host/port/database/encrypt

ExternalDb::QueryRunner
 - valida params contra params_schema (tipos, requeridos)
 - exige SELECT (rechaza INSERT/UPDATE/DELETE/DDL aunque la conexión sea read-only)
 - aplica LIMIT/row_limit y statement timeout
 - ejecuta con bind params → filas (array de hashes)
 - normaliza fechas/decimales (cobranza: importes y vencimientos)

ExternalDb::ResultFormatter
 - table   → tabla compacta para el chat
 - summary → la IA redacta lenguaje natural a partir de las filas
 - template→ formato fijo (ej. recordatorio de pago)
```

**Gems nuevas:** `fb` (Firebird) y `tiny_tds` (SQL Server) — NO están en el Gemfile.
`tiny_tds` necesita FreeTDS en la imagen; `fb` necesita la client lib de Firebird.
(Dependencia de sistema → nota para el Dockerfile.)

> ⚠️ **Hallazgo verificado en vivo (Contpaq):** el SQL Server del cliente es
> **SQL Server 2008 R2** → solo habla **TDS 7.0**. `tiny_tds` 3.x **rechaza** TDS
> < 7.3 ("connecting with a TDS version older than 7.3!"). El adaptador deberá
> **permitir el downgrade** (build/flag de tiny_tds que lo habilite) o conectar vía
> **FreeTDS/ODBC**. Confirmado: con `TDSVER=7.0` la conexión y los `SELECT` funcionan.
> Egress OK a `dragon856.startdedicated.com:6072` (MSSQL) y `:3050` (Firebird).

---

## 6. Integración con los disparadores existentes

**Reuso directo del patrón `KnowledgeBaseResponseService#detect_directive`:**

```
detect_directive  (regex, igual que {{doc:}}/{{hoja:}})
  {{consulta:nombre}}              → sin parámetro
  {{consulta:nombre(valor)}}       → un parámetro posicional
  {{consulta:nombre(rfc=XXX)}}     → parámetro nombrado
```

**Herramienta IA (function calling)** — se expone una sola tool genérica:

```jsonc
{ "name": "consultar_erp",
  "description": "Consulta saldos / facturas / cobranza en el ERP del cliente",
  "parameters": { "consulta": "facturas_vencidas|saldo_cliente|cxc|antiguedad_saldos",
                  "rfc": "RFC o código del cliente", "dias": "opcional" } }
```
Solo se ofrecen a la IA las consultas con `ai_enabled = true`. La IA elige `consulta`
+ params; Ruby ejecuta la consulta nombrada real (la IA nunca ve ni escribe SQL).

---

## 7. Dos modos de operación (IMPORTANTE)

El "bot cobrador" es **proactivo y programado**, NO un chatbot con IA. Conviene
separar claramente:

```
MODO A — RECORDATORIO PROACTIVO  (caso principal · sin IA · sin function calling)
  CaseDb::ReminderJob  (Sidekiq cron, ej. diario 8:00)
    para cada conexión/bot activo:
      → ejecuta consulta predefinida "facturas por vencer / vencidas"
      → agrupa por cliente con saldo
      → dispara recordatorio por el canal (plantilla de seguimiento existente)
  "¿Cuándo verifica?" = el horario programado (campo schedule del bot).
  El "agente" aquí = JOB en segundo plano, no un LLM.

MODO B — CONSULTA REACTIVA  (secundario · IA + function calling)
  Cliente escribe "¿cuánto debo?"
    → agente IA expone tool consultar_erp(consulta, params)
    → elige consulta nombrada + rellena RFC (NUNCA ve ni escribe SQL)
    → QueryRunner ejecuta el SQL predefinido → respuesta
```

**Decisión v1:** se entregan **ambos modos**, pero **Modo B con interruptor on/off
por bot** (default OFF). Así el recordatorio (A) es el núcleo y el chat-IA (B) se
activa cuando se quiera, sin re-desplegar. La **consola** (uso del agente) va siempre.

### Flujo del Bot Cobrador (Modo A)
```
1. Job programado dispara la verificación (diario/semanal)
2. Consulta "facturas_por_vencer(dias)" + "facturas_vencidas" sobre la conexión
3. Identificar contacto Chatwoot ↔ cliente ERP:
     - match por **teléfono o email** del contacto contra el cliente del ERP
     - si no hay RFC en el contacto, el bot **sugiere agregar el RFC** a
       `custom_attributes` (referencia más confiable que tel/email)
4. ReminderFormatter arma el recordatorio (plantilla)
5. Envía por el canal; registra el envío (evitar duplicar el mismo día)
6. (futuro) adjuntar estado de cuenta PDF / link de pago
```

## 8. Librería de consultas por ERP (predefinida, reutilizable)

**Confirmado por investigación: cada ERP tiene esquema conocido.** Se define el SQL
**una vez por sistema** (perfil), no por cliente. Nombres de tabla/columna a afinar
contra la BD real (no hay egress desde este entorno).

```
-- Aspel SAE (Firebird) — ✅ ESQUEMA VERIFICADO EN VIVO (Empresa01, SAE70EMPRE01)
--   tablas con sufijo de empresa (…01). Cliente: CLIE01. Facturas: FACTF01.
--   CLIE01:  CLAVE_CLIENTE, CLIENTE_ID, NOMBRE, RFC, SALDO (saldo global), STATUS
--   FACTF01: TIP_DOC, CVE_DOC, CVE_CLPV(=clave cliente), STATUS, FECHA_DOC, FECHA_VEN,
--            FECHA_CANCELA, IMPORTE, ACT_CXC('S'/'N'), SERIE, FOLIO, RFC
--   ⚠️ flags booleanos son CHAR 'S'/'N' (no 0/1). NO hay saldo por documento:
--      el saldo global del cliente está en CLIE01.SALDO.
saldo_cliente:      SELECT SALDO FROM CLIE01 WHERE RFC = :rfc        -- o CLAVE_CLIENTE = :cve
facturas_vencidas:  SELECT SERIE, FOLIO, FECHA_DOC, FECHA_VEN, IMPORTE,
                           (CURRENT_DATE - FECHA_VEN) AS dias_vencidos
                    FROM FACTF01
                    WHERE RFC = :rfc AND ACT_CXC = 'S'
                      AND FECHA_CANCELA IS NULL AND FECHA_VEN < CURRENT_DATE
                    ORDER BY FECHA_VEN

-- Microsip (Firebird) — ✅ ESQUEMA VERIFICADO EN VIVO (SERVICIOS.FDB) · el más normalizado
--   CLIENTES(CLIENTE_ID, NOMBRE)  · RFC en DIRS_CLIENTES.RFC_CURP (¡no en CLIENTES!)
--   SALDOS_CC(CLIENTE_ID, ANO, MES, CARGOS_CXC, CREDITOS_CXC) = saldo periódico
--   DOCTOS_CC(DOCTO_CC_ID, CLIENTE_ID, FOLIO, FECHA, NATURALEZA_CONCEPTO, CANCELADO 'S'/'N')
--   VENCIMIENTOS_CARGOS_CC(DOCTO_CC_ID, FECHA_VENCIMIENTO) · importe pend.→ IMPORTES_DOCTOS_PEND_CC
--   ⚠️ flags 'S'/'N'; saldo vivo = cargos − créditos (modelo de pendientes normalizado)
saldo_cliente:      SELECT SUM(s.CARGOS_CXC - s.CREDITOS_CXC) AS saldo     -- ✅ validado ($825k)
                    FROM SALDOS_CC s
                    JOIN DIRS_CLIENTES d ON d.CLIENTE_ID = s.CLIENTE_ID
                    WHERE d.RFC_CURP = :rfc
cargos_vencidos:    SELECT dc.FOLIO, dc.FECHA, v.FECHA_VENCIMIENTO
                    FROM DOCTOS_CC dc
                    JOIN VENCIMIENTOS_CARGOS_CC v ON v.DOCTO_CC_ID = dc.DOCTO_CC_ID
                    JOIN DIRS_CLIENTES d ON d.CLIENTE_ID = dc.CLIENTE_ID
                    WHERE d.RFC_CURP = :rfc AND dc.CANCELADO = 'N'
                      AND v.FECHA_VENCIMIENTO < CURRENT_DATE
                    -- ⚠️ importe pendiente vía IMPORTES_DOCTOS_PEND_CC; afinar con
                    --    empresa que use el modelo de pendientes (demo tenía 0 docs pend.)

-- CONTPAQi Comercial (SQL Server) — ✅ ESQUEMA VERIFICADO EN VIVO (adPanchitos_Corp)
--   admDocumentos: CIDDOCUMENTO, CIDCLIENTEPROVEEDOR, CSERIEDOCUMENTO, CFOLIO,
--     CFECHA, CFECHAVENCIMIENTO, CTOTAL, CPENDIENTE(=saldo), CCANCELADO, CRFC, CRAZONSOCIAL
--   admClientes: CIDCLIENTEPROVEEDOR, CCODIGOCLIENTE, CRAZONSOCIAL, CRFC
facturas_vencidas:  SELECT CSERIEDOCUMENTO + CAST(CFOLIO AS varchar) AS folio,
                           CFECHA, CFECHAVENCIMIENTO, CTOTAL, CPENDIENTE AS saldo,
                           DATEDIFF(day, CFECHAVENCIMIENTO, GETDATE()) AS dias_vencidos
                    FROM admDocumentos
                    WHERE CRFC = :rfc AND CPENDIENTE > 0 AND CCANCELADO = 0
                      AND CFECHAVENCIMIENTO < GETDATE()
                    ORDER BY CFECHAVENCIMIENTO
```

> Fuentes de esquema: **Contpaq verificado en vivo** (conexión real, solo lectura);
> Factor BI (hoja pública Microsip) y doc "Tablas Aspel SAE" para los otros dos.

### Pagos / cobranza — ✅ VERIFICADO EN VIVO en los 3 ERPs
```
-- Contpaq: aplicación cargo↔abono (admAsocCargosAbonos) — "cuánto se cobró"
pagos_periodo:  SELECT SUM(CIMPORTEABONO) AS cobrado
                FROM admAsocCargosAbonos
                WHERE CFECHAABONOCARGO >= :desde AND CFECHAABONOCARGO < :hasta
                -- docs de cobro = admDocumentos.CIDCONCEPTODOCUMENTO IN (10,11,13)
                --   (Pago del cliente / Cheque recibido / Abono del Cliente)

-- SAE: pagos = documentos familia "P" (FACTP01), mismo esquema que FACTF01
pagos_periodo:  SELECT EXTRACT(YEAR FROM FECHA_DOC) AS anio, EXTRACT(MONTH FROM FECHA_DOC) AS mes,
                       SUM(IMPORTE) AS cobrado
                FROM FACTP01 WHERE FECHA_CANCELA IS NULL
                  AND FECHA_DOC >= :desde AND FECHA_DOC < :hasta
                GROUP BY 1,2                       -- por cliente: + WHERE CVE_CLPV=:cve / RFC=:rfc

-- Microsip: cobros = DOCTOS_CC naturaleza 'R' (concepto "Cobro") + IMPORTES_DOCTOS_CC
pagos_periodo:  SELECT SUM(i.IMPORTE) AS cobrado
                FROM DOCTOS_CC d JOIN IMPORTES_DOCTOS_CC i ON i.DOCTO_CC_ID = d.DOCTO_CC_ID
                WHERE d.NATURALEZA_CONCEPTO = 'R' AND d.CANCELADO = 'N'
                  AND d.FECHA >= :desde AND d.FECHA < :hasta
                -- naturaleza 'C'=cargos (Venta/Nota cargo), 'R'=abonos (Cobro/Nota crédito/Devolución)
                -- estricto "cobro" = filtrar CONCEPTO_CC_ID de "Cobro"/"Cobro en mostrador"
```
> Nota: en Contpaq y SAE el pago es **un documento**; en Microsip es un **renglón** de
> importe ligado a un docto de naturaleza 'R'. "Último pago del cliente" = el de mayor
> fecha con esos mismos filtros + cliente.

### Límite de crédito — ✅ VERIFICADO EN VIVO en los 3 ERPs
```
-- Contpaq: admClientes.CLIMITECREDITOCLIENTE (+ CDIASCREDITOCLIENTE, CBANEXCEDERCREDITO)
sobre_limite:   SELECT cl.CIDCLIENTEPROVEEDOR, cl.CLIMITECREDITOCLIENTE, SUM(d.CPENDIENTE) AS saldo
                FROM admClientes cl JOIN admDocumentos d ON d.CIDCLIENTEPROVEEDOR = cl.CIDCLIENTEPROVEEDOR
                WHERE cl.CLIMITECREDITOCLIENTE > 0 AND d.CCANCELADO = 0
                GROUP BY cl.CIDCLIENTEPROVEEDOR, cl.CLIMITECREDITOCLIENTE
                HAVING SUM(d.CPENDIENTE) > cl.CLIMITECREDITOCLIENTE

-- SAE: límite y saldo en la MISMA tabla CLIE01 (LIMCRED, DIASCRED, CON_CREDITO 'S'/'N')
sobre_limite:   SELECT CLAVE_CLIENTE, NOMBRE, LIMCRED, SALDO
                FROM CLIE01 WHERE LIMCRED > 0 AND SALDO > LIMCRED

-- Microsip: límite en CLIENTES.LIMITE_CREDITO, saldo por SALDOS_CC
sobre_limite:   SELECT c.CLIENTE_ID, c.LIMITE_CREDITO, SUM(s.CARGOS_CXC - s.CREDITOS_CXC) AS saldo
                FROM CLIENTES c JOIN SALDOS_CC s ON s.CLIENTE_ID = c.CLIENTE_ID
                WHERE c.LIMITE_CREDITO > 0
                GROUP BY c.CLIENTE_ID, c.LIMITE_CREDITO
                HAVING SUM(s.CARGOS_CXC - s.CREDITOS_CXC) > c.LIMITE_CREDITO
```
> `credito_cliente(rfc)` = límite + saldo + disponible (límite − saldo) + días de crédito.
> ⚠️ Días de crédito: Contpaq `CDIASCREDITOCLIENTE`, SAE `DIASCRED` (en cliente);
> Microsip los maneja por condición de pago (tabla aparte) — afinar si se necesita.

---

## 8.bis Catálogo conversacional de Cuentas por Cobrar

"Conversar con la BD": preguntas que el bot/consola pueden responder, agrupadas por
nivel. Cada una = una **consulta predefinida** con parámetros. Coverage por ERP según
esquema YA verificado (✅ directo · ⚠️ requiere tabla/campo extra a inspeccionar).

### Nivel 1 — Básicas (un cliente, una métrica)
```
Pregunta                                    consulta(params)              Contpaq SAE Micro
¿Cuánto me debe el cliente X?               saldo_cliente(rfc)              ✅     ✅   ✅
¿Tiene facturas vencidas el cliente X?      facturas_vencidas(rfc)         ✅     ✅   ✅
¿Cuántas facturas vencidas tiene X?         facturas_vencidas(rfc)→count   ✅     ✅   ✅
¿Cuál es su factura más antigua sin pagar?  factura_mas_antigua(rfc)       ✅     ✅   ✅
¿Cuándo vence su próxima factura?           proxima_vence(rfc)             ✅     ✅   ✅
¿Cuál es su límite de crédito y disponible? credito_cliente(rfc)           ✅     ✅   ✅
```

### Nivel 2 — Intermedias (filtros de fecha / listados / un período)
```
¿Qué facturas vencen hoy?                   por_vencer(dias=0)             ✅     ✅   ✅
¿Cuáles vencen en los próximos 5 días?      por_vencer(dias=5)            ✅     ✅   ✅
¿Qué venció esta semana / este mes?         vencidas_rango(desde,hasta)    ✅     ✅   ✅
¿Cuánto se cobró el mes pasado?             pagos_periodo(mes_anterior)    ✅     ✅   ✅
¿Qué pagos hizo el cliente X este mes?      pagos_cliente(rfc,periodo)     ✅     ✅   ✅
¿Cuál fue su último pago y de cuánto?       ultimo_pago(rfc)               ✅     ✅   ✅
Lista las 10 facturas más vencidas          top_vencidas(limit=10)         ✅     ⚠️*  ✅
```

### Nivel 3 — Complejas (agregaciones, ranking, antigüedad, proyección)
```
Antigüedad de saldos (1-30/31-60/61-90/+90) antiguedad_saldos(rfc?)        ✅     ⚠️*  ✅
¿Cuál es la cartera vencida total?          cartera_total()                ✅     ✅   ✅
¿% vigente vs vencido de la cartera?        cartera_distribucion()         ✅     ⚠️*  ✅
Top 10 clientes con mayor adeudo            top_deudores(limit=10)         ✅     ✅   ✅
¿Cuánto esperamos cobrar la próxima semana? proyeccion_cobranza(dias=7)    ✅     ✅   ✅
Días promedio de mora de la cartera (DSO)   dso()                          ✅     ⚠️*  ✅
Clientes morosos +90 días                   morosos(dias=90)               ✅     ⚠️*  ✅
Cartera por vendedor / zona                 cartera_por_segmento(campo)    ⚠️     ✅†  ✅‡
Clientes que excedieron su límite           sobre_limite()                 ✅     ✅   ✅
```

```
✅  soportado con el esquema ya verificado
⚠️  requiere agregar consulta + inspeccionar tabla/campo aún no visto
⚠️* SAE: sin saldo por documento → antigüedad/distribución se aproxima por IMPORTE de
    la factura, no por saldo remanente (afinar; el saldo exacto solo es global en CLIE01.SALDO)
†   SAE tiene CVE_VEND en FACTF01 (cartera por vendedor)
‡   Microsip tiene ZONA_CLIENTE_ID / TIPO_CLIENTE_ID (cartera por zona/tipo)
✅  PAGOS y LÍMITE DE CRÉDITO ya verificados en vivo en los 3 → ver §8
    (pagos: admAsocCargosAbonos / FACTP01 / DOCTOS_CC 'R' · límite: CLIMITECREDITOCLIENTE
    / CLIE01.LIMCRED / CLIENTES.LIMITE_CREDITO). Pendiente menor: días de crédito en Microsip
    (condición de pago, tabla aparte) y cartera por vendedor en Contpaq (campo agente)
```

> **Modo IA (function calling):** la herramienta `consultar_erp` expone estas consultas
> nombradas; la IA interpreta la pregunta libre del usuario, elige la consulta y rellena
> params (rfc, días, periodo, limit). Nunca genera SQL. Lo no soportado (⚠️) responde
> "no disponible para este ERP" en vez de inventar.

---

## 9. Seguridad

- **Allowlist:** solo se ejecutan consultas guardadas; sin SQL en runtime.
- **Bind params tipados** (no interpolación) → anti-inyección.
- **Read-only forzado:** el runner rechaza todo lo que no sea `SELECT`; además se
  recomienda usuario de BD read-only del lado del cliente.
- **Límites:** `row_limit`, statement timeout, pool acotado por conexión.
- **Credenciales:** Chatwoot NO tiene Active Record Encryption configurado (guarda
  `access_token`/`settings` en claro). v1 sigue esa convención (columnas en la tabla),
  **nunca en logs**; endurecimiento posterior = AR Encryption con llaves gestionadas
  por ops (no se fuerza ahora para no romper el boot).
- **Aislamiento por cuenta:** una cuenta solo ve sus conexiones/consultas.
- **Egress:** el server de Chatwoot necesita salida TCP a host:puerto del ERP
  (hoy este entorno NO alcanza 3050/6072 — validar en producción / allowlist de red).

---

## 10. UI de configuración (dashboard)

**Dónde vive:** módulo propio en la **barra lateral principal** (patrón `gestorTickets`/
`contactTrackings`, registrado en `config/default-sidebar.js` → `sidebarItems/erp.js`),
NO en Settings (que es solo-admin y dejaría al agente sin acceso a la consola) y NO una
tarjeta simple de Integraciones. Sección "Cobranza / ERP". Rutas:

```
/accounts/:id/erp/connections     ErpConnections.vue   (CRUD conexiones)   [admin]
/accounts/:id/erp/queries         ErpQueries.vue       (CRUD consultas)    [admin]
/accounts/:id/erp/bots            ErpBots.vue          (Modo A + toggle B)  [admin]
/accounts/:id/erp/console         ErpConsole.vue       (consola de pruebas) [agente] ⭐
```

**Permisos:** Conexiones/Consultas/Bots = **solo admin** (guardan credenciales);
Consola = **accesible al agente** (herramienta de trabajo, sin admin).

### 10.0 Bots (Modo A + Modo B)
```
[+ Nuevo bot de cobranza]   conexión · plantilla de recordatorio
  Modo A — Recordatorio proactivo:  [✔ activo]  horario [diario 08:00 ▼]
           criterio: facturas que vencen en [3] días / ya vencidas
  Modo B — Consulta por chat (IA):  [ on/off ]  ⬅ interruptor pedido
           si OFF → el bot solo manda recordatorios; el cliente no puede preguntar
           si ON  → además responde saldo/facturas cuando el cliente escribe
```

### 10.1 Conexiones
```
[+ Nueva conexión]   motor (Firebird|SQL Server) · host · puerto · base/ruta .fdb
                     usuario · contraseña · opciones (encrypt, TDS ver)
[ Probar conexión ]  → ping read-only al adaptador, sin guardar (✔/✗ + versión server)
```

### 10.2 Consola de pruebas ⭐ (lo que pediste)
Dos formas de consultar, ambas **solo lectura** y sobre las consultas predefinidas:

```
┌─ Consola ERP ──────────────────────────────────────────────┐
│ Conexión: [ Servicios SAE ▼ ]                               │
│                                                             │
│ (A) Consulta predefinida                                    │
│     Consulta: [ facturas_por_vencer ▼ ]                     │
│     Parámetros:  RFC [__________]   días [ 5 ]              │
│     [ Ejecutar ]                                            │
│                                                             │
│ (B) Pregunta en lenguaje natural  (modo IA / preview bot)   │
│     "¿Cuáles facturas vencen en 5 días?"          [ Probar ]│
│     → la IA mapea a:  facturas_por_vencer(dias=5)           │
│       (muestra qué consulta eligió, NUNCA escribe SQL)      │
│                                                             │
│ Resultado:  12 filas · 240 ms · SELECT ... (read-only)      │
│ ┌───────┬────────────┬────────────┬──────────┐             │
│ │ folio │ fecha      │ vence      │ importe  │             │
│ ├───────┼────────────┼────────────┼──────────┤             │
│ │ A-101 │ 2026-06-20 │ 2026-07-04 │ 1,250.00 │             │
│ └───────┴────────────┴────────────┴──────────┘             │
└─────────────────────────────────────────────────────────────┘
```

Tus ejemplos mapean así a consultas predefinidas parametrizadas:
```
"¿Cuáles facturas se vencerán hoy?"        → facturas_por_vencer(dias=0)
"¿Cuáles se vencerán en 5 días?"           → facturas_por_vencer(dias=5)
"¿Cuántas facturas se pagaron el mes pasado?" → facturas_pagadas(periodo=mes_anterior)
"¿Cuál es el saldo del cliente X?"         → saldo_cliente(rfc=X)
```
> La consola (B) es **el mismo motor que usará el bot** → sirve de preview fiel de
> cómo responderá. (A) sirve para validar/depurar cada consulta sin IA.
> Nota: `facturas_pagadas` es una consulta nueva a agregar a la librería (pagos del
> período) — distinta a las de cartera vencida ya verificadas.

---

## 11. Fases de implementación (cuando se apruebe)

```
F1  Modelo + migraciones (connections, queries) + cifrado + CRUD API
F2  Adaptadores Firebird/MSSQL + QueryRunner (gems, read-only, bind, timeout)
F3  UI módulo ERP: Conexiones + Consultas + Consola de pruebas (A predefinida / B IA)
F4  Disparador directiva {{consulta:…}} (reuso detect_directive)
F5  Tool IA `consultar_erp` (solo consultas ai_enabled)
F6  Bot Cobrador: identificación de cliente + 4 consultas + formatos
F7  Verificación en navegador (cuenta 2) + esquemas reales por ERP
```

---

## 12. Preguntas abiertas / riesgos

1. ~~**Egress de red**~~ → ✅ verificado: producción alcanza el host del ERP
   (6072 MSSQL y 3050 Firebird abiertos). Confirmar por cada cliente nuevo.
2. ~~**Identificación del cliente**~~ → ✅ definido: match por **teléfono/email** del
   contacto + el bot **sugiere agregar el RFC** al contacto para referencia confiable.
3. **TDS antiguo (MSSQL 2008 R2):** `tiny_tds` 3.x rechaza TDS < 7.3 → el adaptador
   debe permitir downgrade a 7.0 o usar FreeTDS/ODBC (ver §5).
4. ~~**Esquemas reales**~~ → ✅ **los TRES ERPs verificados en vivo** (Contpaq, SAE,
   Microsip). BD de datos correcta confirmada en cada uno.
5. **Microsip — modelo de pendientes:** la demo tenía 0 docs en `DOCTOS_PEND_CC`; el
   `cargos_vencidos` con importe pendiente real (`IMPORTES_DOCTOS_PEND_CC`) hay que
   afinarlo contra una empresa que use el flujo de pendientes.
6. **Flags 'S'/'N' (Firebird):** SAE (`ACT_CXC`) y Microsip (`CANCELADO`) usan CHAR
   'S'/'N', no enteros. SAE sin saldo por doc (`CLIE01.SALDO`); Microsip saldo vía
   `SALDOS_CC` (cargos−créditos) y RFC en `DIRS_CLIENTES.RFC_CURP`.
7. **Drivers en imagen:** `fb` (Firebird client) y `tiny_tds` (FreeTDS) requieren libs
   de sistema en el Dockerfile.
8. **Usuario read-only** del lado del ERP (no usar `sysdba/sa` en producción).
9. **Filtro de naturaleza/concepto:** `CPENDIENTE>0 AND CCANCELADO=0` ya da cartera;
   afinar por `CIDCONCEPTODOCUMENTO`/`CNATURALEZA` si hay que excluir notas de crédito.
```
```
