# Pendientes — Cobranza / ERP (Query Databases)

**Rama:** `feat/query_databases` · **Actualizado:** 2026-06-29

## Conexiones configuradas en cuenta 2

| # | Nombre | Motor / ERP | Estado | Consultas |
|---|---|---|---|---|
| 12 | Contpaq adPanchitos | mssql / contpaq | ✅ probada en navegador | 5 |
| 13 | SAE Servicios | firebird / sae (suf. 01) | ⏳ falta probar en navegador | 5 |
| 14 | Microsip Servicios | firebird / microsip | ⏳ falta probar en navegador | 4 |

---

## Pendientes

### Verificación en navegador (F7)
- [ ] **SAE Servicios** (#13): Probar conexión + Consola Modo A (`saldo_cliente` con un RFC real) + Modo B (pregunta natural).
- [ ] **Microsip Servicios** (#14): Probar conexión + Consola Modo A (`saldo_cliente`) + Modo B.
- [ ] Verificar **Bots** y el **toggle Modo B** en navegador.
- [ ] Probar **entrega real** de un recordatorio Modo A (con un contacto de prueba).
- [ ] Probar el **hook Modo B entrante** en vivo (cliente pregunta por chat → bot responde).

### Consultas demo para Contpaq
- [ ] **Consultas demo para Contpaq** que devuelvan datos sin necesitar un RFC exacto,
      para mostrar la feature en vivo. Ideas (datos confirmados: cartera $14.8M, 385 docs):
  - [ ] `top_deudores` — top 10 clientes con mayor adeudo (sin parámetros).
  - [ ] `cartera_total` — total de cartera vencida (un solo número).
  - [ ] `clientes_con_saldo` — listado de clientes con saldo > 0 (top N).
  - [ ] (opcional) ajustar `saldo_cliente` para aceptar también código de cliente, no solo RFC.

### Directiva `{{consulta:}}` desde el agente de seguimiento
- [x] **Implementar `{{consulta:nombre(param)}}`** en las plantillas de seguimiento
      (puente tracking ↔ ERP). Plan: `query_databases_directiva_tracking_plan.md`.
      Nuevo `ExternalDb::ConsultaDirectiveRenderer` + rama `:erp_query` en
      `KnowledgeBaseResponseService`. **Verificado EN VIVO vs SAE** (sae/saldo_cliente
      rfc=DUVM720209EF7 → "Alberto Cota Barbosa · 348.30"; fail-soft e in-place OK).
  - [x] F1 — `detect_directive` + parseo de args (posicional / nombrados).
  - [x] F2 — resolución de conexión **híbrida** (prefijo `sae/`… por erp_type/name; sin prefijo → bot del inbox).
  - [x] F3 — `perform_erp_query`: `QueryRunner` + render por `result_format` (summary/table).
  - [x] F4 — interpolación **in-place** de N directivas por mensaje + fail-soft.
  - [x] F5 — scoping por `@account` + logging (`log_skip`).
  - [ ] (opcional F6) tool `consultar_erp` (function calling) para Modo B dentro del seguimiento.
  - [ ] F7 — verificar en navegador con una plantilla real de seguimiento.

### Resolución de RFC en Modo B (`AiQueryService`)
- [x] Cadena mensaje → contacto → pedirlo: extrae RFC del mensaje (regex), lo persiste
      en el contacto (`custom_attribute erp_rfc`, auto-provisiona la definición por cuenta),
      y si falta lo pide por chat en vez de correr SQL roto.
  - [ ] Probar en navegador el flujo completo (cliente sin RFC → bot lo pide → lo guarda → responde).

### Otros (ops / despliegue)
- [ ] **Firebird en imagen Alpine**: `fb` gem necesita libfbclient (no está en Alpine main) → resolver para producción.
- [ ] **Usuario read-only** del lado de cada ERP (no usar `sysdba`/`sa` en producción).
- [ ] Afinar consulta masiva de **Microsip** con el modelo de pendientes real (`IMPORTES_DOCTOS_PEND_CC`).

---

### Datos de prueba (RFC reales con saldo)
- **Contpaq:** `DUVM720209EF8` (saldo $10.2M), `XAXX010101000` ($1.9M).
- **SAE:** `DUVM720209EF7` → Alberto Cota Barbosa, saldo $348.30.
