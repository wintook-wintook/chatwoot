# Plan — Trabajo en campo y reporte de servicio

> Estado: ✅ **R1–R5 hechos** (2026-10-26, rama `feat/nva_oportunidad`, **sin commit**: lo revisa el
> programador). Ver «Implementado» al final. Pendiente: empaquetar como app de tienda.
> Relacionado: [[Plan-Roles-Permisos]] (rol Técnico, «solo lo suyo»), [[Plan-Responsable-Fijo]],
> clase Orden de trabajo (Plan-Clase-Orden-de-Trabajo), proyectos (Plan-Clase-Proyecto).

## Idea
Que el técnico (aires acondicionados, instalaciones, levantamientos…) vea en el celular los
servicios que le tocan y **documente lo que hizo**: checklist, fotos, notas, materiales, horas y
conformidad del cliente, y que el cliente reciba un reporte. La misma documentación sirve para el
trabajo **en oficina o remoto**.

## Decisiones del usuario
- **El trabajo de campo siempre va en una Orden de trabajo.** No es otro módulo ni una casilla en
  cualquier caso. Soporte = el problema; Proyecto = agrupa órdenes; Ventas = la oportunidad; Orden
  de trabajo = **lo que alguien ejecuta**.
  - Desde cualquier caso ya existe «Crear orden de trabajo» (`Cases::CaseFromCaseService`).
  - Un proyecto ya tiene órdenes adentro (`CaseTicketRelation.project_member`) y su avance se
    calcula con ellas.
  - Ej.: Proyecto «Implementación ERP» → etapa Planeación → + Orden «Levantamiento de
    requerimientos» (en campo) → la técnica va, documenta, el cliente firma → el reporte se ve en
    la orden y en el proyecto.
- **Primero web, después app de tienda.** Portal del técnico como página web para celular
  (Android y iPhone, se instala en la pantalla de inicio). Cuando esté probado, se empaqueta
  (p. ej. Capacitor) para Play Store / App Store sin rehacerlo. No se necesita nativo porque no
  hay rastreo de ubicación todo el día.

## Cómo se activa (la casilla «en campo»)
1. **Tipo de orden** (Ajustes › Casos y etapas › Tipos de caso, solo clase Orden de trabajo):
   ☑ Se ejecuta en campo (por defecto) · ☑ Pide firma · ☑ Pide fotos antes/después ·
   ☑ Enviar reporte al cliente al terminar (o pedir revisión antes) · checklist = tareas por etapa
   (ya existen; las obligatorias bloquean el cierre).
2. **Cada orden**: «Dónde se atiende: En campo / En oficina o remoto», viene del tipo y se puede
   cambiar en esa orden.
3. **Le llega al técnico** cuando la orden es en campo + tiene responsable + tiene visita agendada.
   Botón «Enviar al técnico» le manda el enlace por WhatsApp.
   En oficina/remoto no sale en el portal: el mismo reporte se llena desde la computadora.

## Lo que ya existe en Órdenes de trabajo
Dirección, horas estimadas/reales, facturable, materiales (`case_work_order_items`), visitas
(`case_meetings`, Google Calendar), tareas por etapa, notas internas (texto), entrega
(`received_by`, `received_at`, `conformity_note`), rol Técnico.

## Análisis de la competencia (2026-10-26)
Revisadas: ServiceTitan, Jobber, Housecall Pro, Zuper, Salesforce Field Service, Zoho FSM, Odoo
Field Service, Auvo, Field Control.
- **Todas tienen**: agenda y asignación, app del técnico, checklist, fotos, firma, reporte PDF,
  materiales, horas.
- **Diferencian**: tablero de despacho con mapa (Jobber, Zuper, ServiceTitan) · «Voy en camino»
  con hora estimada (Jobber, Housecall Pro) · formularios/firma obligatorios para cerrar
  (ServiceTitan, Odoo) · catálogo de servicios y refacciones con precio · cotizar en sitio con
  firma (Jobber, ServiceTitan) · portal del cliente para confirmar/reagendar/aprobar/pagar
  (Jobber Client Hub, Zuper) · **historial del equipo del cliente** (Auvo, ServiceTitan) ·
  **mantenimientos recurrentes / contratos** · sin señal (Zuper, Auvo) · IA para agendar.
- **Wintook ya gana en**: WhatsApp nativo (ellos usan SMS), Agentes IA que agendan y dan
  seguimiento, Ventas y Servicio en el mismo sistema (lo cotizado en sitio entra como
  oportunidad), responsable fijo y roles.
- **Fuera de alcance por ahora**: rastreo GPS continuo, optimización automática de rutas,
  inventario por vehículo, cobro en sitio (después vía ERP o enlace de pago), rayar sobre fotos.

## Fases
> Orden acordado (2026-10-26): **C1 Catálogo → V1 Cotizaciones** ([[Plan-Catalogo-Cotizaciones]])
> → R1 → R2 → R3/R4 → R5. El catálogo es el mismo de Ventas (vive en Ventas › Catálogo); R1 toma
> los materiales de ahí y agrega «Cotizar trabajo adicional» (usa V1). Reporte al cliente: página
> con enlace + «Descargar PDF» del navegador (sin librería de PDF por ahora).

- **R1 — Reporte de servicio** (campo y oficina), en la Orden de trabajo:
  casilla «Se ejecuta en campo» por tipo y por orden + opciones del tipo (firma, fotos, envío);
  pestaña «Reporte de servicio»: checklist (obligatorios), notas (con dictado del teclado), fotos
  y archivos, materiales desde el **catálogo de Ventas** (C1), horas
  (Iniciar/Terminar o captura), PDF. Resumen de reportes en el proyecto y en el caso de origen.
- **R2 — Portal del técnico (web para celular)**: Mi ruta de hoy (Cómo llegar, Llamar,
  WhatsApp), **Voy en camino por WhatsApp** con hora estimada, Llegué/Terminé con ubicación,
  horas automáticas, cámara, firma en pantalla, cierre con requisitos, reporte al cliente por
  WhatsApp/correo, **cotizar trabajo adicional** (entra como oportunidad), «Enviar al técnico».
- **R3 — Despacho**: tablero por técnico y día con mapa, arrastrar para asignar, aviso de choques,
  habilidades y zona del técnico.
- **R4 — Equipos y contratos**: equipos del cliente (marca, modelo, serie, ubicación) con
  historial de servicios; la orden se hace sobre un equipo; mantenimientos recurrentes que generan
  órdenes solas y avisan al cliente. (Puede subir antes de R3 si los clientes de A/C viven del
  preventivo.)
- **R5 — Cliente y campo avanzado**: portal del cliente ampliado (ver la visita y quién va,
  confirmar/reagendar, ver reporte, aprobar cotización), sin señal, técnicos externos con enlace
  de un solo uso, métricas (arreglado a la primera, revisitas, horas reales vs estimadas), CSAT
  al cerrar.
- **Después**: empaquetar el portal como app de tienda.

## Recomendaciones pendientes de confirmar
1. Firma del cliente en pantalla al cerrar en campo → **sí**.
2. Ubicación solo al llegar y al terminar → **sí** (evidencia, sin rastreo).
3. Reporte al cliente → **se envía solo**, con casilla por tipo para pedir revisión antes.
4. Técnicos externos con enlace sin usuario → **R5**.
5. Orden R3/R4 → depende de cuánto pese el mantenimiento preventivo.

## Implementado (2026-10-26)
Migraciones `20261030120000`–`20261030160000` (corridas una por una; `schema.rb` parchado a mano).

- **R1 — Reporte de servicio**: `case_types.field_settings` (en campo por defecto, fotos, conformidad,
  envío solo o con revisión), `case_tickets.on_site/report_token/report_sent_at`, `case_work_logs`
  (nota/foto/archivo, antes/después), `case_time_entries` (cronómetro/manual/visita; recalcula
  `actual_hours`). Concern `ServiceReportable` (requisitos para terminar en `transition!`),
  `ServiceReports::{Incomplete,Delivery,Serializer}`, API `case_tickets/:id/service_report`,
  página pública `/reporte/:token`. Pestaña «Reporte de servicio» (`ServiceReportPanel.vue`),
  «Trabajo en campo» en el tipo (`FieldWorkTab.vue`), materiales desde el catálogo.
- **R2 — Portal del técnico** (`/app/accounts/:id/campo`, fuera del menú): Mi ruta, visita con
  Voy en camino (WhatsApp con hora estimada), Llegué/Terminé con ubicación, firma, cotizar trabajo
  adicional, «Enviar al técnico». `Field::{Route,Visit,VisitSerializer,Messages}`, API `field_visits`.
- **R3 — Despacho** (Servicio › Despacho): técnicos con visitas del día, choques, ruta en Maps,
  arrastrar para asignar/agendar (`MeetingSyncJob`). Perfil de campo (habilidades, zona) en
  `account_users.field_profile` (Editar usuario). `Field::DispatchBoard`, API `field_dispatch`.
- **R4 — Equipos y mantenimientos**: `customer_assets` (marca, modelo, serie, ubicación,
  garantía) con historial de órdenes; `maintenance_plans` (cada N semanas/meses, anticipación,
  técnico, avisar al cliente). `MaintenancePlans::Generator` + job diario 7:00
  (`maintenance_plans_generate_job` en schedule.yml): crea la orden (sin duplicar si hay una abierta)
  y adelanta la fecha. Contacto › pestaña **Equipos**; **Servicio › Mantenimientos**; el reporte
  de servicio elige el equipo.
- **R5 — Cliente y campo avanzado**:
  - Portal del cliente `/servicio/:token` (mismo token del reporte): estado, visita y quién va,
    «Confirmo» / «Necesito otra fecha» (`visit_response`, vale solo para esa visita y esa hora),
    reporte, cotizaciones de la orden y **CSAT** (`csat_rating/comment/at`, también en el reporte).
    Va en el mensaje de «Voy en camino» y en el aviso del mantenimiento. Cada respuesta deja nota.
  - **Técnico externo** `/tecnico/:token`: enlace sin usuario (7 días o hasta terminar), Llegué,
    notas y fotos, Terminé con firma. Se da desde el reporte de servicio (copiar / WhatsApp).
  - **Sin señal**: `views/field/offlineQueue.js` guarda Llegué, notas y Terminé en el celular y
    los manda al volver la señal con `occurred_at` (el servidor la acepta de las últimas 24 h).
    Las fotos necesitan señal. Sin service worker por ahora.
  - **Métricas** (Órdenes de trabajo › Métricas): arreglado a la primera (una visita y sin
    retrabajo), revisitas y CSAT, en el resumen y por técnico (`WorkOrderBuilder#field_summary`).
    Horas reales vs estimadas y retrabajos ya existían.
- **Mis trabajos** (pestaña del portal del técnico, `/campo?tab=history`): sus órdenes terminadas
  por semana o mes (fecha de entrega, o de resuelto/cerrado), con sus horas registradas y la
  calificación del cliente; totales de órdenes, horas y promedio. Suyas = responsable o con horas
  suyas, siempre dentro de lo que su rol deja ver. `Field::WorkHistory`, `GET field_visits/history`.
- Specs: `case_service_reports_spec`, `field_visits_spec`, `field_dispatch_spec`,
  `maintenance_plans_spec`, `field_portal_spec`, `work_order_builder_spec` (todo verde).
