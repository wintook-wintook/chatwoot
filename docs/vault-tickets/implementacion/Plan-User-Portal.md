---
titulo: Plan — User Portal (superficie del cliente, estilo osTicket)
tipo: plan
tags: [tickets, osticket, user-portal, plan, roadmap]
fecha: 2026-06-22
estado: P1 implementado y verificado en navegador
---

# 🌐 Plan — User Portal (la cara al cliente)

> ✅ **Fase P1 IMPLEMENTADA** (2026-06-22) — ver changelog en
> [[Historial-de-implementacion]]. Pendientes menores en [[Pendiente]].

> **Objetivo:** dar a MGCI la superficie que hoy le falta para parecerse a osTicket:
> que el **cliente final** abra, consulte y siga su ticket **sin login**, con folio.
> Equivale al **User Portal** de osTicket (Open a Ticket · Check Status · Knowledgebase).
> Norte del proyecto: [[Referencia-osTicket]] · Brechas: [[Conciliacion-osTicket-MGCI]]

---

## 0. Decisiones tomadas (cliente, 2026-06-22)

| Tema | Decisión |
|------|----------|
| Vínculo con mensajería | **Opción A** — el ticket vive en una conversación Chatwoot |
| Si NO hay conversación | crear una + **nota privada** (contexto al agente) + **respuesta pública** (folio+detalles al cliente) |
| Acceso | **Guest** (sin login) |
| Identificación | **email O WhatsApp/teléfono** (no solo correo) |
| Match de contacto existente | por **email o teléfono** |
| Canal de notificación/estado | **sigue el origen del ticket** (WhatsApp→WhatsApp, web→portal+email) |
| Help Topics en el form | **solo públicos** (flag nuevo `public` en `case_types`) |
| URL del portal | **por `slug`**: `/portal/:slug` (sin DNS); dominio propio para después |
| Form del MVP | básico **+ campos personalizados (2K) + adjuntos** (suben de P2 a P1) |

---

## 1. Las 3 acciones del portal (paridad osTicket)

```
┌──────────────────── USER PORTAL  (público, sin login) ────────────────────┐
│                                                                            │
│   ① Open a Ticket        ② Check Status          ③ Knowledgebase          │
│   ───────────────        ──────────────          ──────────────           │
│   nombre                 email o teléfono         (KB existente,           │
│   email o WhatsApp       + folio                   otra rama — enlazar)    │
│   tipo (help topic)      → vista read-only                                 │
│   asunto + mensaje         ticket + timeline                               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Flujo "Open a Ticket" (el corazón del plan)

```
Cliente envía el formulario del portal
   │  nombre · (email y/o WhatsApp) · tipo(help topic público) · asunto · mensaje
   │  + campos personalizados del tipo (2K) · + adjuntos
   ▼
[A] IDENTIFICAR CONTACTO  (find_or_create por email O teléfono)
   ├── existe Contact (match email o phone) → reusa (trae su historial)
   └── no existe → crea Contact  (Contacts::ContactBuilder de Chatwoot)
   ▼
[B] RESOLVER CONVERSACIÓN  (Opción A)
   ├── ¿tiene conversación ABIERTA?  (la más reciente del contacto)
   │      SÍ → adjunta el ticket a esa conversación (reusa el hilo)
   │           → la respuesta pública sale por SU canal (WhatsApp/email)
   │      NO → crea conversación nueva en inbox "Portal"
   ▼
[C] SEMBRAR EL HILO  (3 mensajes en la conversación)
   ├── (incoming)  mensaje del cliente = cuerpo del ticket (asunto+mensaje)
   ├── (private)   NOTA INTERNA solo-agente: folio, tipo, prioridad,
   │                descripción, SLA target, ruteo sugerido
   └── (outgoing)  RESPUESTA PÚBLICA al cliente:
                    "Tu solicitud quedó registrada con folio SOP-00123.
                     Tipo: … · Prioridad: … · Te avisaremos por aquí."
   ▼
[D] CREAR TICKET  Cases::OrchestratorService  (origin: web)
   ├── contact_id (de [A]) · conversation_id (de [B])
   ├── case_type_id (del help topic elegido) · priority (default/regla)
   ▼
[E] FOLIO  FolioGenerator → SOP-00123
   ▼
[F] AUTORESPUESTA  folio mostrado en pantalla del portal + (si hay email) por correo
   ▼
[G] REGLAS  Cases::RuleEngineService  → rutea a team/agente por tipo, prioriza, etc.
   ▼
[H] EVENTO  case_events: ticket_created (origin: system)
```

> Nota sobre [C]: en Chatwoot un `Message` tiene `private: true` (nota interna,
> solo el agente la ve) y `private: false` (pública, le llega al contacto por su
> canal). Eso es exactamente lo pedido: contexto para el agente + acuse para el cliente.

---

## 3. Flujo "Check Status" — el canal sigue el ORIGEN del ticket

> Decisión del cliente: **la consulta de estado se hace por donde nació el ticket.**

```
Ticket nacido en el PORTAL WEB
   └─ Check Status (web): email O teléfono + folio → vista read-only

Ticket nacido en WhatsApp / otro canal
   └─ el cliente pregunta por SU canal ("estado de mi ticket SOP-00123")
      → el bot responde por el mismo canal (futura directiva @estado_ticket)
   └─ el acuse del folio también salió por ese canal (Opción A reusa la conversación)
```

### 3.a Check Status web (read-only)
```
Cliente: email O teléfono  +  folio (SOP-00123)
   ▼
Valida que el folio pertenezca a un Contact con ese email/teléfono
   ├── coincide → muestra: estado, prioridad, tipo, fechas,
   │               timeline público (case_events filtrados) y SLA
   └── no coincide → "No encontramos un ticket con esos datos"
```

- **Solo lectura** (reusa `ticket_json` filtrado a campos públicos — sin notas
  internas ni datos sensibles del agente).
- Filtra `case_events` a los visibles al cliente (creado, en progreso,
  esperando respuesta, resuelto, cerrado) — ocultar internal_note, reglas, etc.

### 3.b Status por canal (WhatsApp, etc.) — fase posterior
- Nueva directiva del bot `@estado_ticket` (patrón igual a `@crear_ticket`,
  ver [[Servicios-Directiva-Integracion]]): detecta intención de consulta de
  estado, busca el ticket del contacto y responde por el mismo canal.
- Reusa el match por contacto (email/teléfono) — el cliente ya está identificado
  por el canal, no necesita teclear folio.

---

## 4. Piezas a construir (backend)

| Pieza | Ubicación propuesta | Función |
|-------|--------------------|---------|
| Inbox "Portal" | `Channel::Api` por cuenta | aloja conversaciones nacidas en el portal cuando el contacto no tiene una abierta |
| `PortalController` (público) | `app/controllers/public/portal/` | sirve la página y recibe el form (sin auth de agente) |
| `Public::Portal::TicketsController` | idem | `create` (open) · `show` (check status) |
| Identificación contacto | reusar `Contacts::ContactBuilder` | match por email o phone, crea si falta |
| Resolver conversación | extender `Cases::OrchestratorService` | `find_open_conversation` / crear en inbox Portal |
| Sembrado de mensajes | servicio nuevo `Cases::PortalThreadSeeder` | incoming + private note + public reply |
| Flag `public` en `case_types` | migración (al final) + admin UI | solo los públicos aparecen en el form |
| Acuse por canal de origen | reusar mensajería del canal | web→pantalla+email · WhatsApp→por el canal |
| Adjuntos | Active Storage (ya en Chatwoot) | validar tipo/tamaño en form público |
| Rate limit / anti-spam | throttle por IP/email | el form es público |

> ⚠️ Convenciones del módulo (ver [[Vision-y-convenciones]] y [[Trampas]]):
> tablas/columnas/código en **inglés**, UI en **español**; migraciones (si hicieran
> falta) SIEMPRE al final; todo cambio relevante → `case_events`; i18n es/en.

---

## 5. Piezas a construir (frontend del portal)

> El portal es **público** (no es el dashboard del agente). Definir si es una
> vista Rails server-rendered o una mini-SPA. Recomendado: vista pública ligera.

```
/portal/:slug                 (landing: 3 acciones)
/portal/:slug/new             (Open a Ticket — formulario)
/portal/:slug/status          (Check Status — email/tel + folio)
/portal/:slug/kb              (Knowledgebase — enlaza KB existente)
```
> `slug` único por cuenta (ej. `/portal/kontrolya`), igual que el Help Center
> nativo (`/hc/:slug`). Ver estrategia completa de URL/dominio en la sección 9.

- Tailwind + `dark:` (consistente con el módulo).
- i18n es/en.
- Marca de la cuenta (logo/color) — osTicket lo permite por instancia.

---

## 6. Decisiones cerradas (2026-06-22)

1. **Entrega / consulta de estado → sigue el ORIGEN del ticket.**
   - Web: acuse en pantalla + email; estado vía Check Status (email/tel + folio).
   - WhatsApp/otro canal: acuse y estado por el mismo canal (Opción A reusa la
     conversación; consulta por canal vía futura directiva `@estado_ticket`).
2. **Help Topics: solo públicos.** Nueva columna `public` en `case_types`; el form
   solo muestra los marcados públicos. (migración al final, admin lo configura).
3. **Campos personalizados (2K): SÍ en el form del MVP.** El form pide los campos
   del tipo elegido (como los forms por help topic de osTicket). *(subió de P2 a P1)*
4. **URL: por `slug`** (`/portal/:slug`, ej. `/portal/kontrolya`). Sin DNS.
   Subdominio/dominio propio queda para después (ver sección 9).
5. **Adjuntos: SÍ en el form del MVP** (vía Active Storage; validar tipo/tamaño).
   *(subió de P2 a P1)*

> Pendiente menor de definir en implementación: límites concretos de adjuntos
> (tipos/tamaño) y reglas de throttle del form público.

---

## 7. Fases sugeridas (ajustadas a las decisiones)

```
Fase P1 — MVP portal  (paridad osTicket, ya con form rico)
  └─ Flag `public` en case_types (migración al final + admin)
  └─ Open a Ticket: form (tipo público + asunto + mensaje + contacto
        + campos personalizados 2K + adjuntos)
        → find_or_create contacto (email/tel)
        → resolver conversación (reusar abierta / crear en inbox "Portal")
        → sembrado de hilo (incoming + nota privada + respuesta pública)
        → ticket (origin: web) → folio → acuse por canal de origen
        → reglas → evento
  └─ Check Status web (email/tel + folio → read-only, timeline público)

Fase P2 — Status por canal + plantillas
  └─ Directiva `@estado_ticket` (consulta de estado por WhatsApp/canal)
  └─ Plantillas de acuse/alertas configurables

Fase P3 — Pulido / marca
  └─ Branding por cuenta · dominio propio/subdominio · KB embebida · i18n fino
```

**MVP = Fase P1** — con eso el cliente abre su ticket (con tipo, campos y adjuntos),
recibe folio por su canal y consulta estado: la experiencia osTicket que hoy falta.

---

## 8. Boceto navegable
Prototipo HTML estático en `mockups/portal/` (no toca la app) — ver
[[mockups/portal/README|Boceto navegable — User Portal]]. Pantallas: landing,
abrir solicitud (con campos 2K + adjuntos), consultar estado (read-only) y acuse con folio.

---

## 9. URL y dominio del portal

> **Reusar el mecanismo nativo de Chatwoot.** El Help Center ya resuelve
> `slug` + `custom_domain` → cuenta. No inventar nada nuevo.
>
> - Modelo `Portal`: columnas `slug` (único) y `custom_domain` (único).
> - `public_controller.rb#ensure_custom_domain_request`: `Portal.find_by(custom_domain: request.host)`.
> - HC servido en `/hc/:slug` o por dominio propio (Host header).

### Decisión: **URL por slug** · dominio propio para después

```
NIVEL 1 — por slug (P1, sin DNS)            ← ELEGIDO PARA EL MVP
   https://aux.wintook.com/portal/:slug      (ej. /portal/kontrolya)

NIVEL 2 — subdominio propio (después)
   https://soporte.wintook.com → Host → cuenta   (1 registro DNS + SSL)

NIVEL 3 — dominio del cliente / marca blanca (después)
   https://ayuda.clientefinal.com → Host → cuenta  (igual que custom_domain del HC)
```

- **P1:** solo Nivel 1 (`/portal/:slug`). `slug` único por cuenta (validar unicidad
  como hace `Portal`). Cero trabajo de DNS.
- **Después (P3):** Niveles 2–3 reusando la resolución por `Host` ya existente
  (`custom_domain`). Solo se suma configuración DNS/SSL por cuenta — sin código nuevo
  de routing significativo.

### Implicación para el modelo
El portal necesita un `slug` por cuenta. Opciones: (a) reusar el `Portal`/`slug` del
Help Center si la cuenta ya tiene uno; (b) un slug propio del User Portal. **A decidir
en implementación** (preferible reusar para que HC y portal de tickets compartan marca/URL).

---

## 10. Canal destino del portal (refinamiento · 2026-06-22)

> **Idea:** un portal puede enrutar sus tickets a un **inbox destino configurable**
> (no solo al inbox API "Portal"), siempre que el canal permita una **conversación
> NUEVA iniciada por el negocio**. El form ya pide **Nombre + Móvil + Correo**, que
> da el identificador que cada canal necesita.

### Matriz de canales

| Canal destino | ¿Conversación NUEVA? | Requisito |
|---|---|---|
| **API** ("Portal", default) | ✅ siempre | — (acuse vive en dashboard / Check Status) |
| **Email** | ✅ | correo del cliente (acuse por email) |
| **WhatsApp** | ⚠️ solo con **plantilla aprobada** (regla 24h Meta) | móvil + plantilla |
| Web Widget | ⚠️ el cliente la ve solo si vuelve al widget | identidad del visitante |
| **Telegram / Messenger / Instagram** | ❌ no se puede iniciar | — |

### Regla de resolución (afina la §2)
```
¿el contacto tiene conversación ABIERTA? (cualquier canal)
   SÍ → reusar ese hilo  (Telegram/Messenger SÍ funcionan por reuso)
   NO → crear NUEVA en el inbox destino del portal (API / Email / WhatsApp)
```
> Telegram/Messenger/Instagram: válidos por **reuso** (el cliente ya escribió), pero
> **no** como destino de conversación nueva.

### Config del portal (nuevos campos)
- `inbox_id` (ya existe) → ahora **seleccionable** por el admin entre inboxes compatibles
  (API/Email/WhatsApp), con fallback al inbox API "Portal".
- Si el destino es **WhatsApp**: configurar **plantilla de acuse**:
  - `acuse_template_name` — nombre de la plantilla aprobada en Meta.
  - orden de parámetros → folio, tipo, prioridad… (ej. plantilla
    *"Tu solicitud quedó registrada con folio {{1}}. Tipo: {{2}}…"*).
  - Al abrir el ticket, el `PortalThreadSeeder` envía esa plantilla con el folio inyectado
    en vez del texto plano (que Meta rechazaría fuera de la ventana de 24h).

### Fases del refinamiento
```
R1 — destino API (actual) + Email     ← bajo esfuerzo; Email = match natural osTicket
R2 — destino WhatsApp + plantilla de acuse (config de plantilla en el portal)
```

---

## 🔗 Relacionado
- [[Referencia-osTicket]] · [[Conciliacion-osTicket-MGCI]]
- [[Servicios-Directiva-Integracion]] (Orchestrator/RuleEngine a reusar)
- [[Modelo-de-datos]] (conversation_id nullable, origin: web)
- [[Trampas]] · [[Vision-y-convenciones]] · [[Pendiente]]
