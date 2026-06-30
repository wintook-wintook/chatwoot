---
titulo: Plan — Adaptación Agent Panel osTicket → Chatwoot (MGCI)
tipo: plan
tags: [tickets, osticket, chatwoot, ux, plan, esfuerzo, roadmap]
fecha: 2026-06-30
estado: PROPUESTA (solo plan, sin implementar)
relacionado: [Comparativa-Agent-Panel-osTicket, Plan-Practicidad-osTicket, Plan-User-Portal, Pendiente]
---

# 🗺️ Plan de implementación — Adaptar la practicidad de osTicket a MGCI

> Deriva de [[Comparativa-Agent-Panel-osTicket]] (recorrido página-por-página + apéndice
> visual observado). Aquí: **qué adaptar, cuánto cuesta y en qué orden.**
>
> Principio rector: **no se copia osTicket, se viste Chatwoot** con su practicidad,
> reusando modelos/componentes que ya existen (`case_tickets`, `case_tasks`,
> `case_portals`, Custom Views, Canned Responses, Chart.js, export).
>
> Norte: [[Referencia-osTicket]] · Practicidad previa (P1–P4): [[Plan-Practicidad-osTicket]].

---

## 1. Leyenda de esfuerzo

```
 S  = Small   ~0.5–1 día   UI/conexión, datos ya existen
 M  = Medium  ~2–4 días    lógica nueva + UI, backend acotado
 L  = Large   ~5–10 días   modelo/estructura nueva, migraciones, varias capas
 ── Dependencia: A→B significa "B conviene después de A"
```

Estimaciones de 1 desarrollador familiarizado con el código. Incluyen UI + back + prueba
manual, no QA formal ni i18n exhaustivo.

---

## 2. Inventario de brechas (de la comparativa)

```
 #  BRECHA                                  ESF  TIPO          ARCHIVO PRINCIPAL
 ─────────────────────────────────────────────────────────────────────────────────
 1  Header: barra de iconos + grid 2 col    S    UI            TicketDetail.vue
 2  Canned + status en caja de respuesta    S    Conexión      TicketDetail/ReplyBox
 3  Métricas: gráfico temporal + CSV        M    UI+datos      Metrics.vue
 4  Vacation Mode (perfil)                   S    Flag+filtro   profile + notif
 5  Menú "Más" (Owner/Merge/Link/Ban)        M    Acciones      TicketDetail.vue + API
 6  Print / PDF con niveles                  M    Back nuevo    nuevo servicio PDF
 7  Colas a medida del agente (Custom View)  M    Reuso patrón  Index.vue + Custom Views
 8  Organización como objeto                 L    Estructural   modelo nuevo + migración
 (9) Tareas como cola/objeto (opcional)      L    Estructural   case_tasks rework
```

---

## 3. Orden recomendado (por valor visible / esfuerzo)

```
   VALOR
   ALTO │  [1]Header      [3]Métricas     [7]Colas
        │  [2]Caja        [5]Menú Más
        │                 [6]Print
        │  [4]Vacation                    [8]Organización
   BAJO │                                 [(9)]Tareas-obj
        └─────────────────────────────────────────────
           BAJO          MEDIO            ALTO   ESFUERZO

   Quick wins (arriba-izq): 1, 2, 4  → primero
   Alto valor medio esfuerzo:        3, 5, 6, 7
   Estructural (decisión aparte):    8, (9)
```

### Fases propuestas

```
 FASE A — Quick wins de ficha (≈2–3 días)        [1] [2] [4]
   └─ Impacto visual inmediato, sin backend pesado. Arranque ideal.

 FASE B — Ficha completa estilo osTicket (≈4–7 días)   [5] [6]
   └─ Menú "Más" + Print/PDF. Cierra el pendiente P4. Depende de A (header).

 FASE C — Cola y métricas (≈4–6 días)            [3] [7]
   └─ Gráfico temporal + export CSV; colas a medida reusando Custom Views.

 FASE D — Estructural (decisión + ≈5–10 días c/u)  [8]  y opcional [(9)]
   └─ Organización como objeto. Requiere decisión de diseño antes de codificar.
```

Dependencias clave:

```
   [1] Header ──→ [5] Menú Más ──→ [6] Print
                                    (Print reusa "qué mostrar" del header/thread)
   Chatwoot Custom Views ──→ [7] Colas a medida
   Decisión Org (nueva vs CRMZeus) ──→ [8]
```

---

## 4. Detalle por brecha

### [1] Header del ticket — barra de iconos + grid 2 columnas · **S**
**Qué:** reordenar `TicketDetail.vue:1029` para que se sienta como el header de osTicket:
fila de iconos (↩ responder · 📄 nota · 👤 asignar · ↗ transferir · 🖨 imprimir · ✏️ editar ·
⚙️ más) + grid de datos 2 columnas (Status/Priority/Dept/Create | User(N)/Email/Org(N)/Source).
**Reuso:** todos los datos ya están en `ticket`. Es Vue/Tailwind.
**Riesgo:** bajo. **Salida:** maqueta + props existentes.

```
 ┌ Ticket #FOLIO ─────────────────── [↩][📄][👤▾][↗][🖨▾][✏️][⚙️▾] ┐
 │ Asunto                                                          │
 ├────────────────────────────┬───────────────────────────────────┤
 │ Status   Open              │ User: Nombre (N)                   │
 │ Priority High              │ Email / Organization: X (N)        │
 │ Assigned ...  SLA ... Due  │ Help Topic / Last Msg / Last Resp  │
 └────────────────────────────┴───────────────────────────────────┘
```

### [2] Canned response + status dentro de la caja · **S**
**Qué:** que la caja de respuesta del ticket tenga **selector de canned response** y
**dropdown de Ticket Status**, como osTicket (hoy se delega a "Ir a la conversación").
**Reuso:** Chatwoot ya tiene Canned Responses nativas (store + componente). Engancharlas.
**Riesgo:** bajo-medio (cuidar no acoplar al `currentChat`, ver [[Trampas]] / nota P4 reply box).

### [3] Métricas — gráfico temporal + export CSV · **M**
**Qué:** en `Metrics.vue`, añadir **gráfico de líneas** (created/closed/reopened/assigned/
overdue por día) + selector de timeframe, y **export CSV** de la tabla.
**Reuso:** Chatwoot usa Chart.js en reportes; `case_tickets` tiene timestamps/estado.
**Back:** endpoint de agregación por día/estado.

### [4] Vacation Mode · **S**
**Qué:** flag en el perfil del agente que **suspende notificaciones** por un período.
**Reuso:** Chatwoot tiene `availability_status` + sistema de notificaciones; añadir flag y
filtrar en el envío. **Decisión:** ¿perfil global Chatwoot o solo en contexto tickets?

### [5] Menú "Más" — Change Owner / Merge / Link / Ban Email / Delete · **M**
**Qué:** dropdown ⚙️ en el header con acciones avanzadas (según permisos del rol).
**Mapeo factible:**
- Change Owner = reasignar contacto del ticket.
- Merge / Link = relación entre `case_tickets` (ya existe tabla de relaciones).
- Ban Email = Chatwoot bloquea contacto; envolver desde el ticket.
- Delete = ya existe; añadir motivo → log.
**Gating:** mostrar cada acción según rol/grupo del agente.

### [6] Print / PDF con niveles · **M** (cierra P4 de [[Plan-Practicidad-osTicket]])
**Qué:** botón 🖨 con menú: Hilo / +Notas / +Eventos / +Adjuntos / +Tareas → PDF.
**Back:** servicio PDF (p.ej. `wicked_pdf`/`prawn`) que arma el contenido según el nivel.
**Reuso:** el "qué incluir" ya está en el thread/notas/adjuntos/tareas del ticket.
**Liga:** preferencia "tamaño papel PDF" del perfil (osTicket My Profile).

### [7] Colas a medida del agente · **M**
**Qué:** que el agente cree **colas privadas** con criterio propio + columnas configurables,
estilo dropdown `Open▾` (estándar + personales + "Add Personal Queue").
**Reuso:** Chatwoot **ya tiene Custom Views** (vistas guardadas) en Conversations → portar el
patrón a la cola de tickets (`Index.vue`) + persistir orden/columnas por usuario
(ya en Pendiente P3 menor).

### [8] Organización como objeto · **L** ⭐ estructural
**Qué:** modelo `Organization` con roster de contactos + **Account Manager** (auto-asigna
tickets) + **Primary Contacts** (auto-colaboran) + **Auto-Add por dominio de email** +
Ticket Sharing.
**Decisión previa (bloqueante):**
```
   OPCIÓN A: entidad nueva propia (organizations + memberships)
             → control total, más migración/UI.
   OPCIÓN B: extender lo de CRMZeus (idorganizacion_crmzeus)
             → menos trabajo, atado a integración externa.
```
**Recomendación:** decidir A vs B antes de estimar fino. Es el único gap que rearquitectura.

### [(9)] Tareas como cola/objeto · **L** opcional
**Qué:** volver `case_tasks` objetos independientes (cola propia, hilo, alertas), no solo
checklist. **Veredicto:** el checklist ya cubre ~80%; hacer esto solo si se busca paridad
fuerte. **Baja prioridad.**

---

## 5. Qué NO adaptar (decisión consciente)

```
 ✗ Portal web con LOGIN/registro del cliente (osTicket "Check Ticket Status" con cuenta)
   → MGCI usa folio + canal nativo (chat/WhatsApp/email). Para esos canales es MEJOR UX
     que mandar al cliente a una web con contraseña. Mantener enfoque MGCI.
   → Equivalente futuro al "Check Status": directiva bot @estado_ticket (pendiente P2).
```

---

## 6. Resumen ejecutivo

```
 ► 5 de 8 brechas son UI/conexión (Fases A–C): días, no semanas. Reusan lo que ya hay.
 ► Print y Menú "Más" (Fase B) cierran el pendiente P4 y el "remate" de la ficha.
 ► Solo Organización (Fase D) es estructural y necesita decisión de diseño primero.
 ► El portal con login NO se adapta: MGCI ya tiene mejor camino por canal.

 Esfuerzo total aprox (sin [8] ni [(9)]):  ≈ 10–16 días.
 Con Organización [8]:                     +5–10 días (tras decidir A/B).
```

Orden sugerido para arrancar: **[1] → [2] → [4]** (Fase A, ganancia visible rápida),
luego **[5] → [6]** (Fase B), luego **[3] → [7]** (Fase C). **[8]** cuando se decida modelo.

---

## 🔗 Relacionado
- [[Comparativa-Agent-Panel-osTicket]] · [[Plan-Practicidad-osTicket]] · [[Plan-User-Portal]]
- [[Pendiente]] · [[Referencia-osTicket]] · [[00-Indice]]
