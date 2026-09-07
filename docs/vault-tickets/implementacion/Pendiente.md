---
titulo: Pendiente / no implementado
tipo: implementación
tags: [tickets, pendiente, todo]
---

## Pendiente / no implementado

### Reuniones — módulo COMPLETO (F0–F7), pendientes menores
Ver [[Historial-de-implementacion]] y `docs/tickets_reuniones_plan.md`. Las 7 fases
están implementadas, probadas y pusheadas a `origin/feat/tickets`.
- **⏸️ Verificar el dominio en Google Cloud (§12.2)** — **aplazado por decisión del usuario (2026-08-13)**.
  Es lo único que falta para que el push en tiempo real (F7) se encienda. Dos pasos:
  (1) Search Console: verificar `wintook.com` como propiedad de tipo **Dominio** (TXT en DNS,
  cubre todos los subdominios) **con la cuenta dueña del proyecto de Cloud**;
  (2) Cloud Console → APIs y servicios → **Verificación de dominios** → agregar
  `develop.wintook.com` (y `app.wintook.com` / `chatzeus.com` para producción).
  **NO se toca la pantalla de Credenciales**: la URL del webhook no se registra ahí, la manda
  el código en `events.watch`. Mientras no se haga, `events.watch` falla en silencio y el
  módulo funciona igual con la reconciliación perezosa (§12.5).
- **Prueba de punta a punta del push** — pendiente de lo anterior: agendar una reunión, moverla
  desde Google Calendar y comprobar que el ticket se actualiza SIN abrirlo.
- **Verificar en la bandeja cuántos correos manda Google** al cancelar/truncar una serie: MGCI
  pide **un** aviso por operación (medido), pero cuántos correos emite Google por cada aviso solo
  se ve en el buzón del invitado. Si resultara uno por ocurrencia, el plan B es cancelar el
  maestro con `sendUpdates: 'none'` y avisar por el canal del ticket (§10.2c).
- **Decir en la pantalla de conexión de Google Calendar** que MGCI solo lee y conserva las
  reuniones creadas desde el sistema (§12.4): `events.watch` es por calendario, así que llegan
  avisos de los eventos personales del agente (se descartan en memoria, pero conviene decirlo).
- **F8 (diferido por el plan)**: recordatorios internos, bandeja de reuniones a nivel cuenta,
  `scope: 'following'` al editar/cancelar una ocurrencia de serie.

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
- ~~**Columnas configurables por Tipo de Caso** (Opción A+)~~ ✅ **hecho (F1–F3)** — ver [[Plan-Columnas-Por-Tipo]]. Cada tipo define sus columnas (nombre/color/orden libres); cada columna cubre uno o más `status` y **varias pueden compartir el mismo** (flujos comerciales/implementación, todo `in_progress`). El ticket guarda `case_tickets.case_type_column_id`; `status` sigue siendo el canónico para SLA/reglas/reportes/portal.
  - **F1 backend** (commit): tabla `case_type_columns` + puntero FK nullify; `CaseTypeColumn` (valida estados, sin validación de solape); hook `resync_type_column` (invariante columna⊆estado en un solo lugar); CRUD + `PUT replace` (`Cases::TypeColumnsReplaceService`: transacción + cobertura de los 13 estados + limpieza de huérfanos); endpoint `move` (rama mismo-estado solo puntero + evento `column_changed` / otro estado transición+puntero); `columns` en JSON de tipos, `case_type_column_id` en ticket y `push_event_data`. 9/9 pruebas de consola en verde.
  - **F2 config UI** (commit): panel "Columnas" en `TicketTypes.vue` — editor del set con nombre/color/multiselect de estados (chips)/reordenar + helper de cobertura + aviso de solape. Store `typeColumns` + `replaceTypeColumns`; api `caseTypeColumns.js`.
  - **F3 tablero** (commit): selector de Tipo; `columns()` con fallback; `grouped()` por puntero (Regla 1); `onDrop` con atajo de mismo-estado (sin modal). Verificado en navegador (cuenta 2, Comercial 6 columnas).
  - **Pendiente menor (F4, diferible)**: validador de flujo — matriz completa de `VALID_TRANSITIONS` al front + aviso cuando dos columnas contiguas de estados distintos no tienen camino legal. Sin él, una config mal armada puede parecer un bug del tablero.
  - **Requisito operativo**: las cadenas de i18n del módulo NO deben decir "osTicket" (los comentarios de código sí pueden referenciar el norte).
- **Futuro Kanban**: plantillas de aviso configurables por cuenta; acciones rápidas en la tarjeta (asignar/prioridad/abrir); SLA en cuenta regresiva con color; avatar del asignado; mover instantáneo con "Deshacer"; swimlanes.

### Tareas + Bloqueo de ticket — hecho, mejoras futuras
- ~~**Tareas/subtareas (checklist) en el ticket**~~ ✅ **hecho** (`case_tasks`, checklist con responsable/borrar/agregar, "Tareas {done}/{total}").
- ~~**Bloqueo de ticket (lock con TTL 3 min)**~~ ✅ **hecho** (banner "X está trabajando en este ticket ahora mismo"; toma en mounted, libera en beforeDestroy; API 409 si lo tiene otro).
- ~~**Bandeja de tareas ("¿qué tengo asignado?")**~~ ✅ **hecho (F1–F4)** — ver [[Plan-Bandeja-Tareas]]. Endpoint `GET /case_tasks` a nivel cuenta con filtros + contexto del ticket (F1); vista "Tareas" con pestañas Mis/Sin asignar/Todas/Vencidas, filtros y marcar completada inline (F2); notificación `case_task_assignment` al asignar (F3); `case_task_completed` con toast en vivo a ticket.assignee + task.assignee (F4). `primary_actor` = ticket (reusa ruteo); tipos nacen sin email/push. Verificado en navegador (cuenta 2).
  - **Pendiente menor (F3 parte b)**: badge de vencidas **en el item de sidebar** "Tareas". El conteo ya se ve en la pestaña "Vencidas (n)" de la vista; el badge en el sidebar exige tocar `Secondary.vue` (layout compartido) + valor de store refrescable → diferido para no desestabilizar el layout global.
- ~~**Notas por tarea + UX de notas/tareas**~~ ✅ **hecho** (2026-08-03). Una nota interna puede pertenecer al **ticket** (como siempre) o a una **tarea** concreta del mismo ticket.
  - **Backend**: `case_events` gana `case_task_id` (nullable, FK `on_delete: :nullify` → al borrar la tarea la nota vuelve a ser del ticket, no se pierde). Migración `20260803120000`. `CaseEvent belongs_to :case_task`; `CaseTicket#add_internal_note!(case_task:)`; `case_notes_controller` acepta/expone `case_task_id` + `case_task {id,sequence,title}`. `case_tasks_controller` y `case_tasks_index_controller` exponen `notes_count` (mapa agrupado, sin N+1).
  - **Notas (tabla del ticket)**: columna "Tarea" con folio T00N (— si es del ticket); metadata **debajo del texto** "Creada el … · Editada el … por …" (se quitó la columna Fecha); buscador con lupa + limpiar; **orden por click** en encabezado; botón **Actualizar**; **más reciente primero** por defecto; modal con **subtítulo** descriptivo + editor enriquecido con la barra bien contenida (se quitó el margen negativo que la desbordaba).
  - **Tareas (tabla del ticket)**: botón por fila **"Agregar nota"** (crea nota atada a la tarea) + columna **"Notas"** (📋 N, click → Notas filtradas por la tarea; con 0 solo avisa, no navega); buscador/orden/actualizar/subtítulo igual que notas; iconos de acción a `large`.
  - **Bandeja de tareas** (`/tickets/tasks`): mismas columnas **Notas** y acción **Agregar nota** (navegan al ticket vía `?tab=notes&task=&taskId=&compose=1`; `TicketDetail` abre la pestaña y filtra/compone al cargar).
  - **Pendiente menor**: al **agregar nota** desde la bandeja el banner del modal muestra el folio pero **no el título** de la tarea (no viaja en el query); traer el título si molesta. La bandeja **toca backend** → producción necesita reinicio de Rails.
- ~~**Solicitante de tarea + menú de acciones + refactor del modal**~~ ✅ **hecho** (2026-08-05, commit `1e0bb753`, **mergeado a `develop`** `867185ac`). En ambas tablas (dentro del ticket y bandeja de cuenta) y su modal compartido.
  - **Backend**: `case_tasks` gana `requester_id` (solicitante, FK `users` `on_delete: :nullify`). Migración `20260805120000`. Se **fija al agente actual al crear** y es **firma inmutable**; `case_tasks_controller#update` solo lo acepta (`assign_requester_if_absent`) **si la tarea aún no lo tiene** (tareas antiguas). `requester` expuesto en los dos serializadores (con `includes(:requester)`).
  - **Modal**: entre título y descripción, dos columnas **Solicitante** (textbox fijo con el agente; o **lista editable** si la tarea no tiene solicitante) + **Responsable** (lista); debajo de la descripción, **Vencimiento · Prioridad · Estado**. El modal **ya no scrollea**: el editor de la descripción tiene **alto fijo** con su propio scroll.
  - **Tablas**: nueva columna **Solicitante**; se quitó la columna suelta "Notas" y los botones sueltos de acción → todo en **un solo menú desplegable** (botón de menú a la **izquierda del folio**, abre a la derecha) con **Notas de la tarea (total)** (0 → solo avisa), **Agregar nota** y **Borrar tarea**. Menú con posición fija (no lo recorta el overflow de la tabla) que cierra con click-afuera/scroll.
  - **Pendiente menor**: nueva columna `requester_id` → al desplegar `develop` **correr migración + reiniciar Rails**.
- **Futuro Tareas**: reordenar (drag); plantillas de checklist por tipo de caso; "convertir tarea en ticket". (~~fecha límite `due_at` UI~~ ✅ ya en el modal de tarea).
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
- [x] ~~**Señal `needs_escalation` en el Intake (KBase se come el escalamiento)**~~ ✅ **HECHO e
      implementado (2026-08-28)** — descubierto probando
      `AGENTE GRUAS V6/V7` (tracking_template, conv. display #39): cuando el `complementary_prompt`
      dice "esto es fuera de alcance, escala con un asesor" (ej. jornada de 16h o varias unidades en
      un agente pensado para un servicio de 2h), `Cases::Ai::Intake` solo tiene `ticket_worthy`
      (true/false); ese booleano no distingue "charla trivial, no hace falta ticket" de "solicitud
      real pero la política dice que debe pasar a un humano". Como las dos devuelven `false`,
      `TicketCreatorService#create_if_needed` retorna `false` y el job sigue de largo hacia
      `{{hoja:...}}` (KBase), que no conoce la política de negocio y contesta con lo que encuentre
      en la hoja/documento — respuesta confusa en vez de un hand-off claro a un asesor.
      **Arreglo propuesto**: agregar `needs_escalation` (bool) + `escalation_reason` (string corto)
      al JSON que devuelve `Cases::Ai::Intake#extract` (independiente de `ticket_worthy`, gobernado
      por el `policy_prompt`); en `TicketCreatorService#create_if_needed`, chequear
      `needs_escalation` ANTES que `not_ticket_worthy?`, armar el ticket igual (no perder datos) y
      enviar un mensaje de hand-off fijo/templado (no lo redacta el LLM) en vez de la confirmación
      genérica, con `outcome = :escalated`. Esto corta el turno ahí mismo — nunca llega a KBase ni
      al fallback conversacional. Acotado: solo afecta templates que usan `@crear_ticket`; sin IA
      disponible cae al comportamiento degradado actual (sin regresión).
      **Re-probado (2026-08-28) tras traer `b133a070`/`c9bfd9a1` (prompt completo en todas las
      ramas de KBase + `@ruta`)**: mejora parcial, no resuelve el fondo. Con el mismo mensaje de
      prueba, la rama de KBase ahora sí redacta algo parecido a un hand-off ("Esto lo tiene que
      atender un asesor directamente") en vez de la respuesta confusa de antes ("no tenemos filas
      que coincidan") — `b133a070` sí ayuda a que el LLM de esa rama vea la política del prompt.
      Pero sigue sin ser un estado real: (1) el mismo mensaje, en dos ejecuciones distintas del job
      (una manual, otra por el Sidekiq real vía el hook de `Message` que ya encola el job en
      producción — `app/models/message.rb:474`), dio dos comportamientos distintos — sin
      `needs_escalation` no hay determinismo, es a criterio del LLM de turno; y (2) un mensaje
      siguiente del cliente igual llevó a crear el ticket y ofrecer horarios — "escalar" es una
      frase de un turno, no algo que el motor recuerde para frenar el turno siguiente. Sigue
      haciendo falta el `needs_escalation` explícito para que el escalamiento sea un estado, no una
      redacción ocasional.
      **✅ Implementado y probado (2026-08-28)**: `Cases::Ai::Intake#extract` ahora devuelve
      `needs_escalation` (bool) + `escalation_reason` (string), gobernado por el `policy_prompt`
      (las reglas de negocio del `complementary_prompt`, ej. nuestra sección "ALCANCE DEL
      SERVICIO"). En `TicketCreatorService#create_if_needed` se chequea PRIMERO, antes de
      `multiple_requests?`, `not_ticket_worthy?` y `request_missing_fields` — corta el turno ahí:
      arma el ticket igual (mismo intake, no se pierde nada), pero responde con un mensaje de
      hand-off fijo/templado (no lo redacta el LLM) y `outcome = :escalated`, que nunca dispara
      `@agendar_calendar` ni llega a KBase/conversacional. Archivos:
      `app/services/cases/ai/intake.rb`, `app/services/cases/ticket_creator_service.rb`.
      Probado end-to-end vía canal API (conv. display #49) con el caso original (jornada 16h + 2
      Hiab): en UN SOLO turno, sin idas y vueltas, el bot respondió "Esto lo tiene que atender un
      asesor directamente (El cliente solicita una jornada de 16 horas, lo cual está fuera de
      alcance.). Registré tu caso RU-00010 y te contactarán en breve." — ticket creado con título y
      descripción correctos (menciona ambas unidades Hiab y la jornada), sin ofrecer horarios, sin
      caer en KBase. **Efecto colateral bueno**: como el chequeo corre antes que
      `request_missing_fields`, tampoco llegó a pedir "Ubicación Destino" (pendiente #3) en este
      caso — para los mensajes que SÍ disparan `needs_escalation`, el problema del pendiente #3
      queda evitado de rebote (pero #3 sigue existiendo tal cual para los casos que no escalan).
- [ ] **🟡 Un solo ticket "abierto" por contacto bloquea solicitudes multi-servicio (pérdida
      silenciosa de datos ya corregida, falta la solución de fondo por `ID_RECURSO`)** —
      re-probado 2026-08-28 con un caso
      MULTISOLICITUD explícito (canal API, conv. display #47): el cliente pidió 2 servicios de
      transporte con datos completos e independientes, y dijo textualmente "son 2 trabajos
      distintos, en fechas distintas" — exactamente el caso que el prompt M0-M7 ya instruye
      escalar (M2: MULTISOLICITUD). **No escaló.** `Cases::Ai::Intake` armó UN solo ticket
      (RU-00008) con un único título/descripción, y la descripción **solo conserva el Servicio 1**
      (3 ton, Juárez→Patria, jueves) — el **Servicio 2 completo** (8 ton, Independencia→Hidalgo,
      viernes) **desaparece sin dejar rastro**: no está en el ticket, no se le avisa al cliente, no
      hay escalamiento. El bot sigue derecho a ofrecer horarios como si fuera un solo servicio.
      Es más grave que "no puede separar en 2 tickets": es **pérdida silenciosa de un trabajo
      completo** (y su ingreso) sin que nadie —cliente ni asesor— se entere. La instrucción M2 del
      prompt no tiene ningún efecto porque el intake está diseñado para resumir UNA solicitud, no
      para detectar "esto no cabe en un ticket".
      Caso de prueba original: el cliente pidió 2 unidades de grúa (2 servicios independientes,
      cotizables por separado); `find_active_ticket`
      (`app/services/cases/orchestrator_service.rb:23-29`) busca *cualquier* ticket no
      cerrado/cancelado del contacto en TODA la cuenta y lo reutiliza — no hay forma de que una
      segunda invocación de `@crear_ticket` en el mismo turno cree un ticket separado, por más que
      el prompt lo pida.
      **Pista real encontrada en los datos (2026-08-26)**: la hoja `CATALOGO GRUAS VIKA NVO`
      (`knowledge_source_id=198`, tabla `google_sheet_rows`) ya modela cada unidad como un recurso
      aislado — columna `ID_RECURSO` (ej. `TP-64`, `TP-123`), poblada hoy para 24 remolques
      (`TIPO_RECURSO: REMOLQUE`). Del lado del calendario, `ContactTrackings::AvailabilitySlotService`
      ya trata **cada calendario de `booking_calendar_ids` como un recurso independiente** (doc del
      propio archivo: "cada calendario marcado es un RECURSO independiente"). Son la misma idea en
      dos capas que hoy NO están conectadas: no existe un vínculo guardado `ID_RECURSO ↔
      calendar_id`, y las grúas/Hiab que pidió el cliente en la prueba no están dadas de alta como
      filas `RECURSO` (solo existen como conocimiento conceptual — `CONFIGURACION`/
      `CAMPO_REQUERIDO`/`REGLA_DECISION` — por eso el bot respondió "no tenemos filas que
      coincidan": no hay inventario real de grúas que buscar).
      **✅ Arreglo mínimo urgente — HECHO e implementado (2026-08-28)**: `Cases::Ai::Intake#extract`
      ahora devuelve `multiple_requests` (bool) + `requests_summary` (array, una línea por
      solicitud detectada); en `TicketCreatorService#create_if_needed` se chequea ANTES que
      `not_ticket_worthy?`/`request_missing_fields` — si es `true`, arma un ticket con TODAS las
      solicitudes listadas (prioridad alta, `custom_attributes: {multiple_requests: true}`),
      responde al cliente explicando que se escaló para que un asesor las separe, y NO ofrece
      horarios (`outcome = :escalated_multiple`, fuera de `%i[created linked_existing]`). Archivos:
      `app/services/cases/ai/intake.rb`, `app/services/cases/ticket_creator_service.rb`.
      Probado end-to-end vía canal API (conv. display #48, ticket RU-00009): ya NO se pierde el
      segundo servicio en silencio — antes desaparecía sin dejar rastro, ahora el ticket lista
      ambos y el bot avisa que un asesor los va a separar.
      **Limitación menor detectada al probar**: el resumen del 2º ítem a veces sale impreciso
      ("detalles no proporcionados" cuando el cliente SÍ los dio) — el LLM del intake no siempre
      copia fielmente cada solicitud al resumen. No es pérdida real de dato (el ticket queda
      vinculado a la conversación completa, el asesor puede leer el mensaje original), pero vale la
      pena ajustar el prompt del intake si se repite. Alcance NO cubierto por este arreglo mínimo
      (sigue siendo la solución de fondo, sin construir): 2 tickets separados, 2 citas separadas,
      una por servicio — ver abajo.
      **Arreglo propuesto (3 piezas, solución de fondo — pendiente)**:
        1. Dato de negocio: dar de alta las grúas reales como filas `RECURSO` en el catálogo, con
           su propio `ID_RECURSO`, capacidad, extensiones, etc. (hoy solo están los remolques).
        2. Guardar la relación `ID_RECURSO ↔ calendar_id` (columna nueva en la hoja, o una tabla
           chica) — hoy `booking_calendar_ids` es solo un arreglo plano de IDs de Google Calendar
           sin nombre de recurso asociado en nuestra BD (los nombres tipo "TP-113" que ve el
           cliente al agendar vienen del *summary* del calendario en Google, no de un dato nuestro).
        3. Código: cuando el intake detecte N unidades en la solicitud, resolver cada una contra el
           catálogo → su `ID_RECURSO` → su `calendar_id`, y crear un `ContactTracking` por unidad
           resuelta, pasándole a `AvailabilitySlotService` (vía `booking_calendars:`) SOLO el
           calendario de ESE recurso en vez del pool completo — la clase ya acepta ese hash tal
           cual, no requiere cambios. Cada tracking agenda y factura por su cuenta con la
           arquitectura actual (un ticket + una cita cada uno), sin tocar el modelo de datos de
           `contact_trackings` ni el anti-duplicado de tickets.
      Ver también la limitación gemela de citas en
      [[../../vault-contact-tracking/implementacion/Pendiente|vault-contact-tracking/Pendiente]]
      (una sola cita por `ContactTracking`) — con esta solución deja de ser una limitación: al
      haber un tracking por recurso, "una cita por tracking" es exactamente lo que se necesita.
- [x] ~~**`case_type_fields` de "RENTA UNIDADES" son obligatorios sin condición — bloquean
      cualquier distinción MANIOBRA vs TRANSPORTE desde el prompt**~~ ✅ **HECHO e implementado
      (2026-08-28)** — descubierto probando el prompt V1 "arquitectura determinista" sobre
      `AGENTE GRUAS V7` (2026-08-26/27): el tipo de caso `case_types.id=100` ("RENTA UNIDADES")
      tiene 4 campos marcados `required=true` en `case_type_fields` sin condición alguna:
      **Material a transportar y cantidad, Ubicación Recogida, Ubicación Destino, Peso**.
      `Cases::Ai::FieldExtractor` (invocado desde `TicketCreatorService#request_missing_fields`)
      los exigía siempre, sin importar qué dijera el `complementary_prompt`. Resultado: aunque el
      prompt ya distinguiera "MANIOBRA en un solo sitio" (sin destino) de "TRANSPORTE punto a
      punto" (con destino), el checklist rígido interceptaba el turno ANTES de que esa distinción
      tuviera oportunidad de aplicarse — el bot pedía "Ubicación Destino" en una solicitud de
      maniobra en sitio único (mismo bug que el caso original de la conv. #39).
      **✅ Arreglo implementado**: en vez de tocar el modelo de datos (segundo `case_type` o
      campos condicionales por tipo — más invasivo y compartido por todas las cuentas),
      `Cases::Ai::FieldExtractor` ahora reconoce un marcador **"N/A"** que el LLM puede devolver
      cuando un campo obligatorio **no aplica** a la solicitud (distinto de "no lo sabemos
      todavía") — se agregó la regla al `system_prompt` del extractor y un cast a
      `NOT_APPLICABLE_LABEL` ("No aplica") que cuenta como valor presente, no como faltante.
      Archivo: `app/services/cases/ai/field_extractor.rb`. Es un cambio general del módulo de
      tickets (beneficia a cualquier cuenta/tipo de caso con campos obligatorios que no siempre
      aplican), no específico de grúas.
      Probado end-to-end vía canal API (conv. display #50): mensaje de maniobra en un solo sitio
      ("necesito una grúa para subir un motor en la obra... no hay traslado a otro lugar, es solo
      maniobra de izaje en el mismo sitio") → ticket RU-00011 creado en UN SOLO turno, con
      `custom_attributes: {"ubicacion_destino": "No aplica", "ubicacion_recogida": "Av. Patria
      500, Zapopan", ...}` y horarios ofrecidos de inmediato — sin preguntar destino, sin vueltas.
      El extractor lo dedujo del propio mensaje inicial, sin que el cliente tuviera que decir
      "no aplica" explícitamente.

### Pruebas reales sobre `AGENTE GRUAS V8` (conv. display #55 y #56, 2026-08-29)

El usuario probó V8 a mano por Telegram real (no canal API) y reportó 3 puntos; se verificaron los
tres contra las conversaciones reales y salió un 4º hallazgo no reportado que explica varios
síntomas a la vez. Ninguno de los 5 está implementado — quedan como plan a ejecutar.

- [x] ~~**1 — No debería ofrecer agenda automática si queda una pregunta técnica sin
      responder**~~ ✅ **HECHO e implementado (2026-08-31)** — conv. #55: el cliente pregunta "qué
      camión me puede ayudar" en el mismo mensaje que pide el servicio; el bot la ignoraba, pedía
      los campos del checklist, y apenas los completaba **creaba el ticket Y ofrecía horarios en
      el mismo turno** (comportamiento "ETAPA 3" ya existente y deliberado) sin haber contestado
      la pregunta. Recién 2 turnos después contestaba qué camión era (vía KBase, correctamente:
      TP-64). El prompt M5 ("recomienda antes de agendar") no tenía efecto porque el LLM
      conversacional que lo lee **nunca se ejecutaba** en ese turno — lo resolvía por completo
      código determinista (`TicketCreatorService` + la oferta automática de agenda) que no
      consultaba ninguna clasificación de intención.
      **Arreglo implementado** (mismo patrón que `needs_escalation`/`multiple_requests`/
      `resources_requested` — una señal más del mismo intake, no una llamada extra al LLM):
      - `Cases::Ai::Intake` — el JSON del intake ahora incluye `pending_technical_question` (bool)
        + `technical_question` (el texto tal cual lo preguntó el cliente), true solo si hizo una
        pregunta técnica concreta que ningún mensaje posterior del bot ya respondió.
      - `TicketCreatorService` — expone `pending_technical_question`/`technical_question` como
        lectores públicos (se setean apenas hay `fields`, independiente de qué outcome termine
        disparándose).
      - `ContactTrackingResponseAnalyzerJob` — nuevo `offer_appointment_or_resolve_question`,
        reemplaza las DOS llamadas directas a `handle_book_appointment` que existían tras crear/
        reusar un ticket (`try_create_ticket` y `dispatch_book_appointment`, + el loop de
        `spawned_trackings` de §3): si `creator.pending_technical_question`, intenta resolverla
        primero por KBase (`resolve_pending_technical_question`, aislado en su propio rescue); si
        KBase la contesta, **no ofrece agenda este turno** (el cliente sigue la conversación
        normal y la agenda se ofrece en un turno posterior, cuando ya no quede pendiente); si KBase
        no encuentra nada o no hay directiva, cae al comportamiento de siempre (ofrecer agenda) —
        nunca se deja al cliente sin ninguna respuesta. Archivos: `app/services/cases/ai/intake.rb`,
        `app/services/cases/ticket_creator_service.rb`,
        `app/jobs/contact_tracking_response_analyzer_job.rb`.
      **✅ Probado (2026-08-31)**: el campo `pending_technical_question`/`technical_question` del
      intake se verificó capturando bien la pregunta en mensajes reales de prueba (aunque en esos
      mensajes de prueba específicos terminó ganando otra señal previa en el orden de chequeo —
      `needs_escalation` o `multiple_requests` — antes de llegar al gate nuevo; es una limitación
      conocida y preexistente de que el intake resuelve varias señales en una sola pasada del LLM,
      no algo que este cambio haya introducido). El **mecanismo del gate en sí** (`offer_appointment_or_resolve_question`)
      se probó de forma aislada y determinística con los 3 casos: pending=true + KBase resuelve →
      NO ofrece agenda; pending=true + KBase no resuelve → SÍ ofrece agenda (fallback, sin dejar al
      cliente sin nada); pending=false → SÍ ofrece agenda (sin regresión del camino normal). Los 3
      se comportaron como se diseñó.
      **Nota de alcance**: esto también resuelve la versión mínima de **3a** (ver abajo) — es la
      MISMA señal e implementación, no dos features separadas (confirmado, ver nota de secuencia
      original más abajo).

- [x] ~~**2a — Vincular `ID_RECURSO` real a su `calendar_id` en vez de depender del nombre del
      calendario en Google**~~ ✅ **HECHO (2026-09-03)** — conv. #56: el usuario ya avanzó del lado de datos (pasó de 5 a 31
      calendarios en `booking_calendar_ids` de V8, con nombres que sí corresponden a filas reales
      del catálogo). Pero verificado en BD, esos nombres corresponden a **`ID_KB`** (la clave
      interna de la fila, ej. `REC-015`), no a **`ID_RECURSO`** (el código real del camión que
      conoce el cliente y que usa el resto del catálogo, ej. `TP-94` — misma fila, columna
      distinta). Por eso "agenda del TP-94" nunca calza con el calendario "REC-015" aunque sea la
      misma unidad. Ya existe un mapeo 1:1 consistente en los datos (`ID_KB` ↔ `ID_RECURSO` ↔
      calendario) — solo falta que el código lo use en vez de fiarse del nombre del calendario en
      Google (frágil: cualquiera lo puede renombrar).
      **Arreglo propuesto**: usar el mecanismo ya construido en el pendiente de arriba (columna
      `CALENDAR_ID` por fila + `Cases::Ai::ResourceMatcher`) para TODOS los camiones reales del
      catálogo, no solo las 2 filas de prueba — así la resolución es por `ID_RECURSO` real,
      independiente de cómo esté nombrado el calendario en Google.
      **Progreso (2026-08-31)**: se armó el mapeo real completo — el `summary` de cada calendario en
      Google (vía `GoogleCalendarService#list_calendars`) es literalmente el `ID_KB` de su fila
      (ej. calendario "REC-015" ↔ fila `ID_KB=REC-015`/`ID_RECURSO=TP-94`), así que la
      correspondencia se resolvió por código sin adivinar: **24 de los 31 calendarios del pool**
      matchearon 1:1 contra las 24 filas `RECURSO` reales del catálogo (`REC-001..REC-024` →
      `TP-64, TP-63, TP-82...`). Los 7 restantes (`CFG-001`..`CFG-007`, sí están en el pool) no
      matchean ningún `ID_KB` del catálogo — sin identificar todavía qué son. El calendario
      *primary* de la cuenta (summary `TP-99`, no está en el pool) tampoco se tocó.
      **🔴 Bloqueador encontrado (no es de código, es de PERMISOS): la columna `CALENDAR_ID` no
      existe en la hoja real** — las 2 filas de prueba (`HIAB-TEST-1/2`) la tienen solo porque se
      agregó a mano en `google_sheet_rows.data` (BD), directamente, nunca vía la hoja de Google. Esa
      tabla es un ESPEJO: `GoogleSheetSyncJob#sync_data_mode` hace `delete_all` + re-inserta desde la
      hoja real en cada sync (botón "Sincronizar ahora") — cualquier valor puesto solo en la BD se
      pierde en el próximo sync, sin avisar. Hay que escribir `CALENDAR_ID` en la HOJA REAL (fuente
      de la verdad), como columna nueva (la real tiene 29 columnas hoy, `CALENDAR_ID` iría en la 30,
      `AD`). Pero el token de esta integración fue autorizado con scope
      `spreadsheets.readonly` (verificado contra la API de Google, `tokeninfo`) — escribir devuelve
      403 pase lo que pase en el código. Cambiado `CALENDAR_SCOPES`
      (`app/controllers/api/v1/accounts/google_calendar/authorizations_controller.rb:12`) a
      `spreadsheets` (lectura+escritura) — pendiente que alguien **reconecte Google Calendar desde
      la UI** (Ajustes → integraciones) para que el nuevo token tenga el scope de escritura; recién
      ahí se puede escribir el `CALENDAR_ID` de las 24 filas reales en la hoja.
      **✅ Destrabado y completado (2026-09-03)**: el usuario reconectó Google Calendar desde la UI
      (misma cuenta, `camion01kontrolya@gmail.com`) — verificado contra `tokeninfo` de Google que el
      nuevo token ya trae el scope `spreadsheets` completo. Al recalcular el mapeo con los
      calendarios actuales salió **mejor de lo esperado: 31 de 31 calendarios matchearon** (antes
      24/31 — se habían agregado más calendarios desde el cálculo anterior), de los cuales 24 son
      camiones reales (`RECURSO`) y 7 son configuraciones (`CFG-001..CFG-007`, sin unidad física,
      no reciben calendario). Se encontró un obstáculo adicional no documentado antes: la hoja
      tenía el **grid fijado exactamente en 29 columnas** — escribir en la columna 30 (`AD`) daba
      `400 Invalid data: exceeds grid limits` hasta expandir el grid primero
      (`spreadsheets:batchUpdate` con `appendDimension`, estructural, no toca datos existentes).
      Con eso resuelto: se escribió el encabezado `CALENDAR_ID` (`AD1`) + los 24 valores reales
      (`AD2`..`AD25`) en la hoja real, en una sola llamada `update_cells` (25 celdas). Se
      resincronizó (`GoogleSheetSyncJob`) y se verificó en BD: `google_sheet_rows` ya trae
      `CALENDAR_ID` poblado en las 24 filas `RECURSO` reales. `Cases::Ai::ResourceMatcher` ya tiene
      datos reales para resolver — pendiente probarlo end-to-end con un camión real (no las 2 filas
      de prueba `HIAB-TEST-1/2`, que siguen siendo las únicas ejercitadas hasta ahora).
      **🔴 Bug preexistente encontrado al investigar 2a (ARREGLADO 2026-08-31), afecta a CUALQUIER
      hoja de la cuenta con más de 26 columnas, no solo esta**: `GoogleSheetsService::DEFAULT_RANGE`
      estaba fijo en `'A1:Z2000'` — la hoja real de GRUAS tiene **29** columnas; las 3 últimas
      (`DATOS_FALTANTES`, `REGLA_ESCALAMIENTO` y **`TEXTO_KB`** — el texto narrativo completo de cada
      recurso, ej. "Recurso TP-64: CAMA BAJA / LOWBOY... Antes de seleccionar validar: altura de
      cama/piso...") se recortaban en silencio en cada sync, nunca llegaban a `google_sheet_rows` ni
      al agente. Fix: `GoogleSheetsService#full_range` calcula el rango real desde
      `sheet_metadata(file_id)['gridProperties']['columnCount']` (nueva llamada a la API de Sheets),
      con fallback al rango fijo de antes si la metadata falla. Se agregó también
      `update_cells` (batchUpdate, escribe N celdas en una sola llamada) — usa el scope de escritura
      de arriba, todavía sin ejercitar (pendiente la reconexión). Archivos:
      `app/services/google_sheets_service.rb`. Probado leyendo la hoja real: las 29 columnas ya
      llegan completas. **Falta correr una sincronización real** (`GoogleSheetSyncJob`) para que el
      fix llegue a `google_sheet_rows`/la búsqueda semántica en producción — no se disparó todavía
      porque cambia el contexto real que ve el agente ahora mismo, se dejó para confirmar antes.

- [x] ~~**2b — La resolución recurso→calendario solo actúa con 2+ recursos, hace falta también con
      1**~~ ✅ **HECHO e implementado (2026-08-31)** — conv. #56: el cliente pidió UNA sola unidad
      ("HIAB con capacidad de 12 toneladas") y aun así se agendó contra el pool genérico de 31
      calendarios (al azar, `REC-020`), sin intentar resolverla contra el catálogo — porque
      `resources_requested` (`Cases::Ai::Intake`/`TicketCreatorService`) solo se activaba con 2 o
      más recursos nombrados; con 1 solo caía al camino normal, que no intentaba ningún
      emparejamiento.
      **Arreglo implementado**: `Cases::Ai::ResourceMatcher` no necesitó cambios (`match()` ya
      aceptaba un array de 1). Los dos cambios fueron:
      - `Cases::Ai::Intake` — el prompt de `resources_requested` pasó de exigir "DOS O MÁS" recursos
        a "UNO O MÁS" (siempre que sea concreto: "HIAB con capacidad de 12 toneladas" cuenta, "una
        grúa" sola no).
      - `TicketCreatorService#resources_requested` — con exactamente 1 descripción, en vez del
        camino de §3 (split de ticket) llama a `scope_tracking_to_single_resource`: si el catálogo
        lo resuelve, acota `booking_calendar_ids` del tracking ACTUAL al calendario de ESE recurso
        (mismo mecanismo que ya usa `spawn_resource_tracking`/`booking_calendars_for` — cero pieza
        nueva) y el turno sigue el camino normal (un solo ticket, sin `ContactTracking` hijo). A
        diferencia de §3, si NO se resuelve **no escala** — simplemente no hace nada y sigue el
        comportamiento de siempre (pool genérico), porque con 1 solo recurso no hay dato que se
        pierda por no resolverlo. Archivos: `app/services/cases/ai/intake.rb`,
        `app/services/cases/ticket_creator_service.rb`.
      **✅ Probado end-to-end (2026-08-31)** con el mensaje REAL de la conv. #56 ("HIAB con capacidad
      de 12 toneladas... de Centro a Paraíso") contra el catálogo real de `CATALOGO GRUAS VIKA NVO`
      (mismo `tracking_template` GRUAS V8), sobre conversación/contacto de prueba en el inbox
      `GRUAS API TEST`: el intake devolvió `resources_requested: ["HIAB con capacidad de 12
      toneladas"]`, `ResourceMatcher` lo resolvió contra `HIAB-TEST-2` (fila de prueba, 12T,
      `CALENDAR_ID: camion01kontrolya@gmail.com`), `booking_calendar_ids` del tracking quedó acotado
      a ese único calendario, y la oferta de horarios posterior (`handle_book_appointment`) ya NO
      mostró el pool genérico de 31 calendarios con nombres internos confusos — ofreció horarios
      solo de ese recurso.
      **Limitación heredada de 2a (no resuelta por este fix)**: la prueba usó las 2 filas `RECURSO`
      de prueba (`HIAB-TEST-1/2`), que ya tienen `ID_RECURSO`+`CALENDAR_ID` bien poblados. Los 31
      calendarios reales de producción todavía están mapeados por `ID_KB` (no por `ID_RECURSO`) —
      hasta que 2a complete ese dato para los camiones reales, este fix no tiene con qué resolver un
      pedido real de un solo camión (sí sigue sin regresión: cae al comportamiento de siempre).

- [x] ~~**3a — Router liviano (alcance mínimo): detectar y resolver una pregunta técnica
      embebida en la misma solicitud**~~ ✅ **HECHO (2026-08-31), alcance mínimo — ver punto 1
      arriba, es la MISMA implementación** — mismo caso que el punto 1, visto desde el ángulo de
      "falta un M1 Router real" (ver comparación previa contra el plan "arquitectura
      determinista"): hoy no hay ninguna clasificación de intención antes de actuar — gana el
      primer paso del pipeline fijo (`@estado_ticket` → `TicketCreatorService` → clasificación de
      cita → KBase → conversación libre) que "atrapa" el turno, no el que mejor entienda qué pidió
      el cliente. El "cambio a considerar (mínimo, mismo patrón que `needs_escalation`/
      `multiple_requests`)" que este punto ya proponía es exactamente lo que se implementó en el
      punto 1: señal `pending_technical_question` en el intake + resolución vía KBase en
      `ContactTrackingResponseAnalyzerJob#offer_appointment_or_resolve_question` antes de ofrecer
      agenda.
      **Sigue pendiente (alcance mayor, de fondo, NO cubierto por lo de arriba)**: un M1 Router
      real como paso de código explícito antes de todo lo demás en
      `contact_tracking_response_analyzer_job.rb` — la reescritura hacia "arquitectura
      determinista" completa. Ya existe `@ruta`/`BranchClassifierService` (traído de
      `origin/fix/test_agentes_ia`) que hace clasificación de intención con LLM, pero está pensado
      para elegir ENTRE FUENTES de conocimiento (ramas), no para esto — se podría extender. Lo
      implementado hoy es un parche puntual (una señal más del intake), no reemplaza esta
      reescritura de fondo si se decide encararla.

- [ ] **3b — El anti-duplicado de tickets no distingue "mismo caso" de "necesidad nueva" — una vez
      que hay ticket abierto, el bot queda sordo a cualquier otra cosa (guard anti-loop
      implementado 2026-08-31, causa de fondo sigue pendiente)** — hallazgo NO reportado
      por el usuario, encontrado al revisar conv. #56: después de agendada la cita, tres mensajes
      distintos del cliente ("me pasas agenda de REC-015", "quiero saber agenda de REC-015",
      "quiero un nuevo ticket" — este último EXPLÍCITO) recibieron la **misma respuesta doble**
      sin excepción:
      ```
      Ya tienes el caso RU-00019 en curso; sumé tu mensaje a ese caso...
      Ya tenés una cita agendada... ¿moverla o cancelarla?
      ```
      Causa: `reuse_existing_ticket` (`TicketCreatorService#create_if_needed`) corre ANTES que
      cualquier otra cosa — apenas encuentra un ticket abierto del contacto, corta el turno ahí
      mismo. Esto significa que `needs_escalation`, `multiple_requests` y `resources_requested`
      (todo lo construido hoy) **nunca vuelven a evaluarse** una vez que existe un ticket, aunque
      el cliente pida algo totalmente distinto — ni siquiera un "quiero un nuevo ticket" explícito
      lo destraba. El doble mensaje en sí (ticket-linked + estado-de-cita) tampoco contesta ninguna
      de las dos preguntas reales del cliente.
      **✅ Mitigación implementada (2026-08-31)**: guard anti-loop por Redis, mismo patrón que
      `MAX_FIELD_ASKS`/`pending_key` (§6). No clasifica intención — corta la repetición por conteo:
      - `TicketCreatorService` — `MAX_LINKED_REPEATS = 2` + `linked_repeat_key(conversation_id)`.
        `reuse_existing_ticket` ahora cuenta cuántas veces seguidas se repitió "ya tienes un caso en
        curso"; al llegar al límite, en vez de repetir el mismo texto una vez más, escala
        (`escalate_linked_existing` reusa `send_escalation_confirmation`, el mismo mensaje fijo de
        hand-off que ya usa §1) con `outcome = :escalated_repeat` (fuera de
        `%i[created linked_existing]`, así el job no vuelve a ofrecer/recordar la cita en el mismo
        turno).
      - `ContactTrackingResponseAnalyzerJob#inform_existing_appointment` — mismo patrón,
        `MAX_APPOINTMENT_QUERY_REPEATS = 2` + `appointment_query_repeat_key(tracking_id)`. Al
        agotarse, `escalate_appointment_query` avisa al cliente, y sigue el patrón ya existente de
        `handle_no_calendar_configured` (`pause!` + `notify_admin_interested` + `create_private_note`).
      Archivos: `app/services/cases/ticket_creator_service.rb`,
      `app/jobs/contact_tracking_response_analyzer_job.rb`.
      **✅ Probado end-to-end (2026-08-31)**: réplica aislada del estado de la conv. #56 (mismo
      `tracking_template` GRUAS V8, ticket abierto + cita ya agendada) sobre un contacto/conversación
      de prueba en el inbox `GRUAS API TEST` (Channel::Api, sin dispatch externo real). Resultado
      determinístico en ambos guards: turnos 1–2 repiten el mensaje fijo, turno 3 escala
      (`outcome = :escalated_repeat` / mensaje de hand-off), y el contador se resetea después de
      escalar — verificado también por rebote vía el job real (Sidekiq activo en este entorno,
      `Message.create!` encola `ContactTrackingResponseAnalyzerJob` — `app/models/message.rb:474`),
      mismo patrón 2+1 confirmado de forma independiente en el log.
      **🔴 Bug preexistente encontrado al probar (ARREGLADO 2026-08-31), afectaba TODA escalada del
      job, no solo este guard**: `notify_admin_interested` y `create_private_note` fallaban
      silenciosamente (cada una con su propio `rescue` que traga el error) — confirmado también en
      tráfico real no relacionado (tracking #2857, flujo de "cita confirmada" ya existente), así que
      no era un problema nuevo de este guard sino algo que ya rompía `handle_no_calendar_configured`
      y el aviso post-booking. Dos causas:
      - `notify_admin_interested`: `account.users.where(role: :administrator)` — `role` vive en la
        tabla intermedia `account_users`, no en `users` → `PG::UndefinedColumn`. Fix: reusar el
        helper ya existente `Account#administrators` (`account.rb:121`).
      - `create_private_note`: llamaba `Messages::MessageBuilder.new(user: ..., conversation: ...)`
        con keywords, pero `MessageBuilder#initialize(user, conversation, params)` solo acepta
        posicionales → `ArgumentError`. Fix: mismo estilo posicional que el resto de los call sites
        del archivo.
      Verificado post-fix: la conversación se asigna al admin, se crea la `Notification`, y la nota
      privada se registra. Antes de este fix, "escalar a un humano" en este job nunca dejaba rastro
      más allá del mensaje que ve el cliente en el chat.
      **Sigue pendiente (causa de fondo, sin implementar)**: el guard corta el loop pero no entiende
      lo que pide el cliente — sigue sin contestar "dame la agenda de REC-015" ni distinguir "esto
      es sobre el mismo caso" de "esto describe una necesidad distinta"; solo evita el bucle infinito
      y garantiza que un humano se entere tras 2 repeticiones. La solución real sigue siendo la
      clasificación liviana **antes** de `reuse_existing_ticket` (puede ser la MISMA señal de 3a,
      reutilizada) — si es distinta, no reusar ciegamente. Toca lógica compartida por todas las
      cuentas — probar que no rompe el caso normal (cliente que solo quiere agregar info a su caso
      ya abierto, que sí debe seguir funcionando como hoy).

### Pruebas con corpus real de SSUSA sobre `AGENTE GRUAS V9` (2026-09-03, `gpt-4o` + sin `fallback` + catálogo real sincronizado)

Con el modelo cambiado a `gpt-4o`, `fallback=true` revertido y el catálogo real ya sincronizado en
modo Datos, se corrieron 8 mensajes reales tomados del buzón de SSUSA (no inventados). 5 de 8 ya
crean ticket real — mejora grande — pero salieron 3 hallazgos nuevos más el ya conocido de la
agenda prematura, ahora confirmado independiente de todo lo anterior.

- [x] ~~**`needs_escalation` le gana el turno a `multiple_requests`/`resources_requested` y puede
      volver a perder datos**~~ ✅ **HECHO e implementado (2026-09-03)** — descubierto con un
      mensaje real (cliente pide cotizar 2 equipos "por separado": una plataforma Haulotte y una
      Zoomlion). El ticket creado (`custom_attributes: {"ai_intake": {...}}`, sin la marca
      `multiple_requests`) **solo mencionaba el primer equipo — el segundo desaparecía del todo**,
      el mismo bug de pérdida de datos que ya habíamos arreglado, reaparecido por otra puerta.
      Causa: en `TicketCreatorService#create_if_needed`, `needs_escalation?` se chequeaba ANTES que
      `multiple_requests?`/`resources_requested(fields)`; cuando el intake marcaba ambas señales
      true para el mismo mensaje, ganaba la genérica (`needs_escalation`), que arma el ticket con
      el `description` resumido normal — no con el resumen que lista cada solicitud.
      **Arreglo implementado**: en `create_if_needed`, se movió el chequeo de `multiple_requests?`
      y `resources_requested(fields)` ANTES que `needs_escalation?` (las señales estructurales/con
      manejo de datos dedicado ganan sobre la genérica). Archivo:
      `app/services/cases/ticket_creator_service.rb` (solo reordenar 3 llamadas, sin lógica nueva).
      **✅ Probado (2026-09-03)** con el mismo mensaje real: el ticket ahora sale con
      `custom_attributes: {"multiple_requests": true}` y el mensaje correcto ("Detecté que se
      trata de varios servicios independientes..."). **Limitación menor residual**: la descripción
      lista los 2 ítems (ya no se pierde ninguno), pero el resumen del 2º a veces sale genérico
      ("el segundo equipo" en vez del nombre/peso reales) — no es pérdida de dato real (la
      conversación completa queda vinculada al ticket), solo una mejora de redacción pendiente.

- [x] ~~**El marcador "N/A" se está usando de más — puede descartar datos que el cliente sí
      dio**~~ ✅ **HECHO e implementado (2026-09-03)** — en el mismo lote de pruebas, un ticket
      había quedado con `"material": "No aplica"` y `"ubicacion_recogida": "No aplica"` cuando el
      cliente SÍ había dado ambos (una "unidad inyectora" y "patio de OLAM Energy en Paraíso"). Es
      el riesgo inverso al que resolvimos antes: el "N/A" debe usarse solo cuando el dato
      genuinamente no aplica a la solicitud, no cuando el modelo simplemente no está seguro de
      haberlo extraído bien.
      **Arreglo implementado**: se reforzó la regla del `system_prompt` en
      `Cases::Ai::FieldExtractor` — "NUNCA uses N/A si el cliente mencionó CUALQUIER valor para ese
      campo, aunque no estés seguro de haberlo identificado bien — en ese caso extraé el valor tal
      cual lo dio". Archivo: `app/services/cases/ai/field_extractor.rb` (ajuste de texto, mismo
      patrón que el marcador ya implementado). Pendiente de una prueba dedicada a este caso puntual
      (no se volvió a probar el mensaje exacto de OLAM tras el cambio); sí se confirmó que el N/A
      correcto de casos anteriores (maniobra sin destino) no se vio afectado en las pruebas de
      re-verificación de este mismo lote.

- [x] ~~**La regla de "duración distinta a 2 horas" solo se detecta cuando es MÁS larga, no cuando
      es más corta**~~ ✅ **HECHO e implementado (2026-09-03)** — dos mensajes reales comparables:
      uno pedía una jornada de 16 horas → escaló correctamente citando la duración; otro pedía un
      servicio de "aproximadamente una hora" → NO escalaba, se creaba el ticket y se agendaba una
      cita de 2 horas normal, sin ningún aviso del descalce. El modelo asociaba "duración distinta
      a 2h" solo con jornadas largas, no con servicios más cortos que el estándar.
      **No fue un cambio de código** — la regla de "2 horas fijas" vive en el prompt del Agente IA
      (`tracking_templates.complementary_prompt` de GRUAS, id 3682/V9, no en un archivo del repo),
      porque `Cases::Ai::Intake` es código compartido por todas las cuentas y no puede tener "2
      horas" cableado. **Arreglo implementado**: se reforzó el texto de M0, el disparador de
      escalamiento y "FUERA DE ALCANCE" en el prompt de GRUAS V9 con el matiz explícito "MÁS LARGA
      (8/12/16/24h) O MÁS CORTA (ej. una hora, 30 minutos)" en los 3 lugares que mencionaban la
      regla de 2 horas.
      **✅ Probado (2026-09-03)** con el mismo mensaje real (grúa 80 ton, "duración aproximada de
      una hora"): ahora escala correctamente citando "El cliente solicita una duración de servicio
      distinta a las 2 horas estándar."

- [ ] **Con fecha/hora explícita, el clasificador de citas salta directo a ofrecer horarios sin
      pasar por recolección de datos ni ticket** — confirmado en 2 rondas de prueba distintas
      (antes y después de todos los cambios de hoy), con un mensaje real de Baker Hughes:
      "confírmame la disponibilidad de la grúa 40T el domingo a las 10am" (sin material, peso ni
      ubicación de trabajo). El bot responde directo con horarios disponibles — nunca pasa por
      `@estado_ticket` ni `@crear_ticket`, nunca se crea un caso. Es independiente de todos los
      arreglos de hoy (`fallback`, modelo, modo de hoja): la clasificación de cita
      (`ContactTrackings::RouterService`/`classify_appointment`, "acción de cita ya clasificada")
      corre ANTES en la cascada que la creación de ticket, y decide "quiere agendar" con solo ver
      fecha+hora, sin verificar si ya existe un caso con los datos base recolectados.
      **Arreglo propuesto**: condicionar el salto directo a agenda — solo permitirlo si (a) el
      agente no tiene `@crear_ticket` en su prompt (agendamiento puro, sin intake), o (b) ya existe
      un ticket/caso abierto para el contacto (o sea, los datos base ya se recolectaron en un turno
      anterior). Archivo: `app/jobs/contact_tracking_response_analyzer_job.rb` (el gate de "acción de
      cita ya clasificada" antes de `@estado_ticket`/`@crear_ticket`). Toca lógica compartida por
      todas las cuentas — con cuidado de no romper agentes que SÍ son de agendamiento puro sin
      ticket (ver receta "Agente de agenda" del manual del motor).

      **Confirmación mucho más grave (conv. display #116, 2026-09-04, prueba de `AGENTE GRUAS
      V10`)**: se probó primero una pregunta suelta de disponibilidad ("¿Tienen disponibilidad para
      mañana en la tarde?") — como se esperaba, el bot ofreció agenda de inmediato (mismo bug de
      arriba). Pero el mensaje SIGUIENTE, con TODOS los datos de un servicio nuevo (bomba industrial
      18T, medidas, origen, destino, fecha), en vez de iniciar `@crear_ticket`, **fue interpretado
      como una propuesta de fecha/hora para el horario ya ofrecido** — el bot extrajo solo "lunes por
      la mañana" del mensaje, ignoró el resto, y **confirmó una cita real en Google Calendar sin
      haber creado ningún ticket**. Los datos de la bomba (peso, medidas, origen, destino) se
      perdieron por completo — no quedaron en ningún ticket ni registro.
      **Causa raíz encontrada**: al ofrecer agenda, el tracking queda marcado con un estado interno
      `[PENDING_SLOT]` en `ai_context`. Ese estado se revisa en `pending_slot_selection?`
      (`contact_tracking_response_analyzer_job.rb`), que corre **primero que cualquier otra cosa en
      la cascada** (antes del router, antes de `@crear_ticket`, antes de la KBase) — así que
      CUALQUIER mensaje siguiente, sin importar su contenido, se interpreta únicamente como "el
      cliente está eligiendo o proponiendo un horario" (`handle_slot_negotiation`), nunca como una
      solicitud nueva. El disparo original del estado es el mismo de siempre:
      `ContactTrackings::RouterService` (clasificador de citas genérico, pensado para agentes de
      agenda pura) define "book_appointment" con ejemplos como *"cuándo tienen disponibilidad"* —
      calza con la pregunta suelta y dispara `handle_book_appointment`/`offer_slots` sin saber que
      GRUAS necesita ticket + validación primero.
      **Gravedad**: esto es peor que "salta directo a la agenda" — una vez que `[PENDING_SLOT]`
      queda activo, el flujo normal de ticket es **inalcanzable** hasta que la negociación de
      horario se resuelva, y puede terminar en una cita real agendada sin ticket, con pérdida
      silenciosa de los datos del servicio.
      **Arreglo propuesto (mismo que arriba, con más urgencia)**: que `classify_appointment`/
      `dispatch_appointment_action` no disparen `book_new` cuando la cuenta tiene `@crear_ticket`
      configurado y el contacto no tiene todavía un ticket abierto — en ese caso, tratar el mensaje
      como inicio de `ROUTER - TICKET`, no como agenda. Riesgo cross-cuenta: bajo, la condición exige
      `@crear_ticket` presente, así que no toca cuentas de agenda pura sin ticket.

### Prueba real vía Telegram (conv. display #109, 2026-09-03) — hallazgo nuevo, más de fondo que los anteriores

- [ ] **🔴 La agenda ofrecida no verifica si el recurso puede cumplir el requisito técnico —
      M5 (recomendación) y M6 (disponibilidad) están desconectados** — el usuario probó en Telegram
      real (no canal API) el mismo mensaje de la prueba P3 (grúa 80 ton para **izar** un inyector de
      26 toneladas sobre una cama baja). El bot creó el ticket y ofreció 5 horarios de los
      calendarios `REC-005/020/015/021/013`. Se verificaron los 5 recursos reales detrás de esos
      calendarios contra el catálogo:
      ```
      REC-005 → TP-112 (remolque, PUEDE_IZAR: NO, plataforma plana)
      REC-013 → TP-74  (remolque, PUEDE_IZAR: NO, cama baja)
      REC-015 → TP-94  (remolque, PUEDE_IZAR: NO, plataforma plana)
      REC-020 → TP-53  (remolque, PUEDE_IZAR: NO, plataforma plana)
      REC-021 → TP-117 (remolque, PUEDE_IZAR: NO, góndola)
      ```
      **Los 5 son remolques — NINGUNO puede izar.** El cliente pidió una GRÚA para una maniobra de
      izaje; el remolque es el camión que RECIBE la carga, no el que la iza — son equipos distintos
      para el mismo trabajo, y el bot ofreció horarios del equipo que no hace la maniobra pedida.
      Causa doble:
      1. **Dato de negocio**: las 24 filas `RECURSO` reales del catálogo son TODAS remolques — las
         grúas/HIAB que se mencionan en los mensajes de prueba no existen todavía como inventario
         real, solo como conocimiento conceptual (`CONFIGURACION`/`CAMPO_REQUERIDO`/`REGLA_DECISION`).
         Sin datos de grúas reales, ningún código puede recomendar una correctamente.
      2. **Código**: incluso si existieran, `handle_book_appointment`/`slot_service_for`
         (`app/jobs/contact_tracking_response_analyzer_job.rb`) siempre ofrece contra el pool
         COMPLETO de `booking_calendar_ids` del template, salvo que el tracking tenga su propio
         `booking_calendar_ids` acotado — y eso solo pasa hoy vía `resources_requested`, cuando el
         cliente NOMBRA explícitamente 1+ recursos concretos (ej. "TP-94"). Cuando el cliente da
         especificaciones técnicas (peso, capacidad, necesidad de izaje) y espera que el sistema
         RECOMIENDE y agende la unidad correcta — como en este caso — no hay ningún paso que filtre
         el pool de calendarios por esas especificaciones antes de ofrecer horarios. M5
         ("validación técnica y recomendación de unidad") es puramente conversacional/textual; no
         alimenta a M6 con qué recursos califican.
      **Arreglo propuesto**: extender el mismo mecanismo ya construido (`Cases::Ai::ResourceMatcher`
      + `booking_calendar_ids` acotado por tracking) para que también se dispare a partir de los
      REQUISITOS técnicos extraídos (capacidad, `PUEDE_IZAR`, dimensiones), no solo cuando el
      cliente nombra una unidad — filtrando el catálogo real por esos campos antes de decidir qué
      calendarios ofrecer; si ningún recurso real califica (como pasa hoy con las grúas), debe
      escalar ("información insuficiente", M5) en vez de ofrecer calendarios de un equipo que no
      corresponde. Archivos: `app/services/cases/ai/resource_matcher.rb` (generalizar de "nombre
      exacto" a "requisitos técnicos"), `app/jobs/contact_tracking_response_analyzer_job.rb`
      (`slot_service_for`/`handle_book_appointment`). Requiere también el dato de negocio (dar de
      alta las grúas reales como filas `RECURSO`) — sin eso, el código no tiene con qué recomendar
      aunque el filtro exista.

      **Avance parcial (2026-09-03)**: el usuario cambió `CFG-005`/`CFG-006`/`CFG-007` de
      `TIPO_REGISTRO=CONFIGURACION` a `RECURSO` en la hoja real. Se resincronizó y se ligó
      `CALENDAR_ID` en las 3 filas (los 3 calendarios ya existían en el pool, coinciden por nombre
      exacto con cada código — no fue necesario crearlos). **Sigue faltando `ID_RECURSO`** (código/
      número económico real de la unidad física) y `CAPACIDAD_MAX_T` en las 3 — sin `ID_RECURSO`,
      `Cases::Ai::ResourceMatcher#catalog_resources` sigue descartando la fila (`next if
      id_recurso.blank?`), así que **no hay cambio funcional todavía**: las 3 filas siguen sin ser
      candidatas reales para el matching. El usuario confirmó (2026-09-03) que por ahora no cuenta
      con esos datos reales — queda en pausa hasta que SSUSA los proporcione; no se debe inventar
      `ID_RECURSO`/`CAPACIDAD_MAX_T` (mismo criterio que el resto del catálogo).

      **Confirmación adicional (conv. display #111, 2026-09-03) — el hueco NO es exclusivo de
      izaje/grúas**: el usuario probó un caso de transporte normal, sin izaje (compresor de 22T,
      10m x 2.3m, plataforma). El bot recolectó bien los datos y creó el ticket (`RU-00046`), pero
      al ofrecer horarios volvió a usar el pool COMPLETO sin filtrar:
      ```
      REC-005 → TP-112 (plataforma plana, 40.8T, 16.15m)  ✅ compatible
      REC-013 → TP-74  (cama baja, 40T, 12m)               ✅ compatible
      REC-015 → TP-94  (plataforma plana, 30T, 14.63m)     ✅ compatible
      REC-020 → TP-53  (plataforma plana, 30T, 12.19m)     ✅ compatible
      REC-021 → TP-117 (góndola/caja de volteo, 30T, 9.15m) ❌ NO compatible — es para material a
                                                                granel, no carga fija, y mide menos
                                                                que la carga (9.15m < 10m)
      ```
      4 de 5 resultaron compatibles por coincidencia (capacidades/largos similares entre
      plataformas), pero confirma que el filtro no existe para NINGÚN tipo de servicio, no solo
      para grúas: el sistema ofreció una góndola de volteo para cargar un compresor rígido sin
      ninguna validación de tipo ni de largo. Refuerza que el arreglo propuesto arriba
      (`ResourceMatcher` por requisitos técnicos, no solo por nombre) aplica de forma general, no
      solo al caso de izaje.

      **Confirmación adicional #2 (conv. display #112, 2026-09-03) — contradicción interna entre
      M5 y M6, no solo "no filtra"**: caso de maniobra pura (bomba de 15T dentro del mismo patio).
      El bot creó el ticket y ofreció agenda del pool completo (`REC-005/020/015/021/013` →
      `TP-112/TP-53/TP-94/TP-117/TP-74`) sin que el cliente hubiera pedido recomendación todavía.
      Cuando el cliente preguntó "¿qué camión me ayudaría?", el bot SÍ consultó bien el catálogo
      (M1: consulta técnica aislada) y recomendó **TP-64, TP-63, TP-58** (low boy/cama baja, 40-60T)
      como las ideales — unidades que no aparecen entre las 5 que ya había ofrecido para agendar. Al
      responder el cliente "es la que te di antes", el bot repitió la MISMA agenda original sin
      reconciliarla con su propia recomendación. Confirma que el texto de M5 (recomendación) y los
      calendarios de M6 (disponibilidad) no comparten ninguna fuente de datos — pueden literalmente
      contradecirse entre sí dentro de la misma conversación, lo cual es peor que solo "no filtrar":
      el cliente puede notar la inconsistencia directamente. Nota aparte, positiva: la regla de
      "N/A" (fix de field_extractor) funcionó bien aquí — no preguntó una segunda ubicación/destino
      para la maniobra de un solo sitio.

### Prueba real vía Telegram sobre `AGENTE GRUAS V10` (conv. display #116, 2026-09-04) — hallazgo nuevo

- [ ] **🟡 Con un ticket ya abierto, una pregunta técnica pura se traga como "ya tienes un caso" en
      vez de contestarse** — en la misma conversación de la confirmación del bug de agenda prematura
      de arriba, con un ticket ya abierto (por escalamiento), el cliente preguntó dos veces "¿cuál es
      la capacidad máxima de la TP-94?" — ambas veces el bot respondió solo "Ya tienes el caso...
      en curso; sumé tu mensaje a ese caso", sin contestar la pregunta técnica.
      **Causa**: `TicketCreatorService#reuse_existing_ticket` corre y decide vincular el mensaje al
      caso abierto SIN revisar antes si el mensaje es en realidad una pregunta técnica/de catálogo
      sin relación con el ticket — el mecanismo que sí resuelve esto (`pending_technical_question`/
      `resolve_pending_technical_question`, ver punto 1/3a más arriba) solo se activa cuando se está
      creando o reusando el ticket con outcome `:created`/`:linked_existing` y encima el intake
      corrió; hoy el camino de `reuse_existing_ticket` no le da a la KBase ninguna oportunidad de
      contestar antes de mandar el boilerplate.
      **Arreglo propuesto**: antes de enviar la confirmación de "ya tienes un caso" en
      `reuse_existing_ticket`, intentar resolver la pregunta por la KBase primero (mismo patrón que
      `pending_technical_question`, extendido para que también aplique cuando YA hay un ticket
      abierto, no solo al crearlo) — si la KBase contesta, no mandar el boilerplate ese turno; si no,
      caer al comportamiento actual. Archivos: `app/services/cases/ticket_creator_service.rb`
      (`reuse_existing_ticket`), posiblemente `app/jobs/contact_tracking_response_analyzer_job.rb`.
      Riesgo cross-cuenta: bajo-medio — solo cambia el comportamiento cuando ya hay un ticket abierto
      y la cuenta tiene una fuente de KBase configurada; mejora el caso para cualquier cuenta así, no
      le veo downside conocido.
      **Nota de contexto (no es un tercer bug)**: en la misma conversación, un mensaje nuevo y
      genuinamente independiente ("mover una excavadora...") se clasificó como `multiple_requests`
      junto con la solicitud de la bomba de la prueba anterior — probablemente porque el bug de
      arriba dejó la solicitud de la bomba sin ticket, y el intake (que lee la conversación completa)
      vio dos servicios "sueltos" sin resolver y los trató como independientes. Es una consecuencia
      encadenada del bug de agenda prematura, no un hallazgo nuevo de clasificación.

- [x] **✅ Arreglado (2026-09-03, conv. display #113)**: caso escalado por `multiple_requests`
      seguía ofreciendo agenda automática en el turno siguiente, contradiciendo su propio mensaje
      de escalamiento. Causa: `reuse_existing_ticket` (`ticket_creator_service.rb`) devuelve
      `:linked_existing` sin distinguir si el ticket reusado fue originalmente un caso normal o uno
      escalado por `multiple_requests` (que sí guarda `custom_attributes: {'multiple_requests' =>
      true}`), y `try_create_ticket` (`contact_tracking_response_analyzer_job.rb`) ofrece agenda
      para CUALQUIER `:linked_existing`.
      **Arreglo**: se expuso `attr_reader :linked_ticket` en `TicketCreatorService` (seteado en
      `reuse_existing_ticket` cuando el outcome es `:linked_existing`), y el job ahora no ofrece
      agenda si `creator.linked_ticket.custom_attributes['multiple_requests']` es true. Cambio
      acotado a ese único chequeo — bajo riesgo cross-cuenta, solo afecta casos ya marcados como
      escalados por multiservicio, donde ninguna cuenta espera que se siga ofreciendo agenda.
      Probado directamente (ticket con `custom_attributes: {'multiple_requests' => true}` + mensaje
      de seguimiento): antes del fix ofrecía agenda, después del fix solo confirma "un asesor te
      contactará", sin agenda. También se probó la variante intacta del flujo normal
      (`resources_requested`/`split_by_resource`, TP-94+TP-37 mismo trabajo) para confirmar que no
      se rompió: sigue generando un ticket y una cita independiente por recurso.

      **🔴 Bug encontrado en Telegram real (conv. display #132, 2026-09-04) — ARREGLADO el mismo
      día**: el ticket se creaba bien (folio, título, `id_recurso`/`calendar_id` correctos) pero
      **sin ninguno de los campos obligatorios del tipo de caso** (`material`, `ubicacion_recogida`,
      `ubicacion_destino`, `peso` — los 4 configurados en "RENTA UNIDADES"). Causa: el flujo normal
      llama a `resolve_type_and_fields(fields)` (vía `request_missing_fields`) ANTES de
      `build_ticket`, dejando `@field_values` listo para que `intake_custom_attributes` los
      incluya — `create_after_appointment` (Fase 3) llamaba a `build_ticket` directo, sin ese paso,
      así que `@field_values` quedaba vacío. **Arreglo**: agregar la misma llamada a
      `resolve_type_and_fields(fields)` antes de `build_ticket` en `create_after_appointment`.
      Probado con el mismo caso real (compresor 15T, Dos Bocas → Paraíso): el ticket ahora sale con
      `material`, `peso`, `ubicacion_recogida`, `ubicacion_destino` completos, además de
      `id_recurso`/`calendar_id`.
      Nota aparte (no arreglada, es variabilidad del LLM ya documentada): en la prueba original
      #113 el intake clasificó esa misma solicitud (2 unidades nombradas, mismo trabajo, misma
      ubicación) como `multiple_requests` en vez de `resources_requested`, a pesar de que la regla
      escrita en `Cases::Ai::Intake` ya cubre ese caso explícitamente ("...incluido un solo trabajo
      que necesita varios recursos/unidades a la vez"). Es el mismo patrón de no-determinismo del
      LLM visto antes con escalamiento/duración — no se tocó el prompt por esto todavía.

### Plan: nueva directiva `@disponibilidad_recurso` (agenda acotada por recurso/requisitos) — 🟡 EN PROGRESO (2026-09-04)

**Fase 1 ✅ HECHA y probada (2026-09-04)**: `Cases::Ai::ResourceMatcher` — `find_by_name(nombre)`
(coincidencia exacta por `ID_RECURSO`/`NOMBRE`, `nil` si no existe) y `match_by_requirements(reqs)`
(filtra por `CAPACIDAD_MAX_T`/`PUEDE_IZAR`/`LARGO_M`/`ANCHO_M`; un campo sin dato en el catálogo
para un requisito SÍ pedido excluye el recurso — nunca asume que cumple). Probado contra el
catálogo real: 22T + sin izaje + 10m de largo → 23/24 unidades califican, excluye correctamente
`TP-117` (la góndola de 9.15m que en la conv. #111 se había ofrecido mal). Con izaje requerido → 0
matches (ninguna unidad real puede izar hoy — confirma que ahí falta dato de negocio, no código).
**Fase 2 ✅ HECHA y probada (2026-09-04)**: directiva `@disponibilidad_calendar` (nombre elegido con
el usuario — consistente con `@agendar_calendar`, sin colisión de regex). `ResourceMatcher
#resolve_for_availability` (extracción liviana vía LLM de nombre/requisitos + resolución) y
`ContactTrackingResponseAnalyzerJob#try_resource_availability` (engancha ANTES de `@crear_ticket` y
del `@agendar_calendar` genérico, justo después de `@estado_ticket`). Opt-in total: solo actúa si el
prompt trae `@disponibilidad_calendar` — **hoy V9/V10 no la tienen, así que este cambio queda
dormido y no afecta ninguna prueba ya corrida**. Probado con un agente de prueba aislado (no V10):
- Nombre exacto (TP-94) → solo su calendario (REC-015). ✅
- Requisitos (10T, sin izaje) → disponibilidad combinada de las unidades que califican. ✅
- Requisitos con izaje (15T) → 0 matches, mensaje pidiendo más datos en vez de ofrecer algo que no
  sirve (correcto, sin unidades de izaje reales todavía). ✅
- Mensaje irrelevante ("Hola, ¿cómo estás?") → NO toma el turno, deja seguir la cascada normal. ✅
- Nombre inexistente (TP-999) SIN requisitos dados → inicialmente cayó a mostrar el pool completo
  (mismo bug que se busca evitar) — corregido: ahora responde pidiendo más datos en vez de asumir
  que "sin requisitos" califica a todos. Nombre inexistente CON requisitos sí recomienda similares
  correctamente (comportamiento acordado con el usuario).

**🔴 Bug encontrado en Telegram real (conv. display #130, 2026-09-04) — ARREGLADO el mismo día**:
al pedir disponibilidad de TP-64, mostró correctamente solo su calendario (`REC-001`). Pero al
insistir "para el jueves no tienes disponible?", el bot volvió a ofrecer el POOL COMPLETO
(`REC-005/020/015/021/013`) en vez de seguir acotado a TP-64. Causa: `offer_resource_availability`
armaba el `booking_calendars` acotado y se lo pasaba directo a `AvailabilitySlotService`, pero
NUNCA lo guardaba en `tracking.booking_calendar_ids` — así que cuando el cliente pedía otra fecha,
`handle_slot_negotiation`/`slot_service_for` (código YA existente, de la negociación de horario)
volvían a leer `booking_calendars_for(tracking)` desde la BD, que seguía vacío, y caían al pool
completo del agente. **Arreglo**: `offer_resource_availability` ahora persiste
`tracking.update!(booking_calendar_ids: booking_calendars)` antes de construir el servicio de
horarios — mismo patrón ya usado por `scope_tracking_to_single_resource`/`spawn_resource_tracking`.
Probado: reproduje la conversación exacta (TP-64 → "para el jueves") y la negociación ahora se
mantiene acotada a `REC-001` en todos los turnos.
**Nota aparte, menor, no arreglada**: el primer ofrecimiento tampoco prioriza la fecha que el
cliente ya mencionó en su mensaje original ("para el jueves") — muestra los horarios más próximos
sin importar el día pedido, obligando a repreguntar como en esta conversación. Sería una mejora de
UX (pasar `from:` a `AvailabilitySlotService#call` con la fecha ya extraída), no bloqueante.

**Reconfirmación del hueco de tipo de carga (conv. display #132, 2026-09-04)** — prueba con
requisitos (compresor 15T, 5m x 2m, sin nombrar recurso): de los 5 calendarios ofrecidos, 4/5
correctos (plataformas planas/cama baja con capacidad y medidas de sobra) y 1/5 incorrecto por
tipo: `REC-021` → `TP-117`, la MISMA góndola/caja de volteo (material a granel) ya detectada como
mal ofrecida en la conv. #111. `match_by_requirements` solo compara capacidad/largo/ancho — no
compara el TIPO de carga (rígida vs. a granel) contra lo que el remolque está diseñado para llevar,
porque el catálogo no tiene ese campo estructurado todavía. Mismo hueco documentado arriba (M5/M6),
no es un bug nuevo — reforzado con un segundo caso real e independiente. Nota aparte: como el
compresor (15T) es más chico que casi toda la flotilla real, casi cualquier remolque calificó
numéricamente — con requisitos bajos el filtro reduce poco el pool, esto es esperado.

**✅ ARREGLADO y probado (2026-09-05)**: `ResourceMatcher` ahora detecta remolques descritos para
material A GRANEL por palabras clave en `DESCRIPCION` (`GRANEL_KEYWORDS`: góndola/volteo/granel) y
los excluye de `match_by_requirements` salvo que el cliente haya descrito explícitamente carga a
granel (nuevo campo extraído `carga_a_granel`, mismo criterio conservador que el resto del método:
ante duda, no se ofrece). Sin campo estructurado en el catálogo — heurística por texto, suficiente
para el caso real conocido. Probado en el flujo completo real: el mismo pedido de compresor
(15T/5x2) ya NO incluye el calendario de TP-117 entre los candidatos (antes sí, 24/24); con carga
explícitamente a granel, sí lo incluye.

**Prueba positiva (conv. display #134, 2026-09-04) — izaje sin unidad real, escaló correctamente**:
requisito de izaje (12T) que hoy nadie del catálogo real cumple. El bot NUNCA ofreció un remolque
inapropiado, y al pedir explícitamente un asesor escaló limpio con el caso `RU-00064` y la razón
correcta. **Mejora menor detectada (no bloqueante, no arreglada)**: `send_resource_availability_no_match`
repite el mismo mensaje fijo sin límite — el bot lo mandó 3 veces idénticas seguidas en vez de
escalar proactivamente después de 2 intentos fallidos (como sí hace el guard anti-loop de
`reuse_existing_ticket`/`MAX_LINKED_REPEATS` en otro flujo). Solo escaló porque el cliente lo pidió
explícitamente. Arreglo propuesto: agregar un contador similar (Redis, TTL corto) a
`try_resource_availability`/`send_resource_availability_no_match` para escalar solo después de N
intentos sin poder resolver, en vez de repetir indefinidamente.

**✅ ARREGLADO y probado (2026-09-05)**: `DISPONIBILIDAD_NO_MATCH_MAX_REPEATS = 2` (Redis, TTL 1h,
mismo patrón que `MAX_LINKED_REPEATS`) — al 3er intento sin match, escala solo (mensaje distinto,
`tracking.pause!`, nota privada, notifica admin) en vez de repetir el mismo mensaje. El contador se
limpia apenas hay un match exitoso, para no arrastrar intentos viejos. Probado: 2 mensajes de izaje
(12T) → mismo mensaje repetido; 3er intento → escaló con el mensaje de handoff y `tracking.status
== 'paused'`.

**Fase 3 ✅ HECHA y probada (2026-09-04)**: `TicketCreatorService#create_after_appointment`
(nuevo método público — construye el ticket igual que siempre pero le agrega
`custom_attributes['id_recurso']`/`['calendar_id']` ya resueltos) +
`ResourceMatcher#find_by_calendar_id` (recurso real detrás del `gcal` que quedó agendado) +
`ContactTrackingResponseAnalyzerJob#maybe_create_ticket_after_appointment`, enganchado al final de
`confirm_and_create_appointment` (justo después de confirmar la cita con éxito). Condicionado a
`@disponibilidad_calendar` Y `@crear_ticket` presentes Y que el contacto NO tenga ya un ticket
activo — cero cambio para cualquier otra combinación de directivas.
Probado de punta a punta (pedir disponibilidad de TP-94 → elegir horario → "sin correo" → cita
confirmada): el ticket se creó DESPUÉS de la cita, con
`custom_attributes: {"id_recurso"=>"TP-94", "calendar_id"=>"...calendar de TP-94..."}` — exactamente
el orden y el dato que pidió el usuario. (Nota de prueba: aparecieron respuestas duplicadas en la
prueba por el mismo artefacto ya documentado de ejecución doble de Sidekiq al crear `Message`
manualmente — no es un defecto de esta fase; se limpió el evento de calendario de prueba creado.)

**Nota de contexto (conv. display #136, 2026-09-04) — no es un bug, es artefacto del entorno de
prueba**: en casi todas las pruebas de requisitos (no por nombre) aparecen los mismos 5 calendarios
(`REC-005/020/015/021/013`). Investigado: `AvailabilitySlotService#balance_slots` toma los 5
horarios más tempranos entre TODOS los calendarios candidatos que califican — como en este entorno
de prueba casi todos los calendarios están casi vacíos (0-1 eventos en 5 días, verificado), hay
empate entre docenas de candidatos por "el horario más próximo", y el desempate
(`resource_key(s).join('::')`, cadena del `google_calendar_id`) favorece siempre los mismos IDs por
orden alfabético — sin relación con cuál recurso es mejor. En producción, con calendarios reales
con actividad variada, este empate sería mucho menos frecuente. No requiere cambio de código, solo
dejar constancia para no confundirlo con un fallo de filtrado en pruebas futuras.

**🔴 Bug real encontrado (conv. display #137, 2026-09-04) — ✅ ARREGLADO y probado (2026-09-05)** —
un mensaje duplicado del cliente generó una SEGUNDA cita real innecesaria: el cliente reenvió (por
su cuenta, dos veces) "Se me olvidó decir que el peso exacto es 20.5 toneladas." — la primera copia
llegó durante el flujo de agenda normal (ignorada correctamente, el bot solo pedía el correo); la
SEGUNDA copia llegó DESPUÉS de que la cita ya había sido confirmada y el ticket `RU-00067` ya
estaba creado. Como todavía menciona un peso, `try_resource_availability` la tomó como un pedido
de disponibilidad nuevo — sin revisar si el contacto ya tenía un caso resuelto — y terminó creando
una SEGUNDA cita real en Calendar, redundante (se borró el evento de prueba). Se confirmó además
(conv. #139) que este mismo hueco, combinado con `@crear_ticket_multiple`, dejaba la segunda cita
**sin ticket** (huérfana) — ver detalle en la Fase 3 más abajo.
**Causa de fondo**: `try_resource_availability` corría ANTES de `try_create_ticket` en la cascada y
no tenía ninguna noción de "¿este contacto ya tiene un caso activo?" — a diferencia de
`@crear_ticket_multiple`, que sí clasifica (mismo caso/pregunta técnica/solicitud nueva) antes de
actuar cuando hay un ticket activo.
**Arreglo implementado (2026-09-05)**: en `try_kbase_then_conversational`
(`contact_tracking_response_analyzer_job.rb`), si el prompt tiene `@disponibilidad_calendar` Y el
contacto ya tiene un ticket activo, el orden se invierte: primero corre `try_create_ticket` (que ya
trae la clasificación de `@crear_ticket_multiple`), y solo si su outcome es `:confirmed_new_request`
se le da paso a `try_resource_availability` (usando el contexto reciente para encontrar el recurso
de la solicitud nueva ya confirmada). Sin ticket activo, el orden de siempre no cambia (Fases 1-3
intactas). También se quitó de `TicketCreatorService#create_if_needed` la construcción inmediata
del ticket para `:confirmed_new_request` cuando `@disponibilidad_calendar` está presente (ahora
corta devolviendo `false` para que la disponibilidad decida primero), y se quitó de
`maybe_create_ticket_after_appointment` el guard "si ya hay un ticket activo, no crear" (estaba
pensado para antes de `@crear_ticket_multiple` y bloqueaba exactamente el caso que ahora sí
corresponde permitir).
**Probado** (con `Sidekiq::Testing.fake!` para aislar de la ejecución duplicada de Sidekiq ya
documentada en este mismo archivo — con ella activa el bug de #137/#139 se reprodujo también en
las pruebas aisladas, confirmando que la causa real no era solo el mensaje duplicado sino la falta
de este chequeo):
- Reproducción exacta de #139 (bomba → tanque distinto → confirma "sí, es nuevo" → elige horario):
  ahora SÍ pregunta antes de ofrecer agenda, y al confirmar crea el segundo ticket con los campos
  correctos (`material=tanque`, `peso=25 toneladas`, `id_recurso` real). ✅
- Regresión: mismo caso agrega info → vincula sin preguntar, 1 solo ticket. ✅
- Regresión: pregunta técnica con caso abierto → contesta por catálogo, no dice "ya tienes un
  caso", 1 solo ticket. ✅
- Regresión: solicitud nueva pero el cliente dice "no, es lo mismo" → vincula al existente, NO
  crea un segundo. ✅
- Regresión: primera solicitud sin ticket activo (TP-64 por nombre) → Fases 1-3 intactas, ticket
  creado después de la cita con `id_recurso` correcto. ✅

**Fase 4 ✅ HECHA (2026-09-04)**: `AGENTE GRUAS V11` (`TrackingTemplate` id 3684, clon de V10) —
prompt reescrito: ROUTER-AGENDA/ROUTER-TICKET actualizados, sección "CREACIÓN DEL TICKET" → "REGISTRO
DEL CASO" (ahora automático, al final, tras confirmar la cita), sección M6/M7 → "DISPONIBILIDAD Y
AGENDAMIENTO" describiendo el nuevo mecanismo. `@agendar_calendar` **removido** de las directivas —
esto además resuelve de rebote, solo para V11, el bug de "agenda prematura" (`appointment_dispatchable?`
depende de que `@agendar_calendar` esté presente; sin él, el clasificador genérico de citas que
causaba ese bug nunca se activa). El bug sigue abierto para cualquier OTRA cuenta que combine
`@agendar_calendar`+`@crear_ticket` — no se tocó ese código compartido.

**🟡 Hueco encontrado probando V11 (2026-09-04, no arreglado)**: si los datos base llegan en
mensajes SEPARADOS (ej. "necesito trasladar una bomba de 18 toneladas" → luego → "de Minatitlán a
Coatzacoalcos, el lunes"), el segundo mensaje no menciona peso/recurso, así que
`try_resource_availability` no se activa ese turno y el turno cae al `@crear_ticket` normal —
que sí ve todo completo y **crea el ticket a la manera vieja, antes de la agenda**, saltándose todo
el mecanismo nuevo. Confirmado con prueba dedicada. Cuando el cliente da todo en UN mensaje (patrón
más común en las pruebas reales de este documento) el flujo nuevo funciona correctamente.
**Causa de fondo**: `try_resource_availability` decide turno por turno "¿ESTE mensaje pide
disponibilidad?", pero la pregunta correcta es "¿la conversación YA está completa para pasar a
disponibilidad?" — eso solo lo sabe con certeza `Cases::Ai::Intake`/`TicketCreatorService` (ya
extrae y trackea completitud de campos across toda la conversación).
**Arreglo propuesto (Fase 5, no implementado, decisión del usuario: documentar y seguir después)**:
enganchar `@disponibilidad_calendar` en el punto EXACTO donde `TicketCreatorService#create_if_needed`
decide "ya tengo todo, listo para crear" (justo antes de `create_and_confirm`) en vez de un chequeo
aparte y anterior en el job — para cuentas con `@disponibilidad_calendar`, desviar ahí mismo hacia
disponibilidad usando los campos YA extraídos por el intake, en vez de re-extraer del mensaje
suelto. Requiere decidir cómo mapear campos de intake (genéricos, por `case_type_fields`
configurables) a los requisitos técnicos que `ResourceMatcher#match_by_requirements` necesita
(peso/izaje/dimensiones) — no es un campo fijo, varía por tipo de caso.

**Intento de arreglo rápido (2026-09-05) — REVERTIDO, no sirvió**: se probó ampliar la ventana de
contexto de `try_resource_availability` (4→8 mensajes) y reforzar el prompt de extracción para que
considerara toda la conversación, no solo el último mensaje. Resultado: **regresión** — un mensaje
con SOLO el peso ("necesito trasladar una bomba de 18 toneladas", sin ubicaciones) empezó a
disparar `@disponibilidad_calendar` de inmediato, cuando antes correctamente pedía las ubicaciones
faltantes primero. Revertido a la versión original de `resource_matcher.rb` y
`contact_tracking_response_analyzer_job.rb` (ventana de 4, prompt sin el énfasis en "toda la
conversación").
**Hallazgo adicional, más de fondo**: al revertir y volver a probar el MISMO mensaje ("bomba de 18
toneladas", sin ubicaciones) con el código YA revertido (idéntico al de antes del intento), el
comportamiento salió **inestable** — a veces dispara disponibilidad de inmediato (mal, sin datos
base completos) y a veces pide las ubicaciones primero (bien) — mismo mensaje, mismo código,
resultado distinto entre corridas. Confirma que esto es no-determinismo del LLM en la propia
clasificación "¿aplica disponibilidad?", no algo introducido por el intento de arreglo. Refuerza
que un ajuste de prompt no alcanza — hace falta el enganche estructural descrito arriba (Fase 5,
en el punto exacto donde `TicketCreatorService` ya sabe con certeza si los datos base están
completos), que sigue sin implementarse.

**Qué implica ese enganche estructural (2026-09-05, para retomar después)**: (1) un nuevo outcome
en `TicketCreatorService#create_if_needed` — justo antes de `create_and_confirm(fields)`, si la
cuenta usa `@disponibilidad_calendar` y no se resolvió ya por nombre (`resources_requested`),
devolver un outcome tipo `:ready_for_availability` (`false`) para que el job intente
`try_resource_availability` en vez de crear el ticket ahí mismo — mismo patrón que
`:confirmed_new_request`. (2) Los campos ya extraídos (`@field_values`, ej. `peso: "18
toneladas"` en texto libre) NO calzan directo con lo que pide `ResourceMatcher#match_by_requirements`
(número, izaje, dimensiones, tipo de carga) — sigue haciendo falta una extracción dedicada, solo
que ahora se dispara con certeza de que hay datos, no como apuesta. (3) Falta diseñar un "plan B":
qué hacer si, aun con los campos obligatorios completos, no se puede armar un requisito claro para
buscar disponibilidad (¿cae al alta de ticket de siempre? ¿pide el dato específico?). (4) Requiere
probar la combinación nueva (datos repartidos en varios mensajes) y el caso "completo pero sin
requisito claro", ninguno probado todavía. **Decisión del usuario (2026-09-05): queda pendiente,
no se implementa por ahora.**

### Plan: nueva directiva `@crear_ticket_multiple` (resuelve Bug B y la causa de fondo de 3b) — ✅ HECHA y probada (2026-09-04)

Alias de `@crear_ticket` (mismo motor de campos/prioridad/escalamiento/`resources_requested` —
`DIRECTIVE_RE` ahora acepta `_multiple` opcional sin romper la captura de parámetros para ninguna
de las 2 formas) que cambia SOLO el comportamiento de `reuse_existing_ticket` cuando ya hay un caso
activo: en vez de vincular ciegamente todo mensaje siguiente, clasifica primero qué es
(`Cases::Ai::TicketReuseClassifier`, nuevo servicio):
- **`same_case`** (agrega info/confirma/sigue el hilo) → vincula como siempre, sin preguntar.
- **`technical_question`** (pregunta de catálogo aislada, sin relación con el caso) → NO vincula;
  `create_if_needed` devuelve `false` para que el job siga su cascada normal hasta la KBase.
- **`new_request`** (trabajo claramente distinto) → pregunta explícito ("¿es parte del mismo caso o
  un servicio aparte?") antes de crear nada; solo si el cliente CONFIRMA explícitamente
  (`confirm_new_request?`, otra clasificación IA, nunca asume "sí" ante ambigüedad) se crea un
  segundo ticket independiente — si dice que no, se vincula al existente normalmente.
Archivos: `app/services/cases/ticket_creator_service.rb` (regex, `multiple_mode?`,
`reuse_existing_ticket_multiple` y helpers, nuevos outcomes `:technical_question`/
`:asked_new_request_confirmation`/`:confirmed_new_request`), `app/services/cases/ai/
ticket_reuse_classifier.rb` (nuevo).
También se mejoró `Cases::TicketStatusService` (@estado_ticket): con varios casos activos, si el
cliente menciona el folio de uno (ej. "cómo va el RU-00052") ahora responde el detalle de ESE en vez
de la lista breve — mejora general, no gated a `@crear_ticket_multiple`, sin cambio de
comportamiento cuando no se menciona folio.

**Probado** con un agente de prueba aislado (no toca V10/V11 — opt-in por directiva):
- Pregunta técnica con caso abierto → contestó por catálogo, YA NO dijo "ya tienes un caso" (Bug B
  resuelto). ✅
- Mismo caso, agrega info → vinculó sin preguntar nada. ✅
- Solicitud nueva y distinta, cliente confirma "sí, es nuevo" → preguntó primero, y al confirmar
  creó un ticket aparte. ✅
- Solicitud nueva y distinta, cliente dice "no, es lo mismo" → vinculó al caso existente, NO creó
  uno nuevo (nunca duplica sin confirmación explícita, como pidió el usuario). ✅

**🟡 Rough edge encontrado (no arreglado, documentado)**: en el escenario "confirma que sí es
nuevo", el ticket nuevo salió marcado `multiple_requests: true` con AMBAS solicitudes listadas
(la original, ya en su propio ticket, Y la nueva) — duplicando la original. Causa: al confirmar, el
flujo cae al `create_if_needed` normal, que llama al intake compartido con la ventana de
conversación reciente (últimas 8), la cual todavía incluye el pedido original ya resuelto — el
intake ve "2 servicios" en esa ventana y dispara `multiple_requests` de nuevo. El ticket nuevo SÍ
se crea por separado (la funcionalidad principal funciona), pero su descripción queda con ruido
redundante. Arreglo pendiente: acotar la ventana de conversación que ve el intake al confirmar un
`new_request`, para que no vuelva a considerar el pedido ya ticketeado.

**✅ ARREGLADO y probado (2026-09-05)**: `ask_new_request_confirmation` ahora guarda (Redis, mismo
TTL) el ID del mensaje donde arrancó la solicitud nueva. `apply_new_request_conversation_scope!`
(nuevo, llamado en `create_if_needed` cuando cae al flujo normal sin `@disponibilidad_calendar`, y
en `create_after_appointment` cuando sí la hay) reconstruye `conversation_text` SOLO con los
mensajes desde ese punto en adelante, antes de llamar al intake — así no vuelve a ver el pedido
viejo ya ticketeado. Probado con el caso real completo (bomba → tanque → confirma nuevo → agenda →
ticket): la descripción del segundo ticket ya NO repite los datos de la bomba (antes sí). Nota
menor residual: la descripción a veces incluye una frase tipo "es un caso nuevo y aparte del
anterior" (eco de la propia confirmación del cliente, que queda dentro de la ventana acotada) — no
duplica datos, es solo una frase de más; no se consideró necesario pulir más.

**Riesgo cross-cuenta**: bajo — opt-in por `_multiple`, el `@crear_ticket` normal no cambia en nada
(verificado con regex: ambas formas capturan parámetros correctamente, `multiple_mode?` distingue
cuál se usó).

**🔴 Bug real encontrado en Telegram (conv. display #148, 2026-09-05) — ✅ ARREGLADO y probado**:
loop infinito de "¿es lo mismo o es nuevo?". Tras confirmar "es aparte", si
`@disponibilidad_calendar` no lograba armar la agenda en ESE mismo turno (la extracción es
inestable, ver hallazgo del punto #6 más abajo), el turno caía a una respuesta conversacional
pidiendo más datos — pero la confirmación era de un solo uso: en el turno SIGUIENTE, como el caso
viejo seguía activo y no quedaba memoria de que ya se había confirmado, `reuse_existing_ticket`
volvía a clasificar desde cero y preguntaba "¿es lo mismo o es nuevo?" OTRA VEZ — y así en cada
turno de la recolección de datos del servicio nuevo, indefinidamente.
**Arreglo**: nueva marca persistente `new_request_in_progress` (Redis, mismo TTL que el resto del
flujo) — se activa al confirmar "es nuevo" (si hay `@disponibilidad_calendar`) y dura TODA la
recolección de datos de ese servicio, no un solo turno. Mientras está activa:
`TicketCreatorService#reuse_existing_ticket` devuelve `nil` de inmediato (trata la conversación
como si no hubiera ningún caso activo, sin volver a preguntar ni vincular al viejo), y el job
restaura el orden normal (`@disponibilidad_calendar` decide primero, como si fuera la primera
solicitud). Se libera al crear el ticket nuevo con éxito
(`maybe_create_ticket_after_appointment`) o expira sola. Archivos:
`app/services/cases/ticket_creator_service.rb` (`new_request_in_progress_key`,
`new_request_in_progress?`, `clear_new_request_in_progress`), `app/jobs/
contact_tracking_response_analyzer_job.rb` (`new_request_in_progress?`, gate de
`active_ticket_gate`).
Probado con la reproducción exacta de la conv. #148 (multisolicitud → pregunta técnica → nuevo
servicio → "es aparte" → más datos en 2 turnos → agenda → ticket): la pregunta "¿es lo mismo o es
nuevo?" salió UNA sola vez, y terminó con 2 tickets independientes, cada uno con su `id_recurso`
correcto — sin loop.

Solución de fondo al hueco M5/M6 de arriba, acordada con el usuario. Directiva NUEVA, independiente
de `@agendar_calendar` (no se toca esa, cero riesgo para otras cuentas) — solo se activa si está
presente en el prompt del agente.

**Flujo acordado (invierte el orden actual de GRUAS V9/V10)**:
1. Cliente pide agenda — por nombre de recurso (ej. "REC-001", "TP-94") o por requisitos técnicos
   (ej. "grúa con capacidad de 10 toneladas") — SIN necesitar ticket todavía.
2. `@disponibilidad_recurso` resuelve el/los calendario(s) que califican y muestra su disponibilidad.
3. Cliente elige un horario.
4. **Recién ahí** se ejecuta `@crear_ticket`, ya con el recurso/calendario decidido —
   `custom_attributes` con `id_recurso`/`calendar_id` grabado desde la creación (hoy es al revés:
   el ticket se crea antes y la agenda no sabe qué recurso se ligó).
5. Se confirma la cita con el mecanismo de agendamiento real que ya existe.

**Resolución del recurso**:
- Por nombre: buscar en catálogo real (`TIPO_REGISTRO=RECURSO`, `CALENDAR_ID` no vacío). Si existe
  → disponibilidad de ese calendario únicamente.
- Nombre no encontrado → NO es callejón sin salida: decirlo, y caer automáticamente al caso de
  requisitos (usando lo que el cliente ya haya dado) para **recomendar unidades similares**. Si no
  hay requisitos suficientes para recomendar nada → pedir esos datos o escalar (información
  insuficiente, mismo criterio M5 ya usado en todo el prompt).
- Por requisitos: filtrar catálogo real por capacidad/`PUEDE_IZAR`/dimensiones. 1 califica → esa.
  Varios califican → disponibilidad **combinada** de todos (decisión del usuario, 2026-09-04).
  Ninguno califica → información insuficiente, escalar.

**Piezas de código**:
1. `Cases::Ai::ResourceMatcher` — agregar `find_by_name(nombre)` y `match_by_requirements(requisitos)`;
   `find_by_name` cae a `match_by_requirements` cuando no hay coincidencia exacta.
2. Detectar la nueva directiva igual que las demás (regex + cascada del job), con su propio handler
   que arma la respuesta de horarios acotada — sin exigir ticket previo.
3. Mover el punto donde hoy `@crear_ticket` corre "antes de M6": debe correr DESPUÉS de que el
   cliente elige horario cuando la nueva directiva está presente, recibiendo `id_recurso`/
   `calendar_id` ya resueltos. Implementar condicionado a la presencia de la nueva directiva — las
   cuentas con el orden actual (`@crear_ticket` antes de `@agendar_calendar`) no deben verse
   afectadas.
4. Prompt de GRUAS (V10 → V11): reescribir "CREACIÓN DEL TICKET" (hoy dice explícito "esto ocurre
   antes de ofrecer disponibilidad") para reflejar el nuevo orden: identificar/validar recurso →
   mostrar disponibilidad → elegir → crear ticket → confirmar agenda.

**Pruebas hasta entrega final**:
1. Unitarias: `find_by_name` (exacto, no encontrado → cae a requisitos), `match_by_requirements`
   (0/1/varios).
2. Conversacionales: nombre existente, nombre inexistente (verificar que recomiende similares),
   requisitos con 0/1/varios matches.
3. Verificar que el ticket, una vez creado, quede con el recurso/calendario correcto grabado.
4. Regresión completa de las pruebas V9/V10 ya corridas (`@crear_ticket`/`@estado_ticket` deben
   seguir funcionando en el nuevo orden).
5. Piloto en Telegram con SSUSA antes de cerrar.

**Riesgo cross-cuenta**: bajo — directiva nueva y opt-in. Punto delicado: el cambio de orden de
`@crear_ticket` debe quedar condicionado a la presencia de la nueva directiva en el prompt.

**Nota de secuencia (actualizada 2026-08-31)**: la idea original era que 3a y 3b compartieran la
MISMA clasificación de intención — en la práctica se implementó distinto: 3a (alcance mínimo) usó
su propia señal nueva del intake (`pending_technical_question`, ver punto 1), independiente de 3b.
3b sigue con su guard anti-loop por conteo (Redis), no con clasificación de intención — la causa de
fondo de 3b (distinguir "mismo caso" de "necesidad nueva") sigue pendiente y podría reusar el mismo
patrón de señal que 3a/1 si se retoma. 2a y 2b dependen de completar el dato de negocio (catálogo
real con `ID_RECURSO`/`CALENDAR_ID` para todos los camiones, no solo las 2 filas de prueba) — 2b ya
está implementado y probado; 2a tiene el mapeo calculado pero bloqueado escribirlo hasta reconectar
Google Calendar con permiso de escritura (ver arriba).
- **Panel de contacto** (3er punto de entrada del diseño) — mostrar tickets históricos del contacto en su perfil. NO se hizo.
- **Reglas pre-cargadas por defecto** (las 7 del diseño) — el seed automático no se implementó; las reglas se crean manualmente desde la UI.
- ~~**⚠️ Borrado de conversación/contacto deja tickets huérfanos**~~ ✅ **hecho** (2026-07-15, commit `48bbc316`). Política elegida: **conservar el ticket como histórico**.
  - FKs en BD para `contact_id` / `conversation_id` / `contact_tracking_id` con **`on_delete: :nullify`** + índices de columna única (migración `20260608000007`, `validate: false` para no fallar con huérfanos previos).
  - `has_many :case_tickets, dependent: :nullify` en `Contact`, `Conversation` y `ContactTracking`.
  - `validate :contact_or_requester_present, on: :create` — así el ticket huérfano (contacto borrado → `contact_id` NULL) **sigue siendo editable/cerrable**.
  - Nota corregida: `contact_id` ya era **nullable** desde Fase C (`20260607000003`), no `not null`. Verificado en BD: borrar cada padre deja el ticket vivo con la referencia en NULL; el huérfano se edita y se cierra; crear sin contacto ni solicitante sigue bloqueado.



## 🔗 Relacionado
- [[Historial-de-implementacion]] · [[00-Indice]]
