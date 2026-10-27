# Plan — Contratos (servicios recurrentes)

> Estado: ✅ **R1 hecho** (2026-10-27, rama `feat/contratos`, sin commit). R2–R4 pendientes.
> Concepto genérico de recurrencia para cualquier giro: monitoreo de alarma, iguala de
> soporte, licencia de software, póliza de mantenimiento, membresía, colegiatura…

## Decisiones del usuario
- Debe servir para **cualquier giro**: campos genéricos, nada de «suscripción de software».
- Nombre: **«Contratos»**.
- R1 primero; lo automático (R2) después.
- El cobro en sí (facturar, tarjeta) queda fuera: el pago se registra a mano o por CSV.

## R1 — Contratos (hecho)
| Pieza | Dónde |
|---|---|
| Tablas `contract_types` y `contracts` | `db/migrate/20261031100000_create_contract_types_and_contracts.rb` |
| Tipo: nombre, color, cobro por omisión (cada N día/semana/mes/año), plazo en meses, renovación automática, datos propios `custom_fields` [{key,label,type}] | `ContractType` |
| Contrato: cliente, tipo, concepto (o producto del Catálogo), cantidad × precio, moneda, cada cuánto, inicio, próximo cobro, plazo → fin, renovación automática, equipo ligado, responsable, datos propios, notas | `Contract` |
| Estado guardado: activo / suspendido / cancelado (con fecha y motivo). Calculado: **al corriente**, **por renovar** (fin del plazo en ≤ 30 días, o ya pasó y se renueva solo), **pago vencido** (pasó el próximo cobro), **terminado** (pasó el plazo sin renovación automática) | `Contract#state`, `Contract.in_state` (mismas reglas en SQL) |
| Registrar pago: el próximo cobro avanza un periodo; si pasa del fin y se renueva solo, se renueva | `Contract#register_payment!` |
| Renovar: un plazo más (mismos meses) | `Contract#renew!` |
| API | `contract_types` (index; create/update solo Administrador) · `contracts` (index con `contact_id` / `q` / `state` / `contract_type_id` + `meta.counts` por estado; create, update, register_payment, renew, cancel, reactivate, template, import) |
| Permisos | Ver: área Clientes o Ventas (con «solo lo suyo», los de sus contactos). Cambiar: «Todo» o «Solo lo suyo» en cualquiera de las dos. Precio: solo con «Ver montos». |
| Importar CSV (Excel › CSV UTF-8): contacto por correo o teléfono (no se crean contactos), tipo por nombre, `id` para actualizar, columnas extra con el nombre de los datos propios | `Contracts::CsvImport` |
| Pantallas | Clientes › **Contratos** (pestañas por estado con cuántos hay, búsqueda, tipo, plantilla, importar, nuevo) · Clientes › **Tipos de contrato** · pestaña **Contratos** en la página del contacto · menú ⋯ con Registrar pago / Renovar / Suspender / Reactivar / Cancelar / Editar |

Front: `views/contracts/` (`ContractsList`, `ContractTypes`, `ContractForm`, `ContractActions`,
`contractHelpers`), `routes/dashboard/contracts/routes.js`, `ContactContractsTab.vue`,
i18n `contracts.json`.

Specs: `spec/models/contract_spec.rb`, `spec/requests/api/v1/accounts/contracts_spec.rb`.

## Siguientes fases
- **R2 · Automático:** por tipo, avisos con días configurables (alta, X días antes del cobro,
  pago vencido → suspender a los N días, X días antes del fin del plazo, cancelado → recuperación)
  que meten al contacto a una campaña continua, crean la **oportunidad de renovación** y tareas al
  responsable. Los 30 días de «por renovar» pasan a ser del tipo.
- **R3 · Lo incluido:** horas / servicios / visitas por periodo; los casos de Servicio descuentan y
  las visitas se ligan a los planes de mantenimiento.
- **R4 · Dashboard:** ingreso recurrente mensual, cobros y renovaciones del mes, vencidos,
  cancelaciones por motivo.
- Después: conectar el sistema de cobro de cada cliente (Stripe, Conekta…).
