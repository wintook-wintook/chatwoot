---
titulo: Conciliación osTicket ⇄ MGCI (Gestor de Tickets Chatwoot)
tipo: análisis
tags: [tickets, osticket, gap-analysis, roadmap]
fecha: 2026-06-19
---

# Conciliación funcional: osTicket ⇄ MGCI

> **Objetivo:** comparar lo que MGCI (nuestro Gestor de Tickets ITIL sobre Chatwoot,
> rama `feat/tickets`) ya hace contra lo que **realmente aporta valor en osTicket**,
> detectar el "algo que falta para que sea atractivo al cliente" y medir la
> **factibilidad** de cada brecha dentro de nuestra arquitectura.

---

## 1. Resumen ejecutivo — el diagnóstico en una frase

> MGCI es **fuerte por dentro** (clasificación ITIL, SLA, reglas, IA, métricas)
> pero **mudo por fuera**: el *cliente final* no tiene ninguna superficie propia.
> En osTicket lo que "engancha" no es el ITIL — es que el **cliente abre, sigue y
> cierra su ticket solo**, por web y por correo, con número de folio y portal.

Hoy un ticket de MGCI **nace y muere dentro del dashboard del agente** (conversación,
ficha de contacto o interno). El cliente nunca "ve" un ticket como objeto: para él
sigue siendo un chat. Eso es exactamente la sensación de "le falta algo".

**Las 3 brechas que más mueven la aguja (todas factibles):**

1. **Portal / superficie del cliente** — que el contacto reciba su folio y pueda
   consultar estado (aunque sea por el mismo canal de chat, sin login).
2. **Ticket por correo (email‑to‑ticket)** — osTicket vive de esto; nosotros solo
   creamos desde chat/manual.
3. **Tareas (subtareas)** — trabajo en equipo dentro del ticket. (Colaboradores/CC
   salió de esta lista el 2026-07-28: descartado por ahora, ver §4.5.)

---

## 2. Tabla de conciliación (qué hace cada uno)

Leyenda estado MGCI: ✅ tenemos · 🟡 parcial · ❌ falta · ➕ tenemos y osTicket no.

| # | Capacidad funcional | osTicket | MGCI hoy | Estado |
|---|---------------------|----------|----------|--------|
| 1 | **Portal del cliente** (crear/seguir/cerrar ticket self‑service) | ✔ núcleo | — el cliente no tiene vista propia | ❌ |
| 2 | **Email → ticket** (piping / IMAP, autorespuesta con folio) | ✔ núcleo | solo chat/manual/interno | ❌ |
| 3 | **Web form público** (crea ticket sin cuenta) | ✔ | inbox web existe pero no crea *ticket* | 🟡 |
| 4 | **Folio / número de ticket** | ✔ | `FolioGenerator` con tokens y prefijo/tipo | ✅ |
| 5 | **Help Topics** (tópico que rutea + form + prioridad) | ✔ | `case_types` (tabla por cuenta) + reglas | 🟡 |
| 6 | **Departamentos** (ruteo, público/privado) | ✔ | usamos **Teams** de Chatwoot | 🟡 |
| 7 | **Ticket Filters** (reglas de ruteo en entrada) | ✔ | `case_rules` (condiciones/acciones, cascada) | ✅ |
| 8 | **SLA plans** (objetivos + escalado + horario hábil) | ✔ | SLA por prioridad + monitor 15 min + escalado | 🟡 |
| 9 | **Horario hábil / días festivos en SLA** | ✔ | SLA cuenta tiempo corrido (24/7) | ❌ |
| 10 | **Formularios y campos personalizados** | ✔ | 2K: campos por tipo (text/number/date/list/checkbox) | ✅ |
| 11 | **Listas configurables** (dropdowns reutilizables) | ✔ | campo `list` por tipo, no lista global reusable | 🟡 |
| 12 | **Estados configurables** | ✔ | 13 estados ITIL fijos (enum) | 🟡 |
| 13 | **Prioridades** (matriz) | ✔ simple | matriz **Impacto × Urgencia** ITIL | ➕ |
| 14 | **Respuestas predefinidas (canned)** | ✔ | Chatwoot tiene canned responses (no scoped a ticket) | 🟡 |
| 15 | **Knowledgebase / FAQ** | ✔ | tenemos KB + Discourse + pgvector (otra rama) | ✅ |
| 16 | **Autoresponders / Alertas / Avisos** | ✔ | notificación in‑app al asignado (bell) | 🟡 |
| 17 | **Asignar / transferir / reclamar / referir** | ✔ | asignar a agente y/o equipo (manual + reglas) | 🟡 |
| 18 | **Notas internas vs respuestas** | ✔ | eventos + notas internas en `case_events` | 🟡 |
| 19 | **Colaboradores / CC** (varios en el hilo) | ✔ | — | ❌ |
| 20 | **Tareas / subtareas dentro del ticket** | ✔ | — | ❌ |
| 21 | **Merge / Link de tickets** | ✔ | 2E relaciones + 2F problema/cambio + 3D duplicados | ✅➕ |
| 22 | **Organizaciones** (agrupar usuarios por empresa) | ✔ | Chatwoot: empresa por contacto, no por ticket | 🟡 |
| 23 | **Time tracking** (tiempo registrado por entrada) | ✔ | métricas de tiempos, no registro manual | 🟡 |
| 24 | **Colas guardadas / búsquedas guardadas** | ✔ | pestañas fijas (Mis/Sin asignar/Todos/SLA) + filtros | 🟡 |
| 25 | **Dashboard / Reportes / export CSV** | ✔ | `Metrics.vue` (12 KPI + gráficos), sin export | 🟡 |
| 26 | **Bloqueo de ticket** (evita choque de 2 agentes) | ✔ | — | ❌ |
| 27 | **Audit log** (quién hizo qué) | plugin | `case_events` = timeline auditable nativo | ✅ |
| 28 | **MFA / OAuth2 / plugins de almacenamiento** | ✔ | lo provee Chatwoot a nivel plataforma | ✅ |
| 29 | **Multi‑idioma** | ✔ | i18n es/en en todo el módulo | ✅ |
| 30 | **Clasificación / respuesta / resumen por IA** | ✘ | 3A–3F: clasifica, sugiere, resume, detecta repetidos, seguimiento | ➕➕ |
| 31 | **Recorrido por fases / Journey del ticket** | ✘ | 2L `JourneyView` (espina de 5 fases) | ➕ |
| 32 | **Kanban / tablero** | ✘ (vista lista) | `Kanban.vue` con drag por estado | ➕ |

**Conclusión de la tabla:** donde MGCI **gana** es analítica + IA + ITIL + Kanban
(filas ➕). Donde **pierde** es en la *cara al cliente y la colaboración operativa*
(filas ❌ 1,2,9,19,20,26 y los 🟡 de portal/email/colas).

---

## 3. Mapa visual de la brecha

```
        osTicket (lo que engancha)                 MGCI hoy
        ===========================                ========

   CLIENTE                                    CLIENTE
   ┌──────────────┐                           ┌──────────────┐
   │ Portal web   │ crea ticket               │   (nada)     │  ← solo "chatea"
   │ + correo     │ recibe folio              │   no ve el   │
   │ consulta est.│ sigue/cierra              │   ticket     │
   └──────┬───────┘                           └──────────────┘
          │ folio + email                            ✗ no hay puente al cliente
          ▼
   ┌──────────────────────────┐              ┌──────────────────────────┐
   │  MOTOR osTicket          │              │  MOTOR MGCI (potente)     │
   │  topics·dept·filters·SLA │   ~equivale  │  case_types·teams·rules   │
   │  forms·canned·KB         │  ──────────► │  ·SLA·forms·KB·métricas   │
   │                          │   y SUPERA   │  ·IA(3A-3F)·Kanban·Journey│
   └──────────────────────────┘              └──────────────────────────┘
                                                       ▲
   El motor está parejo (y MGCI gana en IA/ITIL).      │  la falla está
   La diferencia es TODO lo de arriba: la superficie ──┘  AQUÍ ARRIBA
   del cliente y el correo.
```

---

## 4. Brechas priorizadas + factibilidad

> Factibilidad = esfuerzo × encaje con la arquitectura Chatwoot/MGCI.
> Escala: 🟢 alta (días) · 🟡 media (1–2 semanas) · 🔴 alta complejidad.

### P0 — Lo que vuelve el módulo "atractivo para el cliente"

**4.1 Acuse + folio al cliente por su canal** 🟢
- *Qué:* al crear el ticket desde una conversación, enviar automáticamente al cliente
  un mensaje "Tu solicitud quedó registrada con folio **SOP‑00123**. Te avisaremos por
  aquí." y, al resolver/cerrar, otro de cierre.
- *Por qué:* es el 80 % de la sensación "esto es un sistema de tickets" con el 5 % del
  esfuerzo. Da formalidad percibida.
- *Factibilidad:* 🟢 ya hay `conversation_id` en el ticket y la IA de seguimiento (3F)
  ya redacta y (en on‑demand) puede enviar. Reusar `Cases::Ai::FollowUp` + un mensaje
  de plantilla en `ticket_created`/`resolved`. **Sin tablas nuevas.**

**4.2 Email‑to‑ticket** 🟡
- *Qué:* que un correo entrante cree/actualice un ticket (osTicket vive de esto).
- *Factibilidad:* 🟡 **Chatwoot ya tiene inbox de Email** (IMAP/SMTP + parsing de
  hilos). El trabajo no es el correo, es **enganchar** la creación de conversación de
  email al `Cases::OrchestratorService` (mismo hook que ya usamos en
  `contact_tracking_response_analyzer_job`) y mapear asunto→título, remitente→contacto.
  Reusa todo el motor. No reinventar piping/IMAP.

**4.3 Portal de consulta del cliente (estado por folio)** 🟡→🔴
- *Qué:* página pública donde el cliente mete email + folio y ve estado/timeline.
- *Factibilidad:* 🟡 si es **solo lectura por folio+email** (un controller público
  + vista mínima, reusa `ticket_json` filtrado). 🔴 si se quiere portal completo con
  login/historial (es básicamente reconstruir el User Portal de osTicket — evaluar si
  vale vs. usar el canal de chat como "portal").
- *Recomendación:* empezar por 4.1 (acuse por chat) que cubre la necesidad real sin
  construir portal; el portal público queda como fase 2 si el cliente lo pide.

### P1 — Colaboración operativa (lo que pide el agente, no el cliente)

**4.4 Tareas / subtareas en el ticket** 🟡
- *Qué:* checklist de pasos asignables dentro de un ticket (osTicket "Tasks").
- *Factibilidad:* 🟡 tabla `case_tasks` (title, status, assignee_id, due_at) + tarjeta
  en `TicketDetail` (pestaña Avance ya existe, encaja ahí). Patrón idéntico a lo ya
  hecho; migración al final.

**4.5 Colaboradores / CC** ❌ **DESCARTADO (2026-07-28)**
- *Qué:* sumar a otro contacto/agente al hilo del ticket.
- *Factibilidad:* 🟡 Chatwoot ya tiene "participantes" en conversación; para tickets
  internos/externos sería tabla pivote `case_ticket_collaborators`. Medio.
- *Estado:* **fuera del plan, no se desarrolla por ahora.** Hubo un backend a medias
  (`case_collaborators`) que se **eliminó del repo** y cuya tabla se revirtió en la BD.
  Si se retoma, se replantea desde cero. Ver [[Pendiente]].

**4.6 Bloqueo / "alguien está respondiendo"** 🟢
- *Factibilidad:* 🟢 campo `locked_by_id`/`locked_at` + aviso suave en el detalle.
  Barato; evita choques de dos agentes.

### P2 — Madurez / paridad fina

| Brecha | Factib. | Nota |
|--------|---------|------|
| Horario hábil en SLA (business hours) | 🟡 | hoy SLA es 24/7; meter calendario laboral por cuenta |
| Export CSV de listado y métricas | 🟢 | osTicket lo tiene; botón export sobre el index |
| Colas/búsquedas guardadas por usuario | 🟡 | hoy pestañas fijas; guardar filtros del usuario |
| Estados configurables por cuenta | 🔴 | hoy enum ITIL fijo; volverlos tabla es invasivo (toca transiciones) |
| Listas globales reutilizables | 🟡 | hoy `list` es por‑campo; extraer a catálogo de cuenta |
| Plantillas de email/alertas configurables | 🟡 | osTicket tiene editor; nosotros texto fijo + IA |
| Time tracking manual | 🟡 | registro de minutos por entrada del agente |

---

## 5. Lo que NO conviene copiar de osTicket

- **Estados 100 % libres:** nuestra fuerza es el flujo ITIL guiado (13 estados +
  Journey). Abrirlo del todo diluye el valor y complica métricas/SLA. Mantener.
- **Departamentos como entidad nueva:** ya tenemos **Teams** de Chatwoot. Mapear
  Help Topic→Team vía reglas en vez de crear "departments".
- **Portal con cuentas/login propias:** Chatwoot ya gestiona contactos; duplicar
  autenticación de cliente es coste alto. Preferir "portal por folio" o el chat.
- **Plugins de infra (S3/OAuth2/2FA):** ya los da la plataforma Chatwoot.

---

## 6. Recomendación / orden sugerido

```
Sprint 1 (atractivo inmediato, bajo costo)
  └─ 4.1 Acuse + folio al cliente por chat   🟢  ← mayor impacto percibido
  └─ 4.6 Bloqueo de ticket                   🟢
  └─ Export CSV (listado/métricas)           🟢

Sprint 2 (la puerta de entrada que falta)
  └─ 4.2 Email → ticket (hook al inbox email)🟡

Sprint 3 (colaboración)
  └─ 4.4 Tareas/subtareas                     🟡
  └─ 4.5 Colaboradores/CC                     ❌ descartado (2026-07-28)

Evaluar con cliente (mayor costo, valida demanda)
  └─ 4.3 Portal público por folio            🟡/🔴
  └─ Horario hábil en SLA                     🟡
```

**Si solo se hace UNA cosa:** la **4.1** (acuse con folio al cliente). Es la que
convierte "un chat con notas internas" en "tengo un ticket", que es justo la sensación
que hoy falta — y reusa lo ya construido (folio + IA de seguimiento), sin migraciones.

---

## 🔗 Relacionado
- [[00-Indice]] · [[Historial-de-implementacion]] · [[Pendiente]]
- Motor de reglas: [[Servicios-Directiva-Integracion]] · Modelo: [[Modelo-de-datos]]
- IA (seguimiento 3F reusable para 4.1): ver changelog 3F en [[Historial-de-implementacion]]
