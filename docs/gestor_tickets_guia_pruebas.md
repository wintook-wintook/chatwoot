# Gestor de Tickets (MGCI) — Guía de pruebas para QA

> **Objetivo de este documento:** que un tester entienda qué hace el módulo, cómo
> funciona y pueda ejecutar pruebas funcionales paso a paso con resultados esperados
> claros. No requiere conocimientos de programación.

---

## 1. ¿Qué es el Gestor de Tickets?

Es el **Motor de Gestión de Casos Inteligente (MGCI)**: convierte conversaciones y
seguimientos en **tickets** con ciclo de vida, prioridad, **SLA** (tiempos de
respuesta/resolución), asignación y un **historial** de todo lo que pasó.

Un ticket se puede crear de **dos formas**:
1. **Manual** — un agente lo crea desde el panel derecho de una conversación.
2. **Automático** — el bot lo crea cuando la base de conocimiento no resuelve la
   consulta del cliente (directiva interna `@crear_ticket`).

Además incluye **reglas de automatización** (asignar, escalar, cambiar prioridad…),
**métricas**, **tipos de caso** configurables por cuenta y **folios** (número de
ticket) con plantilla personalizable.

---

## 2. Glosario rápido

| Término | Qué es |
|---|---|
| **Ticket / Caso** | La unidad de trabajo. Tiene folio, título, tipo, prioridad, estado y SLA. |
| **Tipo de caso** | Categoría configurable por cuenta (Soporte, Comercial, etc.), con color y prefijo de folio. |
| **Folio** | Número identificador del ticket (ej. `SOP-00001`), generado por plantilla. |
| **Estado** | Etapa del ciclo de vida (abierto, en progreso, resuelto, cerrado…). |
| **Prioridad** | Baja / Media / Alta / Urgente. Define los tiempos de SLA. |
| **SLA** | Tiempo objetivo de primera respuesta y de resolución. Estado: a tiempo / en riesgo / vencido. |
| **Regla** | Automatización: "si se cumple X condición → ejecuta Y acción". |
| **Evento (timeline)** | Registro histórico de cada cambio del ticket. |

---

## 3. Preparación del entorno de pruebas

### 3.1 Activar el módulo (feature flag)
El módulo está **apagado por defecto**. Para una cuenta de pruebas:

1. Entra al **super admin** → **Accounts** → selecciona la cuenta → **All features**.
2. Marca el checkbox **`case_management`** y guarda.

> ✅ **Resultado esperado:** en el dashboard de esa cuenta aparece el icono
> **"Gestor de Tickets"** (📋) en la barra lateral izquierda, y dentro de las
> conversaciones aparece el panel **"+ Crear ticket"**.
> Si la feature está **apagada**, **nada** de tickets debe verse (ni sidebar ni panel).

### 3.2 Dónde está cada cosa (rutas del dashboard)
| Sección | Ruta | Quién puede entrar |
|---|---|---|
| Todos los tickets | `/accounts/:id/tickets` | Admin y agente |
| Métricas | `/accounts/:id/tickets/metrics` | Admin y agente |
| Tipos de caso | `/accounts/:id/tickets/types` | Solo admin |
| Reglas de automatización | `/accounts/:id/tickets/rules` | Solo admin |
| Configuración de folio | `/accounts/:id/tickets/config` | Solo admin |
| Detalle de un ticket | `/accounts/:id/tickets/:idTicket` | Admin y agente |

---

## 4. Casos de prueba

> Formato: **Pasos** → **Resultado esperado (✅)**. Marca cada caso como Pass/Fail.

### Caso A — Activar / desactivar la feature
1. Con `case_management` **OFF**, abre el dashboard y una conversación.
   ✅ No aparece el icono de tickets ni el panel "+ Crear ticket".
2. Activa `case_management` en el super admin y recarga.
   ✅ Aparecen el icono lateral y el panel de ticket en la conversación.

### Caso B — Tipos de caso (CRUD + prefijo)
1. Ve a **Tipos de caso**. ✅ Se listan los tipos por defecto (Soporte/SOP,
   Comercial/COM, Implementación/IMP, Seguimiento interno/SEG, Incidente/INC).
2. **Crear** un tipo nuevo: nombre "Postventa", elige un color, prefijo `PV`.
   ✅ Aparece en la lista con su color y el prefijo `PV`.
3. Deja el prefijo **vacío** al crear otro tipo "Garantías".
   ✅ Se autogenera un prefijo de 3 letras (ej. `GAR`).
4. **Editar** un tipo (cambia color/nombre). ✅ Se refleja el cambio.
5. **Eliminar** un tipo con confirmación.
   ✅ Desaparece; los tickets que tenían ese tipo quedan **sin tipo** (no se borran).

### Caso C — Configuración de folio
1. Ve a **Configuración de folio**. ✅ Se muestra plantilla actual (ej. `{PREFIX}-{SEQ:5}`)
   y una **vista previa en vivo** (ej. `SOP-00001`).
2. Cambia la plantilla a `{PREFIX}-{YYYY}-{SEQ:4}` y observa la vista previa.
   ✅ La preview se actualiza al instante (ej. `SOP-2026-0001`).
3. Prueba los **tokens** disponibles: `{PREFIX}`, `{SEQ:n}`, `{YYYY}`, `{YY}`, `{MM}`, `{DD}`.
4. Cambia **alcance** (consecutivo por tipo vs general) y **reinicio** (nunca/diario/mensual/anual). Guarda.
   ✅ Mensaje "Configuración guardada". **Los folios existentes NO cambian**; solo aplica a tickets nuevos.
5. Apaga el toggle "Generar folio automático" y guarda.
   ✅ Los nuevos tickets se crean **sin folio**.

### Caso D — Crear ticket manual desde la conversación
1. Abre una conversación con un contacto. En el panel derecho pulsa **"+ Crear ticket"**.
   ✅ Se abre el modal (no debe cerrarse solo).
2. Llena: tipo de caso, título, prioridad, descripción. Pulsa **Crear**.
   ✅ Toast de éxito; el panel muestra el ticket activo con su **folio**, tipo (con color),
   estado **Abierto** y badge de prioridad/SLA.
3. Verifica en **Todos los tickets** que aparece el ticket recién creado.

### Caso E — Lista "Todos los tickets" (búsqueda, filtros, orden, paginación)
1. **Búsqueda:** escribe parte de un folio (ej. `SOP`), un título o el **nombre de un
   contacto**. ✅ La lista filtra (~0.3s de debounce) y el contador muestra "X–Y de N".
   El botón ✕ limpia la búsqueda.
2. **Rango de fechas:** elige un rango y pulsa Aplicar.
   ✅ Solo se muestran tickets creados en ese rango.
3. **Filtros:** usa los selects **Estado** y **Prioridad** y los chips de **tipo**.
   ✅ La lista se filtra combinando los criterios.
4. **Quick filters:** "SLA vencido" y "Sin asignar".
   ✅ "Sin asignar" muestra solo tickets sin agente; "SLA vencido" solo los vencidos.
5. **Orden:** cambia "Ordenar por" (Fecha/Prioridad/Estado/SLA) y el toggle **↑/↓**.
   ✅ La lista se reordena.
6. **Limpiar filtros:** aparece cuando hay algún filtro activo y los resetea todos.
7. **Paginación:** baja "Por página" a 25/50/100 y navega con « ‹ › ».
   ✅ Cambian las páginas y el contador "X–Y de N".

### Caso F — Detalle y transiciones de estado
1. Abre un ticket desde la lista. ✅ Muestra folio, tipo, estado, prioridad, SLA,
   descripción y el **timeline** de eventos.
2. Cambia el estado con **"Cambiar estado"**. Solo deben ofrecerse las transiciones válidas
   (ver **tabla §5.2**). Ej.: de `Abierto` solo se puede ir a `Clasificado` o `Cancelado`.
   ✅ Una transición válida cambia el estado y agrega un evento al timeline.
3. Intenta (vía API o si la UI lo permite) una transición inválida (ej. `Abierto → Resuelto`).
   ✅ Se rechaza con error "Transición inválida".
4. Marca un ticket como **Resuelto**. ✅ Se registra `resolved_at`. Desde `Resuelto`
   se puede ir a `Cerrado` o reabrir a `En progreso`.

### Caso G — Asignación
1. En el detalle/panel, asigna el ticket a un **agente**. ✅ Queda asignado a ese agente
   y se crea evento "Asignado".
2. Asigna a un **equipo**. ✅ Queda asignado al equipo.
3. Verifica que el quick filter "Sin asignar" ya **no** lo muestra.

### Caso H — Reglas de automatización
1. Ve a **Reglas de automatización** → **+ Nueva regla**. ✅ Se abre el builder visual
   (condiciones y acciones interactivas, sin escribir JSON a mano).
2. Crea una regla de ejemplo:
   - **Condición:** Prioridad `es` `urgent`.
   - **Acción:** Escalar.
   - Guarda.
3. Crea un ticket con prioridad **Urgente** (o cambia uno a Urgente).
   ✅ La regla se dispara: el ticket pasa a **Escalado** y aparece el evento en el timeline.
4. Prueba una regla con condición de **contenido de mensaje** (`message_content` `contains`
   "factura") + acción **Cambiar prioridad → Alta**, respondiendo en la conversación.
   ✅ Se aplica al recibirse un mensaje que contiene "factura".

> Operadores disponibles: `eq, neq, contains, gte, lte, in, not_in`.
> Campos: `case_type, origin, priority, status, sla_status, message_content, time_without_response_min`.
> Acciones: `assign_agent, assign_team, change_priority, change_status, escalate, notify_agent, close_ticket` (`add_label` y `trigger_tracking` están reservadas/no-op).
> Las reglas se evalúan en orden; por defecto **paran en el primer match** (salvo `continue_on_match`).

### Caso I — Métricas
1. Ve a **Métricas**. Elige período (7/30/90 días o Todo).
   ✅ Tarjetas: total del período, activos, SLA vencidos/en riesgo, cumplimiento SLA,
   tiempo promedio de resolución, resueltos.
   ✅ Gráficas: por estado, por tipo, por prioridad y estado SLA (dona/barra).
2. Crea/resuelve tickets y verifica que los números cambian al recargar.
   ✅ Las distribuciones NO deben quedar todas en 0 si hay datos.

### Caso J — SLA (tiempos y monitor)
1. Revisa que la **prioridad** define el SLA (ver **tabla §5.3**).
2. Un ticket recién creado está **a tiempo** (punto verde).
3. Cuando transcurre **≥80%** del objetivo sin primera respuesta/resolución → **en riesgo** (amarillo).
4. Al pasar **100%** → **vencido** (rojo), visible en la lista y en el quick filter "SLA vencido".

> El recálculo de `sla_status` y el autocierre de tickets resueltos viejos lo hace el job
> programado **`CaseSlaMonitorJob`** (sidekiq-cron). En pruebas puede forzarse ejecutándolo
> manualmente (ver §7).

### Caso K — Timeline de eventos
1. En el detalle de un ticket, abre **"Ver historial"**.
   ✅ Se ven en orden: creación, clasificación, cambios de estado, asignaciones,
   escalados, mensajes, SLA en riesgo/vencido, resolución, cierre, etc., cada uno con
   actor (Sistema/Bot/Agente) y fecha.

### Caso L — Creación automática por el bot (`@crear_ticket`)
> Requiere una cuenta con bot de seguimiento + base de conocimiento configurada.
1. Como contacto, envía por el canal (WhatsApp/web) una consulta que la **base de
   conocimiento NO pueda responder**.
   ✅ El bot intenta KBase; al no encontrar respuesta, **crea un ticket automáticamente**
   con origen del canal y tipo por defecto.
2. Verifica en "Todos los tickets" que aparece el ticket con su folio y timeline
   (evento "Ticket creado" por el **Bot**).
3. **Importante (no-regresión):** si el módulo de tickets fallara, **el bot debe seguir
   funcionando** (el hook falla en silencio). El cliente nunca debe ver un error.

---

## 5. Tablas de referencia

### 5.1 Estados del ticket
`open` (Abierto) · `classified` (Clasificado) · `in_progress` (En progreso) ·
`waiting_on_customer` (Esperando cliente) · `waiting_on_internal` (Esperando equipo) ·
`escalated` (Escalado) · `resolved` (Resuelto) · `closed` (Cerrado) · `cancelled` (Cancelado).

### 5.2 Transiciones de estado válidas
| Desde \ Hacia | A dónde puede ir |
|---|---|
| Abierto | Clasificado, Cancelado |
| Clasificado | En progreso, Cancelado |
| En progreso | Esperando cliente, Esperando equipo, Escalado, Resuelto, Cancelado |
| Esperando cliente | En progreso, Cancelado |
| Esperando equipo | En progreso, Cancelado |
| Escalado | En progreso, Cancelado |
| Resuelto | Cerrado, En progreso (reabrir) |
| Cerrado | (final, sin transiciones) |
| Cancelado | (final, sin transiciones) |

### 5.3 SLA por prioridad (en minutos)
| Prioridad | 1ª respuesta | Resolución |
|---|---|---|
| Baja | 2880 (48 h) | 7200 (120 h) |
| Media | 480 (8 h) | 2880 (48 h) |
| Alta | 120 (2 h) | 480 (8 h) |
| Urgente | 30 min | 120 (2 h) |

> Umbrales: **en riesgo ≥ 80%** del objetivo, **vencido ≥ 100%**. Tickets resueltos/cerrados/cancelados se consideran **a tiempo**.

---

## 6. Endpoints API (para pruebas con Postman/curl)

Base: `/api/v1/accounts/:account_id`. Requiere header de autenticación del agente.

| Método | Ruta | Acción |
|---|---|---|
| GET | `/case_tickets` | Lista con filtros (ver abajo) |
| POST | `/case_tickets` | Crear ticket manual |
| GET | `/case_tickets/:id` | Detalle |
| PATCH | `/case_tickets/:id/transition` | Cambiar estado (`{status, reason}`) |
| PATCH | `/case_tickets/:id/assign` | Asignar (`{assignee_id}` o `{team_id}`) |
| GET | `/case_tickets/:id/case_events` | Timeline |
| GET | `/case_tickets/metrics` | Métricas (`date_from`, `date_to`) |
| GET/POST/PATCH/DELETE | `/case_rules` | CRUD de reglas |
| GET/POST/PATCH/DELETE | `/case_types` | CRUD de tipos |
| GET/PATCH | `/case_folio_config` | Configuración de folio |

**Filtros de `GET /case_tickets`:**
`q` (folio/título/descripción/nombre de contacto), `status`, `case_type_id`, `priority`,
`sla_status`, `assignee_id` (`null`/`none`/`unassigned`/`0` = sin asignar), `contact_id`,
`date_from`/`date_to` (`YYYY-MM-DD`), `sort_by` (`created_at|priority|sla_status|status`),
`sort_order` (`asc|desc`), `page`, `per_page` (default 25, máx 100).

Ejemplo:
```
GET /api/v1/accounts/2/case_tickets?q=SOP&priority=urgent&sort_by=created_at&sort_order=desc&page=1&per_page=25
```

---

## 7. Tips para el tester

- **Forzar el monitor de SLA** (recalcular estados sin esperar al cron), desde la consola
  de Rails: `CaseSlaMonitorJob.perform_now`.
- Para acelerar pruebas de SLA, crea tickets **Urgentes** (30 min de 1ª respuesta) y revisa
  el cambio a "en riesgo" a los ~24 min.
- Los tipos por defecto se crean solos por cuenta la primera vez que se usan.
- El folio solo se asigna al **crear** el ticket; cambiar la plantilla no renumera lo viejo.

---

## 8. Checklist de regresión rápida

- [ ] Feature OFF → no se ve nada de tickets (sidebar ni panel de conversación).
- [ ] Feature ON → sidebar + panel visibles.
- [ ] Crear ticket manual desde conversación (modal abre y guarda).
- [ ] Lista: búsqueda por folio/título/contacto, filtros, fechas, orden, paginación, limpiar.
- [ ] Detalle: transición válida OK, inválida rechazada.
- [ ] Asignar a agente y a equipo.
- [ ] Regla simple se dispara (ej. prioridad urgente → escalar).
- [ ] Tipos de caso: crear/editar/eliminar + prefijo.
- [ ] Folio: cambiar plantilla y ver preview; tickets nuevos respetan la plantilla.
- [ ] Métricas: tarjetas y gráficas con datos reales (no todo en 0).
- [ ] SLA: a tiempo → en riesgo → vencido según prioridad.
- [ ] Bot crea ticket cuando KBase no responde, sin romper la conversación.

---

## 9. Errores comunes / qué reportar

| Síntoma | Posible causa / qué adjuntar al reporte |
|---|---|
| No aparece el módulo | Feature `case_management` apagada para esa cuenta. |
| "Transición inválida" | Es esperado si el cambio de estado no está permitido (ver §5.2). |
| Búsqueda no encuentra a un contacto | Confirmar nombre exacto del contacto; adjuntar término buscado. |
| Métricas en 0 | Verificar período seleccionado; adjuntar captura + rango. |
| SLA no cambia | El cron pudo no haber corrido; pedir ejecutar `CaseSlaMonitorJob`. |
| Folio no se genera | Toggle "Generar folio automático" apagado en Configuración. |

> Al reportar un bug, incluye: **cuenta**, **rol** (admin/agente), **pasos exactos**,
> **resultado esperado vs obtenido**, **captura** y, si aplica, el **folio del ticket**.
