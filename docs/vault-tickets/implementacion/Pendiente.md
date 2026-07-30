---
titulo: Pendiente / no implementado
tipo: implementación
tags: [tickets, pendiente, todo]
---

## Pendiente / no implementado

### User Portal — pendientes tras la Fase P1 (ver [[Plan-User-Portal]])
- **i18n `en` del portal** — la copy de las vistas ERB está hoy en español; `<html lang>` ya sale de `portal.locale`. Falta extraer textos a locales es/en.
- **Tailwind por CDN** — las vistas del portal cargan Tailwind vía CDN (rápido para el MVP); migrar al build de assets para producción.
- ~~**Admin UI del portal**~~ ✅ **hecho** — vista "Portales del cliente" (`Portals.vue`, CRUD) + toggle público por tipo en `TicketTypes.vue`.
- ~~**Admin elige inbox destino (API/Email)**~~ ✅ **hecho** (R1) — selector "Canal destino" en el portal; acuse por ese canal.
- ~~**R2 — destino WhatsApp + plantilla de acuse**~~ ✅ **hecho** (config/lógica/UI). **Pendiente de verificación real**: envío de la plantilla necesita un WhatsApp conectado + plantilla aprobada en Meta (el inbox de prueba tiene 0 plantillas). Mapeo v1: folio = `{{1}}`; extender `processed_params` si la plantilla usa más parámetros.
- **Directiva bot `@estado_ticket`** (P2) — consultar estado por el canal de origen (ej. WhatsApp) sin teclear folio.
- **Adjuntos: límites + throttle** — definir tipos/tamaño permitidos en el form público y rate-limit anti-spam.
- **Dominio propio** (P2/P3) — subdominio (`soporte.dominio.com`) y marca blanca (`custom_domain` ya existe en `case_portals`, reusa el patrón del Help Center).
- **Acuse por email** cuando la conversación nace en el inbox Portal (hoy el acuse vive en la conversación; sale por el canal si se reusó uno externo).

### Modo simple (osTicket) — tras las Fases S1+S2 (ver [[Plan-Modo-Simple]])
- ~~**S2 — colapsar badges de estado**~~ ✅ **hecho** — Index/TicketDetail con `displayStatus`
  + Kanban con columnas simples (5). (Panel de conversación no muestra texto de estado).
- ~~**S3 — métricas y reglas**~~ ✅ **hecho** — Metrics oculta KPIs ITIL (grupo "Calidad" con solo CSAT)
  y TicketRules filtra estados a simples + oculta la acción "Escalar". **Modo simple completo (S1+S2+S3).**

### Unir ticket + conversación (U1) — hecho, mejoras futuras
- ~~**U1 — leer/responder al cliente desde el ticket**~~ ✅ **hecho** (pestaña Conversación + caja de respuesta + IA "usar en la conversación").
- **Reply box: decisión (pragmática)** — la caja del ticket es simple a propósito; para
  editor rico/adjuntos/canned/firma se usa "Ir a la conversación" (ReplyBox nativo). NO
  se embebe el ReplyBox nativo en el ticket (acoplado a `currentChat`, frágil).
- **U1 v2 (futuro, opcional)**: adjuntos básicos en la caja del ticket + tiempo real.

### Kanban — mejoras (tras notificar-al-mover)
- ~~**Notificar al cliente al mover**~~ ✅ **hecho** (checkbox + plantilla por estado + envío por el canal).
- **Columnas configurables por Tipo de Caso** 📋 **plan listo (Opción A+)** — ver [[Plan-Columnas-Por-Tipo]]. Hoy las columnas son constantes JS hardcodeadas (`Kanban.vue:22` y `:41`); cada tipo tendría las suyas, en cantidad y orden propios. La columna se **guarda en el ticket** (`case_tickets.case_type_column_id`), así varias columnas pueden compartir el mismo `status` — necesario para flujos comerciales o de implementación, cuyas etapas son todas `in_progress`. No toca la máquina de estados: `status` sigue siendo el canónico para SLA, reglas, reportes y portal.
- **Futuro Kanban**: plantillas de aviso configurables por cuenta; acciones rápidas en la tarjeta (asignar/prioridad/abrir); SLA en cuenta regresiva con color; avatar del asignado; mover instantáneo con "Deshacer"; swimlanes.

### Tareas + Bloqueo de ticket — hecho, mejoras futuras
- ~~**Tareas/subtareas (checklist) en el ticket**~~ ✅ **hecho** (`case_tasks`, checklist con responsable/borrar/agregar, "Tareas {done}/{total}").
- ~~**Bloqueo de ticket (lock con TTL 3 min)**~~ ✅ **hecho** (banner "X está trabajando en este ticket ahora mismo"; toma en mounted, libera en beforeDestroy; API 409 si lo tiene otro).
- ~~**Bandeja de tareas ("¿qué tengo asignado?")**~~ ✅ **hecho (F1–F4)** — ver [[Plan-Bandeja-Tareas]]. Endpoint `GET /case_tasks` a nivel cuenta con filtros + contexto del ticket (F1); vista "Tareas" con pestañas Mis/Sin asignar/Todas/Vencidas, filtros y marcar completada inline (F2); notificación `case_task_assignment` al asignar (F3); `case_task_completed` con toast en vivo a ticket.assignee + task.assignee (F4). `primary_actor` = ticket (reusa ruteo); tipos nacen sin email/push. Verificado en navegador (cuenta 2).
  - **Pendiente menor (F3 parte b)**: badge de vencidas **en el item de sidebar** "Tareas". El conteo ya se ve en la pestaña "Vencidas (n)" de la vista; el badge en el sidebar exige tocar `Secondary.vue` (layout compartido) + valor de store refrescable → diferido para no desestabilizar el layout global.
- **Futuro Tareas**: fecha límite (`due_at` ya existe en BD, falta UI); reordenar (drag); plantillas de checklist por tipo de caso; "convertir tarea en ticket".
- **Futuro Lock**: aviso en tiempo real (hoy solo al abrir/refrescar); "tomar el control" forzado por admin; heartbeat para renovar el lock mientras se escribe.
- **⚠️ Concurrencia — lost update** 📋 **análisis listo** — ver [[Analisis-Concurrencia-Edicion]]. Hoy el `update` **no valida el lock** (es cosmético) y **no hay bloqueo optimista** (`lock_version`) en ticket/tarea/nota → si dos actores (o la IA/jobs, que no toman el lock) guardan a la vez, el segundo pisa al primero **en silencio**. Recomendado: **A** (que `update` respete el lock, 423) **+ B** (bloqueo optimista → 409 "recarga"). Fase 2: **C** (la IA cede ante el humano). No reproducido, es preventivo.

### Practicidad osTicket (ver [[Plan-Practicidad-osTicket]])
- ~~**P1 — ficha accionable inline**~~ ✅ **hecho** (barra de acciones: Tomar/Prioridad/Estado, sin modal).
- **P1 menor (futuro)**: estado/prioridad editables también desde la tarjeta "Información". ~~cerrar menús con click-afuera~~ ✅ **hecho** (commit `442c1775`, `v-on-clickaway` en la fila de acciones de `TicketDetail.vue`: Prioridad, Vence y Cambiar estado).
- ~~**P2 — conversación al frente**~~ ✅ **hecho** (Resumen a dos columnas: hilo sticky + sidebar de datos; pestaña Conversación eliminada).
- **P2 menor (futuro)**: Tareas/Relacionados como acordeón colapsable en la sidebar; ajustar altura del hilo en pantallas medianas; adjuntos en la caja del hilo.
- ~~**P3 — cola tipo tabla**~~ ✅ **hecho** (tabla densa + cabeceras ordenables + selección múltiple + barra de lote Tomar/Asignar/Estado/Cerrar vía endpoint `bulk`; colas = pestañas `QUICK_FILTERS`).
- **P3 menor (futuro)**: export CSV (osTicket "Data Extraction"); persistir orden/columnas por usuario; acción de lote "asignar a equipo"; cerrar dropdowns de lote con click-afuera; quitar el dropdown "Ordenar por" del toolbar (ahora redundante con las cabeceras).
- **P4 — extras de practicidad** (parcial):
  - ~~💬 respuestas predefinidas en la caja~~ ✅ **hecho** (commit `754c77b4`, menú de canned responses en el hilo del ticket).
  - ~~📅 vencimiento (columna "Vence" + edición inline, rojo si vencido)~~ ✅ **hecho** (commit `c11450b4`, estilo osTicket "Due Date"). Se añadió la columna `due_at` (manual pisa al estimado por SLA; editarlo NO recalcula el reloj SLA); orden por vencimiento efectivo; evento `due_date_changed`. Verificado en BD; **falta verificación visual en el navegador**.
  - **Pendiente**: 🖨️ imprimir (vista imprimible ficha+hilo, BAJO).
  - ❌ **Descartado (2026-07-28)**: 👥 colaboradores/CC — **fuera del plan por ahora**, no se va a desarrollar. El backend a medias que había sin commitear (modelo, controlador, job, mailer, migración) se **eliminó**, junto con la ruta y el `has_many` que sí estaban commiteados; la tabla se revirtió en la BD local. Si se retoma, se rehace desde cero (ver §4.5 de [[Conciliacion-osTicket-MGCI]]).
  - ~~📄 **notas internas (bitácora)**~~ ✅ **hecho** (ver [[Plan-Notas-Internas]] y el changelog). Incluye la **Fase 2** (motivo opcional al Cambiar estado). **Pendiente de esa función**: editar/borrar notas; adjuntos y menciones en la nota; motivo también en los modales de Cerrar y de Resolver-problema (hoy solo en el camino simple).

### Ticket cerrado (ver [[Plan-Ticket-Cerrado]])
- ~~**Pasos 1–4**~~ ✅ **hecho** — reapertura con motivo obligatorio (admin siempre;
  el asignado dentro de la ventana de `reopen_window_days`, default 30), campos
  congelados **validados en el backend** (prioridad/vence/tipo/asignación y las
  tareas, salvo completar), notas internas permitidas siempre, SLA con reloj nuevo.
- ~~**Paso 5**~~ ✅ **hecho** — `CaseTicketListener` reabre por respuesta entrante
  del cliente (dentro de ventana) o crea ticket de seguimiento (fuera); filtra
  `incoming?`; envuelto en rescue para no tumbar la entrega del mensaje.
- ~~**Paso 6**~~ ✅ **hecho** — badge "post-cierre" en la tabla de Notas y en el
  Historial del Avance; `post_closure` se mide contra el PRIMER `closed` del
  timeline (sobrevive a reaperturas).
- ~~**Paso 7**~~ ✅ **hecho** — sección "Reapertura de tickets cerrados" en Ajustes
  del módulo: ventana (0 = sin límite) + toggle de reapertura por respuesta.
- **Decidido y no reabierto**: `custom_attributes` NO se congela (la guarda mira
  campo por campo) para no romper integraciones que solo escriben metadata.

### Widget embebible — PENDIENTE (ver [[Plan-Widget-Embebible]])
- Launcher JS + iframe para capturar tickets desde la web del cliente, reusando el User Portal.
- Incluye una corrección de seguridad: `X-Frame-Options: ALLOWALL` global (`config/application.rb:58`, heredado del fork en `fd22446c`) → `frame-ancestors` por portal.

### Email-to-ticket — PENDIENTE (no implementado)
- Crear ticket automáticamente desde un correo entrante (inbox Email) — estilo osTicket "Email Piping". Decidir mapeo (asunto→título, remitente→contacto, tipo por defecto) y reusar `PortalTicketService`/`PortalThreadSeeder`.

### `@crear_ticket` inteligente — ✅ HECHO (Fase 1+2, ver [[Plan-Crear-Ticket-IA]])
Antes la directiva era un flag: título recortado, prioridad `medium` fija, descripción vacía, clasificador a ciegas. Ahora es un intake IA que arma el ticket bien formado. Verificado en la cuenta 2 (intake real + anti-dup + prioridad forzada vs matriz).
- ~~**Fase 1 — Intake IA** (`Cases::Ai::Intake`)~~ ✅ lee la conversación → título redactado + descripción-resumen + kind/impacto/urgencia/tipo/servicio/categoría (saneados contra las listas reales).
- ~~**Fase 1 — Directiva parametrizable** `@crear_ticket(prioridad=alta, tipo=Soporte)`~~ ✅ (regex `DIRECTIVE_RE`); precedencia directiva > riesgo > matriz > default (`skip_priority_derivation`).
- ~~**Fase 1 — `Orchestrator.create_from_ai`** + confirmación con **folio** + degradación~~ ✅ (si la IA está off/falla, cae al alta básica de antes).
- ~~**Fase 1 — #2 Anti-duplicado** (§11.2)~~ ✅ vía `find_active_ticket`: si el contacto tiene un caso abierto, lo reusa y avisa "#folio en curso".
- ~~**Fase 1 — #3 Score de riesgo** (§11.3)~~ ✅ `churn_risk` (lo detecta el intake) + reincidencia (14 días) suben la prioridad y marcan `custom_attributes['churn_risk']`.
- ~~**Fase 2 — `missing_info`**~~ ✅ repregunta de un turno (Redis `case_intake_pending::<conv>`, TTL 1h).
- **#1 Deflexión** (§11.1): ya la da el ORDEN del job (KBase corre antes que el ticket); el gate con umbral de confianza explícito queda como mejora futura (KBase hoy devuelve boolean, no score).
- Fuera de Fase 1/2 (plan aparte si se retoma): intake multimodal (voz/imagen), confirmación interactiva con botones, auto-cierre + CSAT, SLA proactivo.

### General
- **Panel de contacto** (3er punto de entrada del diseño) — mostrar tickets históricos del contacto en su perfil. NO se hizo.
- **Reglas pre-cargadas por defecto** (las 7 del diseño) — el seed automático no se implementó; las reglas se crean manualmente desde la UI.
- ~~**⚠️ Borrado de conversación/contacto deja tickets huérfanos**~~ ✅ **hecho** (2026-07-15, commit `48bbc316`). Política elegida: **conservar el ticket como histórico**.
  - FKs en BD para `contact_id` / `conversation_id` / `contact_tracking_id` con **`on_delete: :nullify`** + índices de columna única (migración `20260608000007`, `validate: false` para no fallar con huérfanos previos).
  - `has_many :case_tickets, dependent: :nullify` en `Contact`, `Conversation` y `ContactTracking`.
  - `validate :contact_or_requester_present, on: :create` — así el ticket huérfano (contacto borrado → `contact_id` NULL) **sigue siendo editable/cerrable**.
  - Nota corregida: `contact_id` ya era **nullable** desde Fase C (`20260607000003`), no `not null`. Verificado en BD: borrar cada padre deja el ticket vivo con la referencia en NULL; el huérfano se edita y se cierra; crear sin contacto ni solicitante sigue bloqueado.



## 🔗 Relacionado
- [[Historial-de-implementacion]] · [[00-Indice]]
