---
titulo: Comparativa Agent Panel osTicket ⇄ Chatwoot (MGCI)
tipo: análisis
tags: [tickets, osticket, chatwoot, agent-panel, gap-analysis]
fecha: 2026-06-30
fuente: https://docs.osticket.com/en/latest/Agent/
relacionado: [Referencia-osTicket, Conciliacion-osTicket-MGCI]
---

# 🖥️ Comparativa: Agent Panel de osTicket ⇄ Chatwoot (MGCI)

> Recorrido **página por página** del Agent Panel de osTicket (doc oficial),
> documentando cada pantalla y comparándola con lo que ya existe en Chatwoot / el
> módulo de tickets MGCI (`feat/tickets`).
>
> Leyenda: ✅ Chatwoot lo cubre · 🟡 parcial · ❌ falta · ➕ Chatwoot lo hace mejor

---

## 1. Dashboard (métricas históricas)

**Fuente:** `Agent/Dashboard/Dashboard.html`

Rastreador histórico de actividad del help desk, con filtro por fechas y export CSV.

**Agrupación (filas):** Departamentos · Help Topics · Agentes

**Columnas (6 métricas):**

| Métrica | Qué cuenta |
|---------|-----------|
| Opened | Tickets creados (incl. abiertos por agente en nombre del usuario) |
| Assigned | Asignados a agente/equipo (manual, reclamados, por filtro, help topic/org) |
| Overdue | Vencidos por violación de SLA (Open pasada la fecha límite) |
| Closed | En estado cerrado (baja si se reabren) |
| Reopened | Veces que pasó de Closed → Open |
| Deleted | Eliminados |

**Desempeño:** Service Time (promedio horas/ticket) · Response Time (promedio msg usuario → respuesta agente)

**Extras:** filtro por rango de fechas · export CSV.

**Comparación Chatwoot/MGCI:**
- 🟡 MGCI ya tiene vista **Metrics** (S3: oculta KPIs ITIL, grupo "Calidad" solo CSAT).
- ❌ **Export CSV** pendiente (P3 menor — osTicket "Data Extraction").
- 🟡 Agrupación por Departamento/Help Topic/Agente: verificar paridad.
- **Brechas candidatas:** columnas Opened/Assigned/Overdue/Reopened/Deleted lado a lado; Service/Response Time; export CSV.

---

## 2. Agent Directory (directorio de agentes)

**Fuente:** `Agent/Dashboard/Agent Directory.html`

Listado centralizado de **todos los agentes** del help desk. La doc no detalla
columnas/filtros (solo imagen `agent_dashboard_agentDir.png`).

**Comparación Chatwoot/MGCI:** ➕ **Chatwoot lo hace mejor.**
Chatwoot ya tiene `Settings > Agents`: rol (Admin/Agente), presencia (online/busy/offline),
invitar/editar/eliminar, asignación a inboxes y Teams, roles personalizados.
**Decisión: NO se replica** — Chatwoot lo cubre y gobierna permisos/presencia/enrutamiento.

---

## 3. My Profile (perfil del agente)

**Fuente:** `Agent/Dashboard/My Profile.html`

**Cuenta:** Nombre, Email, Teléfono, Extensión, Móvil, Username.

**Estado:** visibilidad de tickets asignados en cola "Open" · **Vacation Mode**
(suspende notificaciones/emails).

**Preferencias:** tamaño máx. de página · auto-refresh (min) · nombre remitente por
defecto · orden del hilo (asc/desc) · firma por defecto · tamaño papel PDF ·
redirección tras responder (cola vs ticket) · imágenes inline/descarga · interlineado editor.

**Localización:** zona horaria · formato de hora · idioma.

**Firma:** crear/guardar firma del agente.

**Comparación Chatwoot/MGCI:** mayormente ✅ cubierto.

| osTicket | Chatwoot |
|----------|----------|
| Nombre, email, teléfono | ✅ (+ avatar, display name) |
| Username/password | ✅ (+ 2FA, access token) |
| Firma | ✅ Message Signature por agente |
| Zona horaria/idioma | ✅ |
| Auto-refresh, page size, orden hilo | 🟡 parcial |
| Vacation Mode | 🟡 Chatwoot usa availability status (online/busy/offline), no "modo vacaciones" |

**Brechas candidatas (opcionales):**
- ❌ **Vacation Mode** explícito (suspender notificaciones por período).
- ❌ Preferencias finas de cola: page size, auto-refresh, redirección tras responder.
- 🟡 Tamaño papel PDF / impresión (liga con pendiente "P4 — imprimir").

---

## 4. User Directory (directorio de usuarios/contactos)

**Fuente:** `Agent/Users/User Directory.html`

Permite buscar tickets por usuario y crear Organizaciones para asociarlas al usuario.
**Email = identificador único** de cada usuario.

**Acciones de gestión:**
- Agregar usuario manual · importar por copy/paste · importar por CSV.
- Borrar usuario (obliga a borrar también sus tickets asociados).
- Asociar usuario a **Organización**.
- "Manage Account" (admin de cuenta) · reset password · forzar reset al login · bloquear (lock) usuario.

**Tipos de usuario:**
- **Registered**: con cuenta + email verificado → ve todos sus tickets en el help desk.
- **Guest**: sin registro, solo envía tickets.

**Datos:** las cabeceras CSV mapean al built-in "Contact Information" (perfil estructurado, personalizable por forms admin).

**Comparación Chatwoot/MGCI:** ➕ **Chatwoot lo hace mejor.**
Chatwoot tiene módulo **Contacts** completo: listado, búsqueda/segmentos/filtros,
import CSV, atributos personalizados, merge de contactos, notas, conversaciones previas,
y **Organización** (sección "Organización" en el panel de contacto — integración CRMZeus,
`ContactForm.vue`).

| osTicket | Chatwoot |
|----------|----------|
| Listar/buscar usuarios | ✅ Contacts + filtros/segmentos |
| Importar CSV | ✅ |
| Atributos de contacto | ✅ custom attributes |
| Organización | ✅ sección Organización (CRMZeus) |
| Registered vs Guest | 🟡 Chatwoot: contacto identificado vs anónimo (no es exactamente el portal/login del cliente) |
| Manage Account / reset password del cliente | ❌ — Chatwoot no da login al cliente (liga con **User Portal**, brecha #1 de [[Conciliacion-osTicket-MGCI]]) |

**Brecha candidata:** la "cuenta del usuario final" (login, ver sus tickets) es la
misma **superficie del cliente / User Portal** ya identificada como brecha #1.

---

## 5. Organizations (organizaciones)

**Fuente:** `Agent/Users/Organizations.html`

Una **Organización** agrupa varios usuarios bajo una entidad (empresa, cliente,
departamento…). Los tickets se rastrean por organización vía el email de cada usuario.

**Campos / settings:**
- **Account Manager** — agente o equipo asignado; recibe alertas del ciclo de vida del
  ticket y **los tickets se auto-asignan** a él.
- **Primary Contacts** — usuarios elegidos del roster; **auto-colaboran** en todos los
  tickets de la org y acceden por el client portal.
- **Auto-Add Domains** — dominios/subdominios de email (separados por coma); los usuarios
  que coincidan se agregan automáticamente a la organización.
- **Collaborator Settings** — primary contacts auto-colaboran; opcionalmente **todos** los
  miembros se agregan como colaboradores.
- **Custom Fields** — vía Admin > Forms > Built-in > "Organization Information".

**Acciones:** crear · editar · buscar/asociar usuarios · importar usuarios · asignar
account managers · configurar primary contacts · borrar.

**Comparación Chatwoot/MGCI:** 🟡 **parcial — gap notable.**
Chatwoot **no tiene un modelo nativo de Organización** con esta riqueza. Lo más cercano:
- La sección **"Organización"** del panel de contacto (`ContactForm.vue`) es una
  integración con **CRMZeus** (id externo), no un objeto Organization propio con roster.
- No hay: Account Manager por org, auto-asignación de tickets por org, primary contacts,
  auto-colaboradores, ni **auto-add por dominio de email**.

| osTicket | Chatwoot/MGCI |
|----------|---------------|
| Org agrupa usuarios | 🟡 solo `company_name` / id CRMZeus, sin roster real |
| Account Manager (auto-asigna tickets) | ❌ |
| Primary Contacts / auto-colaboradores | ❌ (ligaba con "Colaboradores/CC", **descartado 2026-07-28**) |
| Auto-Add por dominio de email | ❌ |
| Custom fields de org | 🟡 vía custom attributes del contacto, no de una entidad org |

**Brechas candidatas:**
- ❌ **Modelo Organization propio** (roster de contactos, no solo string/id externo).
- ❌ **Account Manager** por organización → auto-asignación de tickets.
- ❌ **Auto-add por dominio** de email.
- ❌ **Colaboradores/CC** — **descartado (2026-07-28)**, ya no está en P4 ni en el
  roadmap; encajaría con primary contacts si algún día se retoma.

> Nota: este es el gap más "estructural" del recorrido hasta ahora. Evaluar si MGCI
> necesita una entidad Organización real o si basta extender el contacto + CRMZeus.

---

## 6. Tasks (tareas)

**Fuente:** `Agent/Tasks/Tasks.html`

Una **Task** es un ítem de trabajo interno (to-do) visible solo para agentes con
acceso al departamento. Puede ir **ligada a un ticket** o ser **independiente (standalone)**.

**Diferencia clave con un ticket:** la tarea es interna (no client-facing) y crea una
**relación de bloqueo**: *"un ticket no puede cerrarse hasta que todas sus tareas estén
completas."*

**Campos:**
- Requeridos: Task Summary · Task Detail · Departamento asignado.
- Opcionales: Agente asignado · Due Date.
- Form personalizable (Admin > Forms > "Task Details").

**Asociación a ticket:** se crean desde arriba del hilo del ticket (bajo el header).
Múltiples tareas (ilimitadas) por ticket, en distintos departamentos/agentes. Un agente
asignado a una tarea sin acceso al depto del ticket ve solo metadata + su tarea, no el hilo.

**Cola/visibilidad:** pestaña **Tasks** del agente; solo tareas de los departamentos a los
que tiene acceso. Tareas ligadas muestran referencia al ticket en el header. Estado open/closed.

**Hilo/notas:** las tareas tienen su propio hilo de actividad; **colaboradores externos**
pueden agregarse para recibir updates (sin acceso al portal, solo notificaciones que
threadean de vuelta).

**Alertas (5):** New Task · New Activity · Task Assignment · Task Transfer · Overdue Task (SLA/due date).

**Comparación Chatwoot/MGCI:** ✅ **mayormente cubierto** (ya implementado en MGCI).
Pendiente.md vault-tickets: *"Tareas/subtareas (checklist) en el ticket ✅ hecho
(`case_tasks`, checklist con responsable/borrar/agregar, 'Tareas {done}/{total}')"* y
*"Bloqueo de ticket (lock) ✅"*.

| osTicket | MGCI |
|----------|------|
| Tarea ligada a ticket | ✅ `case_tasks` (checklist con responsable) |
| Contador done/total | ✅ "Tareas {done}/{total}" |
| Due date | 🟡 `due_at` existe en BD, **falta UI** (pendiente) |
| Bloqueo: ticket no cierra hasta completar tareas | 🟡 verificar si MGCI fuerza esto (tiene lock de edición, no necesariamente gating de cierre) |
| Tareas **standalone** (sin ticket) | ❌ MGCI las modela como checklist del ticket, no como objeto independiente |
| Hilo/actividad propio de la tarea + colaboradores | ❌ es checklist simple, sin hilo |
| Departamento asignado a la tarea | 🟡 tiene responsable (agente), no depto |
| 5 alertas de tarea | ❌ |
| Plantillas de checklist por tipo | ❌ (pendiente "Futuro Tareas") |

**Brechas candidatas:**
- 🟡 **Due date UI** (campo ya existe) — pendiente ya listado.
- ❓ **Gating de cierre** (no cerrar ticket con tareas abiertas) — confirmar/implementar.
- ❌ Tareas **standalone** + hilo propio + alertas — solo si se busca paridad fuerte
  (MGCI hoy las trata como checklist ligero, decisión pragmática).
- ❌ Plantillas de checklist por tipo de caso (pendiente "Futuro Tareas").

---

## 7. Advanced Search (búsqueda avanzada + colas guardadas)

**Fuente:** `Agent/Tickets/Advanced Search.html`

Búsqueda de tickets por múltiples criterios, con capacidad de **guardar la búsqueda como
cola personalizada**. (La doc no enumera todos los filtros, pero el motor de osTicket
soporta: keyword, estado, prioridad, departamento, agente asignado, help topic, fechas y
custom fields.)

**Features:**
- **Saved Searches** — guardar búsqueda con título; aparece como columna/cola en el panel; editable.
- **Custom Columns** — desmarcar "Use standard columns" para elegir qué campos se muestran
  (el admin define columnas disponibles por cola en Admin > Columns).
- **Quick Filters** — desde la pestaña Settings; filtran aún más sobre la búsqueda guardada.
- **Sortable Fields** — el agente designa qué columnas son ordenables en su cola custom.
- El admin controla qué campos están disponibles por cola.

**Comparación Chatwoot/MGCI:** 🟡 **parcial.**
Chatwoot tiene búsqueda y **filtros guardados / segmentos** (en Conversations y Contacts),
y MGCI ya tiene **colas como pestañas (`QUICK_FILTERS`)** + tabla densa con **cabeceras
ordenables** (pendiente P3 ✅ hecho).

| osTicket | Chatwoot/MGCI |
|----------|---------------|
| Búsqueda multi-criterio | ✅ filtros de conversación/contacto; 🟡 verificar en cola de tickets MGCI |
| Saved searches → cola | 🟡 MGCI tiene `QUICK_FILTERS` (pestañas predefinidas), no "guardar mi búsqueda" libre por agente |
| Custom columns por cola | 🟡 P3 menor pendiente: "persistir orden/columnas por usuario" |
| Quick filters sobre la cola | 🟡 parcial |
| Cabeceras ordenables | ✅ (P3 hecho) |

**Brechas candidatas:**
- 🟡 **Saved searches por agente** (guardar mi propio filtro como cola), vs las pestañas fijas actuales.
- 🟡 **Custom columns persistentes por usuario** (ya listado en P3 menor: "persistir orden/columnas por usuario").
- 🟡 Búsqueda avanzada multi-criterio dentro de la cola de tickets (confirmar alcance actual).

---

## 8. Tickets (cola + ficha del ticket) ⭐ núcleo

**Fuente:** `Agent/Tickets/Tickets.html`

La pantalla central del agente: las **colas** y la **ficha del ticket**.

### Colas (5, superpuestas)
1. **Open** — nuevos + donde respondió el usuario (número en **negrita**).
2. **Answered** — esperan respuesta del usuario (no-negrita; colapsable en Open).
3. **My Tickets** — asignados al agente o su equipo.
4. **Overdue** — exceden SLA/due date.
5. **Closed** — cerrados (reabren si el usuario responde).

**Orden:** por Prioridad, luego por última actualización. Columnas ordenables, pero
vuelve al orden Prioridad/Fecha en cada login. **Preview** al pasar el mouse (metadata + quick actions).

### Ficha del ticket
- **Reply box:** texto + adjuntos/links/YouTube, **canned responses**, agregar
  colaboradores, dropdown de estado, "Do Not Email Reply".
- **Header:** campos de built-in forms + custom forms del Help Topic.
- **Print (PDF):** ticket estándar, Thread, Thread+Notas, +Eventos, +Adjuntos, +Tareas.
- **Acciones primarias:**
  - **Edit** (campos + custom forms)
  - **Change Status** (sin requerir respuesta; nota en popup)
  - **More:** Change Owner · Merge · Link · Release (desasignar) · Mark Answered/Unanswered ·
    Manage Forms · **Ban Email** · **Delete** (irreversible, motivo a System Logs)
- **User Info:** dueño + contador de tickets → ver open/closed/all del usuario, Manage User,
  Manage Organization; click en nombre = editar contacto / cambiar dueño.
- **Thread color-coded:** 🔵 azul = respuesta del dueño/colaborador · 🟡 amarillo = nota
  interna + acciones (transfers/asignaciones) · 🟠 naranja = respuesta del agente.
- **System Notes:** toda acción sobre user/colaboradores/ticket queda como nota interna en el hilo.

**Comparación Chatwoot/MGCI:** ✅ **muy cubierto** — es lo más trabajado de MGCI.

| osTicket | MGCI/Chatwoot |
|----------|---------------|
| Colas Open/Answered/My/Overdue/Closed | ✅ `QUICK_FILTERS` como pestañas; orden por prioridad/fecha |
| Negrita/no-negrita por estado | 🟡 MGCI usa badges/`displayStatus` (modo simple colapsa) |
| Cola tabla densa + cabeceras ordenables + selección múltiple + lote | ✅ (P3 hecho: bulk Tomar/Asignar/Estado/Cerrar) |
| Reply al cliente desde el ticket | ✅ (U1: pestaña Conversación + caja de respuesta + IA) |
| Canned responses en la caja | 🟡 vía "Ir a la conversación" (ReplyBox nativo); caja del ticket es simple a propósito |
| Cambiar estado/prioridad/asignar inline | ✅ (P1: barra Tomar/Prioridad/Estado sin modal) |
| Merge / Link tickets | 🟡 confirmar (Chatwoot tiene merge de **contactos**; merge de **tickets** = ?) |
| Change Owner (reasignar contacto del ticket) | 🟡 confirmar |
| Ban Email | 🟡 Chatwoot puede bloquear contacto; "ban email" como tal = confirmar |
| Print / PDF con niveles | ❌ pendiente (P4 "imprimir") |
| Thread color-coded (azul/amarillo/naranja) | 🟡 Chatwoot distingue mensaje/privado/sistema, otra estética |
| System notes de toda acción | ✅ Chatwoot tiene activity log/notas de sistema |
| Custom forms por Help Topic en el header | 🟡 MGCI usa tipos de caso + atributos, no forms dinámicos por topic |

**Brechas candidatas:**
- ❌ **Print / PDF** del ticket con niveles (Thread, +Notas, +Adjuntos, +Tareas) — pendiente P4.
- 🟡 **Merge / Link tickets** — confirmar si existe; osTicket lo usa para duplicados/relacionados.
- 🟡 **Canned responses dentro de la caja del ticket** (hoy se delega a "Ir a la conversación").
- 🟡 **Ban Email / bloquear remitente** desde el ticket.
- 🟡 **Custom forms por Help Topic** en el header (vs tipos+atributos actuales).
- 🟡 **Print niveles** ligado a preferencia "tamaño papel PDF" de My Profile (#3).

> Conclusión: el corazón (colas, reply, acciones inline, lote, asignación, estados) **ya
> está**. Las brechas son "remates" osTicket: imprimir/PDF, merge/link, canned en caja,
> ban email.

### 8.1 Ticket Header — botones de acción rápida (⭐ a considerar para MGCI)

> Encabezado del ticket en MGCI: `TicketDetail.vue:1029` (`<!-- Header -->`). Las acciones
> van **arriba a la derecha** y deben respetar **permisos del rol/grupo** del agente.

osTicket coloca en la esquina superior derecha del header estos botones (visibles según
permisos del grupo del agente):

**🖨️ Imprimir** — imprime el ticket o lo descarga como **PDF** (PDF con icono de archivo,
ZIP con icono de carpeta). Con **niveles** seleccionables:
1. **Hilo del ticket** — todo el hilo, *excluye* notas internas y eventos.
2. **Hilo + Notas internas** — incluye notas internas, *excluye* eventos.
3. **Hilo + Notas internas + Eventos** — incluye notas internas y eventos del hilo.
4. **Hilo + Notas internas + Archivos adjuntos** — incluye notas internas y adjuntos.
5. **Hilo + Notas internas + Archivos adjuntos + Tareas** — todo lo anterior + tareas.

**✏️ Editar** — edita campos del ticket, incluidos **formularios personalizados** añadidos
tras crear el ticket.

**🔄 Cambiar estado** — cambia el estado **sin requerir respuesta**; abre un **popup** para
añadir notas junto con el cambio.

**⋯ Más (More)** — opciones según permisos del rol: Change Owner · Merge · Link · Release ·
Mark Answered/Unanswered · Manage Forms · Ban Email · Delete.

**Mapeo contra el header actual de MGCI (`TicketDetail.vue:1029`):**

| Botón osTicket | MGCI hoy | A considerar |
|----------------|----------|--------------|
| 🖨️ **Imprimir / PDF** (5 niveles) | ❌ no existe | **Agregar botón Print** con menú de niveles (Hilo / +Notas / +Eventos / +Adjuntos / +Tareas) → genera PDF. Liga con preferencia "tamaño papel PDF" (My Profile #3) y pendiente **P4 imprimir**. |
| ✏️ **Editar** (+ custom forms) | 🟡 parcial (edición inline de campos) | Confirmar edición completa de campos + **formularios personalizados** post-creación |
| 🔄 **Cambiar estado** (popup + nota) | ✅ barra inline P1 (Estado) | 🟡 agregar **popup para nota al cambiar estado** (hoy puede no pedir nota) |
| ⋯ **Más**: Change Owner | 🟡 confirmar | reasignar dueño/contacto del ticket |
| ⋯ **Más**: Merge / Link | 🟡 confirmar | unir duplicados / relacionar tickets |
| ⋯ **Más**: Release (desasignar) | 🟡 confirmar | liberar asignación |
| ⋯ **Más**: Mark Answered/Unanswered | ❌ | marcar respondido/no respondido (estética de colas) |
| ⋯ **Más**: Manage Forms | 🟡 | adjuntar/quitar formularios al ticket |
| ⋯ **Más**: Ban Email | 🟡 (Chatwoot bloquea contacto) | bloquear remitente desde el ticket |
| ⋯ **Más**: Delete (motivo → logs) | 🟡 confirmar | borrar con motivo a logs |
| **Permisos por rol/grupo** | 🟡 | **gating de visibilidad** de cada botón según rol del agente |

**Acción recomendada:** agrupar estos en el header como **(1) Imprimir** (menú de niveles),
**(2) Editar**, **(3) Cambiar estado** (con popup de nota), y **(4) menú "Más"** con las
acciones avanzadas — todo condicionado a **permisos del rol**. El de mayor valor/menor
ambigüedad es **Imprimir/PDF** (P4) y el **popup de nota en Cambiar estado**.

### 8.2 OBSERVADO en capturas reales (practicidad / layout) 👁️

> Descargadas de la doc oficial (`_images/`) y vistas directamente. Esto NO es inferido del
> texto: es el layout real que MGCI debe sentir.

**Cola de tickets (`agent_tickets_ticket_ticketQueue.png`):**
- Pestañas principales arriba: Dashboard · Users · Tasks · **Tickets** · Knowledgebase.
- Sub-pestañas de cola **con contador en vivo**: `Open (17)` · `Answered (3)` ·
  `My Tickets (15)` · `Overdue (3)` · `Closed` · `New Ticket` (cada una con icono).
- Buscador + enlace **`[advanced]`** + **Sort** (arriba derecha).
- Heading "Open Tickets" + **iconos de acción de lote** a la derecha (flag, asignar, transferir, borrar).
- Tabla: ☐ · **Number** (icono de estado) · Last Updated · **Subject** (iconos 📎 adjunto,
  💬N conversación, 👥 colaboradores) · From · **Priority** (celda con fondo de color) ·
  Assigned To — **todas las columnas ordenables** (↕).
- **Practicidad clave:** contadores en cada pestaña, columnas ordenables, iconos de estado
  en el número, indicadores inline en el subject, barra de lote contextual.

**Ticket Header (`agent_tickets_ticket_ticketHeader.png`):**
- `Ticket #<folio>` (con refresh) arriba-izq; **asunto** debajo.
- **Barra de iconos** arriba-der (en este orden): ↩ responder · 📄 nota · 🚩 flag▾ ·
  👤 asignar▾ · ↗ transferir · 🖨 imprimir▾ · ✏️ editar · ⚙️ engrane▾ (Más).
- **Grid de datos a 2 columnas:**
  - Izq: Status · Priority · Department · Create Date.
  - Der: **User: Nombre (N)** ← contador de tickets del cliente · Email · **Organization: X (N)** ·
    Source.
  - 2ª fila: Assigned To · SLA Plan · Due Date | Help Topic · Last Message · Last Response.

**Menú "Más" real (`agent_tickets_ticket_moreOptions.png`):**
Change Owner · Mark as Answered · **Manage Referrals** · Manage Forms · **Manage Collaborators** ·
Ban Email <email> · Delete Ticket.
(Nota: la captura muestra "Manage Referrals" y "Manage Collaborators"; en versiones la doc
texto lo llamaba Merge/Link — el concepto es relacionar/derivar tickets + colaboradores.)

**Qué de esto le falta a MGCI (`TicketDetail.vue:1029`) — practicidad:**
- ❌ **Barra de iconos compacta** en el header (responder/nota/flag/asignar/transferir/imprimir/editar/más). MGCI tiene botones inline P1, pero no este set completo tipo toolbar.
- ❌ **Print▾** y **engrane "Más"** (Change Owner, Referrals, Forms, Collaborators, Ban Email, Delete).
- 🟡 **Grid de datos a 2 columnas** con User(N)/Organization(N) y contadores — MGCI muestra badges + título, valdría un bloque de datos tipo ficha osTicket.
- ✅ **Contadores en pestañas de cola** + **columnas ordenables** — MGCI ya lo tiene (P3).
- 🟡 **Iconos de estado/indicadores en la fila** (adjunto/conversación/colaboradores en el subject).

> Para más pantallas: descargar de `https://docs.osticket.com/en/latest/_images/<nombre>.png`
> (los nombres salen del HTML de cada página) y verlas para fidelidad visual real.

---

## 9. Personal Queues (colas personales)

**Fuente:** `Agent/Tickets/Personal Queues.html`

Vistas de tickets con criterio propio que **cada agente** crea — **privadas** (solo las
ve quien las crea). Complementan a las saved searches/colas estándar.

**Crear:** dropdown en la pestaña Tickets → "Add Personal Queue" → definir criterio → guardar.
**Editar:** botón settings junto al título → Edit.

**Custom columns:** agregar/renombrar/ancho/quitar/reordenar (drag-and-drop) campos no
visibles por defecto. **Sortable** por columna. **Quick Filters** desde el top de la cola.
**Herencia:** la nueva cola hereda columnas de una cola padre (típico "Open"), desmarcable
para personalizar 100%.

**Comparación Chatwoot/MGCI:** 🟡 **parcial — misma familia de brechas que #7.**
MGCI tiene colas fijas (`QUICK_FILTERS` como pestañas), no "crea tu propia cola privada".
Chatwoot sí tiene **Custom Views / filtros guardados** en Conversations y Contacts (segmentos),
patrón reutilizable.

| osTicket | Chatwoot/MGCI |
|----------|---------------|
| Cola privada por agente con criterio propio | 🟡 Chatwoot tiene Custom Views en Conversations; falta en cola de tickets |
| Custom columns (add/rename/width/reorder) | 🟡 P3 menor pendiente "persistir orden/columnas por usuario" |
| Sortable por columna | ✅ (P3 hecho) |
| Quick filters en el top | 🟡 parcial |
| Herencia de cola padre | ❌ |

**Brechas candidatas:**
- 🟡 **Colas personales/Custom Views** para tickets (reusar el patrón de Custom Views de
  conversaciones de Chatwoot). Mismo bucket que "Saved searches" (#7).
- 🟡 **Custom columns configurables + reorder** (ya en P3 menor).

> Observación: #7 (Advanced Search) y #9 (Personal Queues) son **la misma capacidad**
> ("colas a la medida del agente"). Conviene tratarlas como **una sola brecha**:
> reusar Custom Views + columnas persistentes.

---

## 10. Knowledgebase (base de conocimiento + canned responses)

**Fuente:** `Agent/Knowledgebase/Knowledgebase.html`

Dos componentes: **FAQs** (categorías + artículos) y **Canned Responses**.

**FAQs:**
- Categorías (anidables) → FAQs ilimitadas; click en categoría → "Add a New FAQ".
- Artículo: HTML/Rich Text, **adjuntos**, asociación a **Help Topics**.
- **Visibilidad:** private (interno) o public (cliente) — para ser público, **categoría Y FAQ**
  deben marcarse Public.

**Canned Responses:**
- Disponibles por departamento o toda la organización.
- Toolbar HTML/Rich Text (imágenes, gráficos, links).
- **Variables** (se reemplazan automáticamente).
- Adjuntos (removibles antes de enviar).

**Client Portal:** la KB se habilita en Admin > Settings > Knowledgebase; el cliente filtra
FAQs por Help Topic.

**Comparación Chatwoot/MGCI:** ➕ **Chatwoot lo hace mejor / ya existe.**
- **FAQs/artículos públicos** → Chatwoot **Help Center** (portales, categorías, artículos,
  público). Más completo que las FAQs de osTicket.
- **Canned responses** → Chatwoot tiene **Canned Responses** nativas (con variables/short codes).
- ➕ Además MGCI/Chatwoot tiene **Base de Conocimiento con embeddings + búsqueda semántica**
  (Knowledge Sources, pgvector, sync Discourse/Google Docs/Sheets) — muy por encima de FAQs estáticas.

| osTicket | Chatwoot/MGCI |
|----------|---------------|
| FAQ categorías/artículos públicos | ✅ Help Center (portales/categorías/artículos) |
| Private vs public | ✅ (artículos draft/published; Help Center público) |
| Canned responses + variables | ✅ Canned Responses nativas |
| Adjuntos en respuesta | ✅ |
| Asociar artículo a Help Topic | 🟡 Chatwoot organiza por categoría/portal, no por "help topic" |
| Búsqueda semántica / IA | ➕ Knowledge Sources (embeddings, Discourse, Google Docs/Sheets) |

**Brechas candidatas:** prácticamente ninguna estructural.
- 🟡 (menor) Asociar artículos KB ↔ tipo de caso/Help Topic para sugerencias contextuales.

> Conclusión: KB y canned responses **están cubiertos y superados** por Chatwoot
> (Help Center + Canned Responses + Knowledge Sources con IA). No se replica osTicket.

---

## 11. User Portal (superficie del cliente) ⭐⭐ brecha #1 histórica

**Fuente:** `User Portal.html` (índice; subpáginas: Open A Ticket, Check Ticket Status, Knowledgebase)

La cara del **cliente final**. Tres secciones:
1. **Open A Ticket** — el cliente abre un ticket (form con Help Topic, campos, captcha, adjuntos).
2. **Check Ticket Status** — consulta su ticket por **email + número de folio** (guest) o por
   **login/registro** (cuenta).
3. **Knowledgebase** — autoservicio (FAQs públicas).

**Acceso:** guest (email + folio, sin registro) o registered (login; ve todos sus tickets,
hilo, y **responde**).

**Comparación Chatwoot/MGCI:** 🟢 **YA IMPLEMENTADO (Fase P1)** — era la brecha #1 de
[[Conciliacion-osTicket-MGCI]] y se construyó.

Según `implementacion/Pendiente.md` (vault-tickets):
- ✅ **Admin UI del portal** — "Portales del cliente" (`Portals.vue`, CRUD) + toggle público por tipo en `TicketTypes.vue`.
- ✅ **Admin elige inbox destino** (API/Email) — selector "Canal destino"; acuse por ese canal.
- ✅ **R2 — destino WhatsApp + plantilla de acuse** (config/lógica/UI). ⚠️ falta verificación real (WhatsApp + plantilla aprobada en Meta).
- Servicios: `PortalTicketService`, `PortalThreadSeeder`; tabla `case_portals` (con `custom_domain`).

| osTicket | MGCI |
|----------|------|
| Open A Ticket (form público) | ✅ portal público por tipo de caso |
| Check Ticket Status (email + folio) | ✅ folio + acuse por canal |
| Login / cuenta registrada | 🟡 MGCI usa folio + canal (chat/WhatsApp/email), **no login del cliente** (decisión: sin registro) |
| Knowledgebase pública | ✅ Help Center |
| Responder desde el portal | 🟡 el cliente responde **por su canal** (chat/WhatsApp/email), no en una web con login |
| Captcha/adjuntos en form | 🟡 adjuntos: pendiente "límites + throttle"; captcha = confirmar |

**Pendientes ya listados (no nuevos):**
- 🟡 i18n `en` del portal · Tailwind a build de assets · verificación real R2 (WhatsApp).
- 🟡 Adjuntos: límites + throttle anti-spam · Dominio propio (subdominio/marca blanca).
- 🟡 Acuse por email cuando la conversación nace en inbox Portal.

> Conclusión: la brecha **más importante del proyecto ya está resuelta en su núcleo (P1)**.
> Diferencia de enfoque: osTicket = portal web con login opcional; MGCI = **folio + el propio
> canal del cliente** (chat/WhatsApp/email), sin obligar registro. Quedan remates (i18n,
> assets, adjuntos límites, dominio propio, verificación WhatsApp).

---

## 11.1 User Portal → Open A Ticket (form del cliente)

**Fuente:** `User/Ticket/Open A Ticket.html`

El form con que el cliente abre un ticket.

**Campos:**
- Contacto requerido: **email**, nombre del dueño, teléfono, etc.
- **Help Topic** (dropdown) — dirige/encauza la info; al elegirlo puede **cambiar el form**
  (campos según el topic).
- **Issue Summary** (como el "asunto" de un correo) + cuerpo del mensaje.
- HTML Rich Text (toolbar), subir **fotos/videos**, links.
- (La doc no menciona explícitamente: prioridad, custom fields, captcha, guest vs login.)

**Envío:** botón **"Create Ticket"** → pantalla de **confirmación** del ticket creado.

**Comparación Chatwoot/MGCI:** ✅ **cubierto (P1)** — el portal MGCI ya tiene form público
por tipo de caso con acuse/folio.

| osTicket | MGCI |
|----------|------|
| Form con email/nombre/teléfono | ✅ form público del portal |
| Help Topic que cambia el form | 🟡 MGCI: **tipo de caso**; campos dinámicos por topic = confirmar alcance |
| Issue summary + cuerpo | ✅ |
| Adjuntos (foto/video/links) | 🟡 funciona; pendiente **límites + throttle** |
| "Create Ticket" → confirmación/folio | ✅ acuse con folio por el canal |
| Rich Text en el form | 🟡 confirmar (MGCI form más simple) |

**Brechas candidatas (menores, ya en pendientes):**
- 🟡 **Campos dinámicos por tipo/topic** en el form público (paridad con Help Topic forms).
- 🟡 **Adjuntos: límites + throttle** (ya listado).
- 🟡 (opcional) Rich Text en el cuerpo del form.

---

## 11.2 User Portal → Check Ticket Status (consulta del cliente)

**Fuente:** `User/Ticket/Check Ticket Status.html`

Dos formas de que el cliente consulte su ticket:

**Método 1 — Guest (email + folio):** en la página principal, botón "Check Ticket Status" →
ingresa email + número de ticket → el sistema **envía un access link al email** con el hilo
del ticket (acceso temporal sin registro).

**Método 2 — Cuenta registrada:** registro + confirmación por email → login → ve una
**cola con todos sus tickets** (dashboard unificado).

**Qué ve:** registered = cola de todos sus tickets; guest = estado del ticket vía el link
por email. (La doc no detalla responder/adjuntar, solo confirma el acceso al hilo.)

**Comparación Chatwoot/MGCI:** 🟡 **enfoque distinto — cubierto por el canal, no por web.**
MGCI **no usa "email + folio" ni login**: el cliente sigue su ticket por **su propio canal**
(chat/WhatsApp/email) donde recibió el folio y el acuse. El hilo del ticket = la conversación
de Chatwoot que el cliente ya tiene en su canal.

| osTicket | MGCI |
|----------|------|
| Guest: email + folio → access link | 🟡 no aplica; el cliente ya tiene el hilo en su canal |
| Registered: login + cola de "mis tickets" | ❌ **no hay login del cliente** (decisión de diseño) |
| Responder desde el portal | 🟡 el cliente responde **por su canal**, no en web |
| Directiva `@estado_ticket` (consultar estado por chat) | 🟡 **pendiente P2** (consultar estado por el canal sin teclear folio) |

**Brechas candidatas:**
- 🟡 **Directiva bot `@estado_ticket`** (P2, ya listada) — que el cliente pregunte el estado
  por su canal sin folio. Es el equivalente MGCI a "Check Ticket Status".
- ❓ **¿Login/cola web de "mis tickets"?** — decisión consciente de NO hacerlo (MGCI apuesta
  por el canal). Solo reconsiderar si un cliente lo pide explícitamente.

> Conclusión: osTicket resuelve "seguimiento" con **portal web (email+folio / login)**;
> MGCI lo resuelve con **el canal del cliente + folio + (futuro) `@estado_ticket`**. Es la
> misma diferencia de enfoque del User Portal (#11): web con login vs canal nativo.

---

## 11.3 User Portal → Knowledgebase (autoservicio del cliente)

**Fuente:** `User/Knowledgebase/Knowledgebase.html`

El "FAQ Center" del cliente: autoservicio para **desviar tickets** (*ticket deflection*).
*"Pre-poblando artículos con help topics de FAQs, los clientes se ayudan solos con los
problemas comunes, reduciendo la espera."*

**Acceso:** links de artículos al pie de la página principal, o botón "Knowledgebase".
**Visibilidad:** público en la portada, o requerir login.

**Comparación Chatwoot/MGCI:** ➕ **Chatwoot lo hace mejor** (igual que #10).
Chatwoot **Help Center** ya es un portal público de autoservicio (categorías, artículos,
búsqueda, multi-portal, SEO), más completo que el FAQ Center de osTicket; más el módulo de
**Knowledge Sources con IA** para respuestas asistidas.

| osTicket | Chatwoot/MGCI |
|----------|---------------|
| FAQ Center público (ticket deflection) | ✅ Help Center público |
| Browse por categoría/help topic | ✅ categorías/portales (🟡 no por "help topic") |
| Búsqueda | ✅ (➕ búsqueda semántica vía Knowledge Sources) |
| Login opcional para ver KB | 🟡 Help Center suele ser público; gating por login = confirmar |

**Brechas candidatas:** ninguna estructural (lado cliente cubierto por Help Center).
- 🟡 (menor) Sugerir artículos KB **antes** de abrir ticket en el portal (deflection activo).

> Conclusión: autoservicio del cliente **cubierto/superado**. No se replica.

---

## 📌 Resumen del recorrido (Agent Panel + User Portal)

| # | Página osTicket | Estado vs Chatwoot/MGCI |
|---|-----------------|--------------------------|
| 1 | Dashboard (métricas) | 🟡 Metrics existe; falta **export CSV** |
| 2 | Agent Directory | ➕ Chatwoot mejor — no se replica |
| 3 | My Profile | ✅ cubierto; opcional **Vacation Mode** |
| 4 | User Directory | ➕ Chatwoot mejor; gap = User Portal |
| 5 | **Organizations** | 🟡 **gap estructural** (Org como objeto, account manager, auto-add dominio) |
| 6 | Tasks | ✅ cubierto; 🟡 due date UI, gating de cierre |
| 7 | Advanced Search | 🟡 colas a medida del agente |
| 8 | **Tickets (núcleo)** | ✅ muy cubierto; ❌ print/PDF, 🟡 merge/link, canned en caja, ban email |
| 9 | Personal Queues | 🟡 (= #7, misma brecha: Custom Views + columnas) |
| 10 | Knowledgebase | ➕ Chatwoot mejor (Help Center + Knowledge Sources IA) |
| 11 | **User Portal** | 🟢 **YA IMPLEMENTADO (P1)**; quedan remates |

**Las brechas que realmente quedan (priorizadas):**
1. 🟡 **Organizations** como entidad real (account manager → auto-asigna, auto-add por dominio, colaboradores) — el gap más estructural.
2. ❌ **Print / PDF** del ticket (P4) + 🟡 **Merge/Link**, **Ban Email**, **Canned en la caja** — remates osTicket en la ficha.
3. 🟡 **Colas a medida del agente** (Advanced Search + Personal Queues = una sola: reusar Custom Views + columnas persistentes).
4. ❌ **Export CSV** del Dashboard/Metrics.
5. 🟡 Remates del **User Portal** (i18n, assets, adjuntos límites, dominio propio, verificación WhatsApp).
6. 🟡 (opcional) **Vacation Mode**, due date UI de tareas, gating de cierre por tareas.

---

## 📸 Apéndice visual — OBSERVADO en capturas reales (practicidad y navegación)

> Imágenes descargadas de `docs.osticket.com/.../_images/` y vistas directamente. Foco en
> **layout, navegación y practicidad** (no solo campos). Esto es lo que MGCI debe "sentir".

**Navegación global (todas las pantallas):** barra superior de pestañas fija:
`Dashboard · Users · Tasks · Tickets · Knowledgebase`. Cada pestaña abre una **2ª fila de
sub-pestañas** con iconos (ej. Dashboard → Dashboard / Agent Directory / My Profile).
Patrón consistente = el agente siempre sabe dónde está y cómo cambiar de área.

**Dashboard** (`agent_dashboard_dashboard.png`): selector "Report timeframe" (ej. Last month)
+ period + Refresh; **gráfico de líneas "Ticket Activity"** con 5 series (created/closed/
reopened/assigned/overdue, con leyenda de colores). Debajo va la tabla de stats por
Depto/Topic/Agente. → MGCI Metrics: **falta el gráfico de líneas temporal** + export CSV.

**My Profile** (`agent_dashboard_myProf.png`): "My Account Profile" con pestañas
**Account / Preferences / Signature**. Account = Name (first/last), Email, Phone+Ext, Mobile,
Username + **Change Password**; sección "Status and Settings" con ☐ *Show assigned tickets on
open queue* y ☐ **Vacation Mode**. Botones Save/Reset/Cancel. → MGCI: Vacation Mode no existe.

**User Directory** (`agent_users_userDir_dir.png`): buscador; botones **Add User · Import ·
More▾**; tabla ☐/Name(con contador de tickets)/Status(*Active (Registered)* vs *Guest*)/
Created/Updated, **columnas ordenables**; Select All/None/Toggle; Page + **Export**.
→ Chatwoot Contacts lo cubre/supera.

**Organizations** (`agent_users_org_settings.png`): modal con pestañas **Fields / Settings**.
Settings = **Account Manager** (dropdown) · **Auto-Assignment** ☐ *"Assign tickets from this
organization to the Account Manager"* · **Primary Contacts** (select) · **Ticket Sharing**
(*Primary contacts see all tickets*) · **Automated Collaboration** (Primary Contacts / Org
Members → add to all tickets) · **Email Domain → Auto Add Members From**. → **El gap
estructural confirmado al pixel**: MGCI no tiene este objeto Organización con automatización.

**Tasks** (`agent_tasks_tasks.png`): **pestaña de primer nivel** con cola propia:
sub-tabs `Open (N)` · `My Tickets/My Tasks (N)` · `New Task`; buscador + Sort; iconos de lote
(flag/asignar/transferir/borrar); tabla Number/Date Created/Title/Department/Agent ordenable;
Export. → MGCI trata tareas como **checklist del ticket**, no como cola/objeto independiente.

**Ticket Queue** (`agent_tickets_ticket_ticketQueue.png`): sub-tabs con **contador en vivo**
`Open(17)/Answered(3)/My Tickets(15)/Overdue(3)/Closed/New Ticket`; buscador + **[advanced]**
+ Sort; heading "Open Tickets" con iconos de lote; tabla con iconos de estado en el Number e
indicadores en el Subject (📎/💬N/👥), columnas ordenables, Priority con celda de color.

**Ticket Header** (`agent_tickets_ticket_ticketHeader.png`): `Ticket #folio` + asunto;
**barra de iconos** der: ↩ responder · 📄 nota · 🚩 flag▾ · 👤 asignar▾ · ↗ transferir ·
🖨 imprimir▾ · ✏️ editar · ⚙️ más▾; **grid de datos 2 columnas** (Status/Priority/Dept/Create |
User(N)/Email/Organization(N)/Source; Assigned/SLA/Due | HelpTopic/LastMsg/LastResponse).

**Menú "Más"** (`agent_tickets_ticket_moreOptions.png`): Change Owner · Mark as Answered ·
Manage Referrals · Manage Forms · Manage Collaborators · Ban Email <email> · Delete Ticket.

**Reply box** (`agent_tickets_ticket_ticketReply.png`): pestañas **Post Reply / Post Internal
Note**; To (destinatario) · **Collaborators** (Recipients N of N) · **Response: Select a canned
response** (dropdown) · **editor rico** (code/¶/font/B/I/U/color/highlight/strike/listas/
indent/imagen/video/tabla/link/align/hr) · **Drop files** · Signature (radio) · **Ticket
Status** (dropdown) · Post Reply/Reset. → MGCI delega esto a "Ir a la conversación"; el canned
en la caja y el selector de status inline son la diferencia.

**User Information** (`agent_tickets_ticket_userInformation.png`): modal `Ticket #: Nombre`,
avatar + email + org + **Change User**; pestañas **User / Organization / Notes**; Contact
Information (Phone, Internal Notes) + iconos editar/forward.

**Thread color-coded** (`internalNote.png` = banner amarillo nota interna; `agentReply.png` =
respuesta agente): header con autor + fecha + título + acción▾.

**Advanced Search** (`advsearch_new.png`): modal "Advanced Ticket Search" con **My Searches**
(dropdown), pestañas **Criteria / Columns**; criterios como checkboxes (TicketStatus/State,
Department, Assignee, Help Topic, Create Date, SLA Due Date) + **Add Other Field**; **Save
Search**; Cancel/Search.

**Personal Queues** (`cccc_personal_queue_created.png`): en la pestaña Tickets, dropdowns
**Open▾ / Closed▾ / Search▾ / New Ticket**. El **Open▾** despliega: colas estándar con contador
(Open 11 / Unanswered 2 / Unassigned 0 / My Tickets 10) — separador — **personales** (My Custom
View 1 / New Personal Queue 10) + **+ Add Personal Queue**. → Patrón de navegación de colas a
medida del agente; MGCI tiene pestañas fijas.

**User Portal — Open a New Ticket** (`user_ticket_open_openPage.png`): header "SUPPORT CENTER",
"Guest User | Sign In"; nav **Support Center Home / Open a New Ticket / Check Ticket Status**;
form Contact Information (Email* / Full Name* / Phone+Ext) + **Help Topic*** (al elegirlo
expande el form); Create Ticket/Reset/Cancel. → MGCI ya tiene portal P1 (enfoque por tipo+canal).

**User Portal — Check Ticket Status** (`user_ticket_stat_checkStatusLogin.png`): Email Address +
Ticket Number → **Email Access Link** (guest); a la derecha *"Have an account? Sign In or
register to access all your tickets"*. → MGCI lo resuelve por el **canal del cliente + folio**
(sin login); equivalente futuro = directiva `@estado_ticket`.

**Brechas de practicidad/navegación que surgen de lo observado:**
1. **Barra de iconos compacta** en el header del ticket (toolbar) + grid de datos 2 columnas
   con User(N)/Organization(N).
2. **Canned response + selector de status dentro de la caja de respuesta** (hoy se delega).
3. **Print▾** con niveles y menú **"Más"** (Change Owner/Referrals/Forms/Collaborators/Ban/Delete).
4. **Gráfico de líneas temporal** en Metrics + export CSV.
5. **Colas a medida del agente** vía dropdown (Open▾ con personales + "Add Personal Queue").
6. **Organización como objeto** con Account Manager/Auto-Assign/Auto-Add por dominio (estructural).
7. **Vacation Mode** en el perfil.
8. **Tareas como cola/objeto** (no solo checklist) — opcional.

---

## 🔗 Relacionado
- [[Referencia-osTicket]] · [[Conciliacion-osTicket-MGCI]] · [[00-Indice]]
