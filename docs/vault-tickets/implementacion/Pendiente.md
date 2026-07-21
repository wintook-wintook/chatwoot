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
- **Futuro Kanban**: plantillas de aviso configurables por cuenta; acciones rápidas en la tarjeta (asignar/prioridad/abrir); SLA en cuenta regresiva con color; avatar del asignado; mover instantáneo con "Deshacer"; swimlanes.

### Tareas + Bloqueo de ticket — hecho, mejoras futuras
- ~~**Tareas/subtareas (checklist) en el ticket**~~ ✅ **hecho** (`case_tasks`, checklist con responsable/borrar/agregar, "Tareas {done}/{total}").
- ~~**Bloqueo de ticket (lock con TTL 3 min)**~~ ✅ **hecho** (banner "X está trabajando en este ticket ahora mismo"; toma en mounted, libera en beforeDestroy; API 409 si lo tiene otro).
- **Futuro Tareas**: fecha límite (`due_at` ya existe en BD, falta UI); reordenar (drag); plantillas de checklist por tipo de caso; "convertir tarea en ticket".
- **Futuro Lock**: aviso en tiempo real (hoy solo al abrir/refrescar); "tomar el control" forzado por admin; heartbeat para renovar el lock mientras se escribe.

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
  - **Pendiente**: 👥 colaboradores/CC (modelo nuevo, esfuerzo BAJO — hay backend a medias **sin commitear** en `feat/tickets`) · 🖨️ imprimir (vista imprimible ficha+hilo, BAJO).
  - ~~📄 **notas internas (bitácora)**~~ ✅ **hecho** (ver [[Plan-Notas-Internas]] y el changelog). **Pendiente de esa función**: Fase 2 — nota opcional al **Cambiar estado** (cero backend: `transition!` ya acepta `reason:`); editar/borrar notas; adjuntos y menciones en la nota.

### Widget embebible — PENDIENTE (ver [[Plan-Widget-Embebible]])
- Launcher JS + iframe para capturar tickets desde la web del cliente, reusando el User Portal.
- Incluye una corrección de seguridad: `X-Frame-Options: ALLOWALL` global (`config/application.rb:58`, heredado del fork en `fd22446c`) → `frame-ancestors` por portal.

### Email-to-ticket — PENDIENTE (no implementado)
- Crear ticket automáticamente desde un correo entrante (inbox Email) — estilo osTicket "Email Piping". Decidir mapeo (asunto→título, remitente→contacto, tipo por defecto) y reusar `PortalTicketService`/`PortalThreadSeeder`.

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
