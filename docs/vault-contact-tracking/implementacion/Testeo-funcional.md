---
titulo: Testeo Funcional — Contact Tracking
tipo: implementacion
tags: [contact-tracking, testeo, testeo-funcional, casos, qa]
---

# Testeo Funcional — Contact Tracking

> 🧪 **Documento de estudio de testeo.** Aquí se registran **casos reales** observados
> en el sistema (cuenta 2), con precondición, pasos, esperado, real, tiempos y resultado.
> Es la fuente para el entregable **"Documentación de Testeo Funcional"** (un `.md`
> detallado que se genera a pedido a partir de estos casos).

Setup de referencia: cuenta **2**, inbox **4** (`kontrolyaBots_bot`), automatización
**#1 "Agente IA Incio"** (`conversation_created`, condición `inbox_id=4`, acción
`assign_tracking_template` → Agente IA **#6 "CONSULTOR JUNIOR @discourse"**). Ver
[[Automatizaciones]] y [[Servicios-y-jobs]].

---

## TC-01 · Conversación nueva → crea seguimiento → consulta a KB (@discourse)

| Campo | Valor |
|---|---|
| **Objetivo** | Verificar que al crear la conversación se crea el seguimiento y se responde una consulta vía base de conocimiento Discourse. |
| **Precondición** | Contacto sin tracking activo; entra por inbox 4; automatización #1 activa. |
| **Pasos** | 1) Crear conversación nueva en inbox 4. 2) Enviar: *"Hola me podrías decir quién es el director de kontrolya"*. |
| **Esperado** | (a) Se crea `ContactTracking` desde Agente IA #6. (b) Router clasifica `:kbase`. (c) `@discourse` → búsqueda en foro. (d) Responde con dato + footer de fuente. |
| **Real (2026-06-12)** | Conv **#28**, contacto **#26**. **Tracking #41** creado 18:37:31 (status `pending`, sched +1 día, max_attempts 1). Router → `:kbase` (conf. 0.9). `KnowledgeBaseResponseService` modo `discourse_integration` → **50 resultados**, usa post#236. Respuesta msg **#992** a las 18:37:48. |
| **Respuesta** | *"…El director de Kontrolya CRM es Mario Alberto Duarte Vázquez… 📚 Más información: https://foro.kontrolya.com/t/…/232"* |
| **Tiempo** | **17.5 s** IN→OUT  (≈ **5 s** delay fijo + **~9.05 s** del `ResponseAnalyzerJob`: router OpenAI + búsqueda Discourse + generación OpenAI). |
| **Resultado** | ✅ **PASS** |
| **Notas** | El +5 s viene de `will_trigger_tracking_automation? == true` (`message.rb:470`), para evitar el race condition tracking/BotSeller. |

---

## TC-02 · Conversación ya creada → NO crea seguimiento → agenda cita (calendario)

| Campo | Valor |
|---|---|
| **Objetivo** | Verificar que en una conversación existente (con tracking ya creado) NO se crea otro seguimiento, no hay delay y responde una sola vez. |
| **Precondición** | Conv #28 ya existe; contacto #26 ya tiene Tracking #41 (`pending` = activo). |
| **Pasos** | Enviar en conv #28: *"Y si quiero agendar una demostración?"* |
| **Esperado** | (a) **No** se crea tracking nuevo. (b) **Sin** +5 s de delay (`wait=0`). (c) **Una sola** respuesta. (d) Router según intención. |
| **Real (2026-06-12)** | Sigue existiendo **solo el Tracking #41** (no se creó otro). Router → `:book_appointment` (conf. 0.9). `AvailabilitySlotService` leyó el Google Calendar de Admin → propuso slots. Msg IN **#993** 18:50:08 → OUT **#994** 18:50:11. |
| **Respuesta** | *"¡Con gusto! 📅 Tenemos los siguientes horarios disponibles: 1️⃣ lunes 15 jun · 09:00–09:30 … "* |
| **Tiempo** | **3.3 s** IN→OUT (sin el delay de 5 s; ~5× más rápido que TC-01). |
| **Resultado** | ✅ **PASS** |
| **Notas** | Confirma que la ruta `:book_appointment` **propone** slots reales. Falta probar la **creación del evento** al elegir un número (ver [[Pendiente]]). |

---

## TC-03 · Selección de slot de cita (conv #29)

| Campo | Valor |
|---|---|
| **Objetivo** | Verificar cómo se responde a la elección de horario tras proponer slots (`:book_appointment`). |
| **Precondición** | Conv #29, contacto #27 con Tracking #42; ya se ofrecieron slots (estado `[PENDING_SLOT]` en `ai_context`). |
| **Setup previo** | #995 IN "Y si quiero agendar una demostración?" → #996 OUT (9.8 s) propuso slots de *lunes 15* (calendario de Admin). |
| **Sub-hallazgo A — outgoing no dispara IA** | El mensaje #997 "martes 16 a las 16:00" se mandó como **agente (outgoing, User#5)** → la IA **no** respondió. Es esperado: `message.rb:138` `analyze_for_active_trackings, if: :incoming?`. |
| **Sub-hallazgo B — selección solo por número** | #998 **IN** (Contact#27) "martes 16 a las 16:00" → respondió #999 (+**1.1 s**): *"No entendí tu elección 😊 … respondé con el número (1 al 5)."* `parse_slot_choice` (`:468`) **solo** acepta dígito 1-5 aislado (`/\b([1-5])\b/`) o palabra (uno…cinco). **No interpreta fechas**, ni siquiera si coinciden con una opción ofrecida. |
| **Riesgo (falso positivo)** | Una frase con un dígito 1-5 suelto (ej. "a las 3") seleccionaría la **opción 3** aunque sea una hora, no la opción. ("16:00"/"15" no matchean por no ser 1-5 aislado.) |
| **Sub-hallazgo C — creación de evento SÍ existe** | Al elegir un número válido → `confirm_and_create_appointment` (`:495`) llama `GoogleCalendarService#create_event` y **crea el evento real** en Google Calendar con el contacto como invitado. Falta probar en vivo (TC-04). |
| **Tiempo** | **1.1 s** (rama local, sin OpenAI; sin delay). |
| **Resultado** | ✅ comportamiento esperado, ⚠️ con limitaciones de UX (solo número, no fechas). |

---

## TC-04 · Confirmar slot por número → crea evento en Google Calendar (conv #29)

| Campo | Valor |
|---|---|
| **Objetivo** | Verificar que al elegir un número de slot válido se crea el evento real en Google Calendar. |
| **Precondición** | Conv #29 con `[PENDING_SLOT]` activo (slots de *lunes 15* ya ofrecidos en TC-03). |
| **Pasos** | Contacto #27 envía **"1"** (incoming). |
| **Real (2026-06-12)** | #1000 IN "1" 19:40:38 → #1001 OUT (+**2.1 s**): *"✅ ¡Perfecto! Tu cita está agendada para el lunes 15 de junio de 2026 a las 09:00 – 09:30 hs…"*. Log: `Slot elegido: opción 1 — 2026-06-15T09:00:00Z` → `Evento creado en Google Calendar`. |
| **Verificación en Google** | ✅ Evento *"Cita con Andres Liverio — CONFIRMACION CUMPLIMINTO REQUERIMIENTO"* (id `3glebg80mk1…`) a las **2026-06-15 09:00 UTC**. Confirmado con `GoogleCalendarService#list_events`. |
| **Estado del tracking** | #42 pasó a `paused` (cierre del flujo de agenda). |
| **Tiempo** | **2.1 s**. |
| **Resultado** | ✅ **PASS** — el agendado funciona end-to-end (slot → evento real). |
| **Obs. 1 (timezone)** | El evento quedó 09:00 **UTC** = 03:00 hora México. NO es bug de cálculo: el **inbox 4 tiene timezone `UTC`** (y `Time.zone` app = UTC); slots, horario 9-18 y mensaje al cliente son todos UTC, consistentes. Si el negocio es México, falta configurar el inbox en `America/Mexico_City`. |
| **Obs. 2 (attendees)** | `attendees=[]` porque el contacto de WhatsApp **no tiene email** → no se le envía invitación. El evento se crea igual. |

## Comparativa de tiempos

| Caso | Conv | Crea tracking | Ruta | Busca en | Tiempo |
|---|---|---|---|---|---|
| TC-01 | nueva | ✅ #41 | `:kbase` | Discourse (foro) | **17.5 s** |
| TC-02 | existente | ❌ (ya existía) | `:book_appointment` | Google Calendar | **3.3 s** |
| TC-03 | existente | ❌ | selección de slot (local) | — (regex, sin OpenAI) | **1.1 s** |
| TC-04 | existente | ❌ | confirmar slot → crea evento | Google Calendar (create_event) | **2.1 s** |

El **+5 s** solo aplica al **primer** mensaje (cuando una automatización va a crear el
tracking). En mensajes posteriores no hay delay.

## Pendiente de testear (ampliar el estudio)
- [x] Crear evento real al elegir un slot (`:book_appointment` → calendar event). ✅ TC-04 PASS
- [ ] Latencia del 1er mensaje (¿reducir o condicionar el +5 s?).
- [ ] Fallback cuando Discourse/OpenAI fallan (¿pierde la persona del prompt?).
- [ ] Rutas `:rejected` / `:interested` / `:reschedule` end-to-end.
- [ ] Verificar que el seguimiento programado (saliente) se dispara mañana (TC-01, sched +1 día).

### 📅 Casos de testeo de agendado (cubrir en la doc de Testeo Funcional)
> Derivados de los pendientes de [[Pendiente]] sección "Agendado de citas". Incluir como
> casos cuando se genere el entregable de Testeo Funcional.
- [x] **TC-04** — Elegir número válido → verificar evento creado en Google Calendar. ✅ **PASS** (ver arriba).
- [ ] **TC-05** — Mover una cita ya agendada (¿qué responde? hoy no soportado).
- [ ] **TC-06** — Cancelar una cita ya agendada (hoy no soportado).
- [ ] **TC-07** — Calendario desconfigurado entre ofrecer y confirmar (¿confirma cita falsa? = bug).
- [ ] **TC-08** — Varios agentes con calendario: ¿qué disponibilidad propone (balance)?
- [ ] **⭐ TC-09 — Agente sin calendario configurado / desconfigurado** — qué debe responder
      el seguimiento (hoy: `:interested` o `:book_appointment_no_slots` + escala a humano,
      sin mensaje específico). *(Pendiente marcado por el usuario para el Testeo Funcional.)*
