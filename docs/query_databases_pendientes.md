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

### Otros (ops / despliegue)
- [ ] **Firebird en imagen Alpine**: `fb` gem necesita libfbclient (no está en Alpine main) → resolver para producción.
- [ ] **Usuario read-only** del lado de cada ERP (no usar `sysdba`/`sa` en producción).
- [ ] Afinar consulta masiva de **Microsip** con el modelo de pendientes real (`IMPORTES_DOCTOS_PEND_CC`).

---

### Datos de prueba (RFC reales con saldo)
- **Contpaq:** `DUVM720209EF8` (saldo $10.2M), `XAXX010101000` ($1.9M).
- **SAE:** `DUVM720209EF7` → Alberto Cota Barbosa, saldo $348.30.
