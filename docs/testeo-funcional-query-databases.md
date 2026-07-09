# Testeo Funcional — Módulo Cobranza / ERP (Query Databases)

**Proyecto:** Consultar BDs externas + Bot Cobrador · **Fecha:** 2026-06-29 · **Rama:** `feat/query_databases`
**Entorno:** cuenta 2 · Rails dev (:3000) · webpack (:3035) · Sidekiq activo · OpenAI integrado.
**Login:** admin@kontrolya.com / TestLogin123!

> Estado: casos **a ejecutar en navegador (F7)**. El "Resultado esperado" sale de lo
> ya verificado en backend contra las BDs reales (SAE/Microsip/Contpaq) + OpenAI.

---

## 1. Objetivo y alcance

Verificar de punta a punta el módulo **Cobranza / ERP**: conexión read-only a ERPs
(Firebird/SQL Server), librería de consultas predefinidas, **consola** (Modo A
predefinida + Modo B IA), **bots cobradores** (recordatorio proactivo + toggle Modo B)
y el **hook de Modo B** sobre mensajes entrantes. Foco en seguridad (solo lectura,
allowlist, anti-inyección, permisos).

## 2. Entorno y setup (datos reales de prueba)

| Elemento | Valor |
|---|---|
| Host ERP | `dragon856.startdedicated.com` (egress a 3050 Firebird / 6072 MSSQL) |
| SAE (Firebird) | ruta `C:\Program Files (x86)\...\SAE7.00\Empresa01\Datos\SAE70EMPRE01_SERVICIOS.FDB`, sysdba/masterkey, erp_type **sae**, sufijo **01** |
| Contpaq (SQL Server) | db `adPanchitos_Corp`, sa, puerto 6072, opción `tds_version=7.0`, erp_type **contpaq** |
| Microsip (Firebird) | ruta `C:\Microsip datos\SERVICIOS.FDB`, sysdba/masterkey, erp_type **microsip** |
| Cliente de prueba (SAE) | RFC `DUVM720209EF7` → "Alberto Cota Barbosa", saldo **348.30** |
| Inbox para bot | #4 Telegram (o el que se use para Modo B) |
| OpenAI | integración activa de la cuenta (Modo B) |

## 3. Resumen de casos

| Caso | Descripción | Resultado |
|---|---|---|
| TC-01 | Crear conexión Firebird (SAE) + Probar conexión | ⏳ |
| TC-02 | Crear conexión SQL Server (Contpaq, TDS 7.0) + Probar | ⏳ |
| TC-03 | Probar conexión con credenciales malas → error claro | ⏳ |
| TC-04 | Editar conexión dejando contraseña en blanco (la conserva) | ⏳ |
| TC-05 | Sembrar consultas (erp_type sae + sufijo 01) | ⏳ |
| TC-06 | Sembrar de nuevo → idempotente (0 nuevas) | ⏳ |
| TC-07 | Crear consulta manual con SQL no-SELECT → rechazada | ⏳ |
| TC-08 | Consola Modo A: ejecutar `saldo_cliente(rfc)` | ⏳ |
| TC-09 | Consola Modo A: parámetro requerido faltante → error | ⏳ |
| TC-10 | Consola Modo B: pregunta en lenguaje natural → IA | ⏳ |
| TC-11 | Crear bot cobrador + Vista previa (dry-run) | ⏳ |
| TC-12 | Recordatorio Modo A: disparo programado/manual envía | ⏳ |
| TC-13 | Hook Modo B: cliente pregunta por chat → bot responde | ⏳ |
| TC-14 | Toggle Modo B OFF → el bot ya no responde por chat | ⏳ |
| TC-15 | Permisos: agente ve Consola, NO Conexiones/Bots | ⏳ |
| TC-16 | Seguridad: inyección SQL en parámetro → neutralizada | ⏳ |

---

## 4. Casos detallados

### TC-01 · Crear conexión Firebird (SAE) + Probar conexión
- **Precondición:** sesión admin; sidebar muestra **Cobranza / ERP**.
- **Pasos:** ERP › **Conexiones** › *Nueva conexión*. Motor **Firebird**, ERP **sae**,
  sufijo **01**, host `dragon856.startdedicated.com`, puerto `3050`, base = ruta `.fdb`
  de SAE, usuario `sysdba`, contraseña `masterkey`. Guardar → clic **Probar conexión**.
- **Resultado esperado:** se guarda; el toast muestra *"Conexión OK: Firebird OK (1 fila de prueba)"*.

### TC-02 · Crear conexión SQL Server (Contpaq, TDS 7.0) + Probar
- **Pasos:** *Nueva conexión*. Motor **SQL Server**, ERP **contpaq**, host
  `dragon856.startdedicated.com`, puerto `6072`, base `adPanchitos_Corp`, usuario `sa`,
  contraseña, **Versión TDS = 7.0**. Guardar → **Probar conexión**.
- **Resultado esperado:** *"Conexión OK: Microsoft SQL Server 2008 R2 …"*.
  (Si se omite TDS 7.0, la conexión falla — el server viejo solo habla 7.0.)

### TC-03 · Probar conexión con credenciales malas → error claro
- **Pasos:** editar la conexión SAE, poner contraseña incorrecta, **Probar conexión**.
- **Resultado esperado:** toast *"Falló la conexión: …"* (no un 500); no se cae la UI.

### TC-04 · Editar conexión dejando contraseña en blanco (la conserva)
- **Pasos:** editar la conexión SAE, cambiar el nombre, dejar **contraseña vacía**, guardar.
  Luego **Probar conexión**.
- **Resultado esperado:** guarda con el nuevo nombre y **conserva la contraseña anterior**
  (Probar conexión sigue OK). El JSON nunca devuelve la contraseña (`has_password: true`).

### TC-05 · Sembrar consultas (erp_type sae + sufijo 01)
- **Precondición:** conexión SAE con erp_type **sae** y sufijo **01**.
- **Pasos:** en la fila de la conexión, clic **Sembrar consultas**.
- **Resultado esperado:** toast *"5 consultas creadas"*. Al abrir **Consultas** aparecen:
  `saldo_cliente`, `facturas_vencidas`, `pagos_periodo`, `sobre_limite`,
  `recordatorio_vencidas` (esta última con badge **IA** apagado; las 4 primeras con/sin IA según corresponda).

### TC-06 · Sembrar de nuevo → idempotente
- **Pasos:** clic **Sembrar consultas** otra vez.
- **Resultado esperado:** toast *"Ya estaba al día (sin consultas nuevas)"*; no se duplican.

### TC-07 · Crear consulta manual con SQL no-SELECT → rechazada
- **Pasos:** Consultas › *Nueva consulta*. SQL = `DELETE FROM CLIE01`. Guardar.
- **Resultado esperado:** error de validación *"solo se permiten consultas SELECT de solo lectura"*.
  (También rechaza nombre con mayúsculas/espacios: debe ser `a-z0-9_`.)

### TC-08 · Consola Modo A — ejecutar `saldo_cliente(rfc)`
- **Precondición:** consultas sembradas; ir a ERP › **Consola**.
- **Pasos:** elegir conexión **SAE**, consulta `saldo_cliente`, parámetro `rfc` =
  `DUVM720209EF7`, clic **Ejecutar**.
- **Resultado esperado:** tabla con 1 fila → `NOMBRE = Alberto Cota Barbosa`, `SALDO = 348.30…`;
  meta *"1 filas · N ms"*; el desplegable "Consulta ejecutada" muestra el SQL (solo lectura).

### TC-09 · Consola Modo A — parámetro requerido faltante → error
- **Pasos:** misma consulta `saldo_cliente`, dejar `rfc` vacío, **Ejecutar**.
- **Resultado esperado:** error *"falta el parámetro requerido: rfc"* (no ejecuta).

### TC-10 · Consola Modo B — pregunta en lenguaje natural
- **Precondición:** `saldo_cliente` (y otras) con **IA habilitada**; OpenAI activo.
- **Pasos:** en la consola, caja **"Preguntá en lenguaje natural"**, escribir
  *"¿Cuál es el saldo del cliente con RFC DUVM720209EF7?"* → **Preguntar**.
- **Resultado esperado:** respuesta *"El saldo del cliente con RFC DUVM720209EF7 es 348.30."*
  y *"Consulta elegida: saldo_cliente"*. (La IA elige la consulta y rellena el RFC; nunca escribe SQL.)

### TC-11 · Crear bot cobrador + Vista previa (dry-run)
- **Pasos:** ERP › **Bots** › *Nuevo bot*. Nombre, conexión **SAE**, consulta
  `recordatorio_vencidas`, inbox de entrega #4, columna de teléfono `TELEFONO`,
  plantilla `Hola {{NOMBRE}} 👋 factura {{SERIE}}{{FOLIO}} por ${{IMPORTE}} venció el {{FECHA_VEN}}`.
  Guardar → **Vista previa (dry-run)**.
- **Resultado esperado:** lista de hasta 5 recordatorios compuestos con datos reales,
  montos a 2 decimales y fecha `dd/mm/aaaa`, **sin enviarse** nada. Ej:
  *"Hola Alberto Cota Barbosa 👋 factura 2 por $812.14 venció el 22/04/2022"*.

### TC-12 · Recordatorio Modo A — disparo envía (⚠️ con datos de prueba)
- **Precondición:** bot **activo**, `run_hour` = hora actual, inbox con contacto real de prueba.
- **Pasos:** esperar el cron horario o disparar manualmente
  `ErpCollection::ReminderDispatchJob.perform_now` por consola.
- **Resultado esperado:** por cada fila con teléfono que **mapee a un contacto** del inbox,
  se crea un mensaje saliente con el recordatorio; `last_run_at` se actualiza (no re-envía
  el mismo día). Filas sin contacto → se cuentan como `skipped`.

### TC-13 · Hook Modo B — cliente pregunta por chat → bot responde
- **Precondición:** bot con **Modo B ON** en el inbox #4; OpenAI activo; consultas IA sembradas.
- **Pasos:** como cliente, enviar al inbox #4 *"¿cuál es el saldo del cliente con RFC DUVM720209EF7?"*.
- **Resultado esperado:** a los pocos segundos el bot responde en la conversación
  *"El saldo del cliente… es 348.30."*. (Callback `incoming?` → `ChatResponseJob` → IA.)

### TC-14 · Toggle Modo B OFF → no responde por chat
- **Pasos:** editar el bot, **desactivar Modo B**, guardar. Repetir TC-13.
- **Resultado esperado:** el bot **no** responde la consulta por chat (Modo A sigue intacto).

### TC-15 · Permisos admin/agente
- **Pasos:** iniciar sesión como **agente** (no admin) y abrir el módulo.
- **Resultado esperado:** el agente ve **Consola** (puede consultar), pero **Conexiones**
  y **Bots** quedan fuera de su alcance (rutas admin).

### TC-16 · Seguridad — inyección SQL neutralizada
- **Pasos:** en la consola, consulta con parámetro string (ej. `by_rfc`), poner como RFC
  `X' OR 1=1 --`.
- **Resultado esperado:** la consulta corre con el valor **escapado** y devuelve **0 filas**
  (no se ejecuta la inyección). Firebird usa bind params `?`; SQL Server, literal escapado.

---

## 5. Verificaciones técnicas ya realizadas (backend, contra BD real)

| Verificación | Resultado |
|---|---|
| Conexión + SELECT read-only SAE/Contpaq/Microsip | ✅ en vivo |
| Inyección `X' OR 1=1 --` → 0 filas | ✅ |
| Parámetro requerido faltante → error | ✅ |
| Sembrado SAE (5 consultas) + idempotencia | ✅ |
| Consulta masiva (join CLIE.CLAVE=FACTF.CVE_CLPV + TELEFONO) | ✅ 33 filas |
| Composición de recordatorio (montos/fechas formateados) | ✅ |
| Modo B function calling (OpenAI) → consulta + respuesta | ✅ "saldo… 348.30" |
| Hook entrante: guard encola + find_bot resuelve | ✅ |

## 6. Notas / pendientes de entorno

- **Egress de red:** el server de producción debe alcanzar host:puerto del ERP.
- **Firebird en imagen Alpine:** `fb` gem necesita libfbclient (no está en Alpine main) →
  resolver en ops (base Debian/prebuild) antes de desplegar.
- **TDS 7.0:** los SQL Server de Contpaq (2008 R2) requieren `tds_version=7.0` en la conexión.
- **Credenciales:** v1 sigue la convención de Chatwoot (texto plano, como `access_token`);
  para producción → usuario **read-only** del lado del ERP y, opcional, AR Encryption.
