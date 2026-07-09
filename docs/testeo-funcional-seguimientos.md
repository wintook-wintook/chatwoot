# Testeo Funcional — Módulo de Seguimientos (Contact Tracking / Agentes IA)

**Proyecto:** Control de Seguimientos · **Fecha:** 2026-06-12 · **Rama:** `dashboard_contact_tracking`
**Entorno:** cuenta 2 · Rails dev · Sidekiq activo · OpenAI + Discourse + Google Calendar integrados.

---

## 1. Objetivo y alcance

Verificar de punta a punta el flujo de **seguimientos automáticos con Agente IA**:
creación vía automatización, clasificación de intención, respuesta desde base de
conocimiento (Discourse), agendado de citas en Google Calendar, y la regla de
**seguimientos en paralelo por canal**.

## 2. Entorno y setup

| Elemento | Valor |
|---|---|
| Canales (inbox) | #4 Telegram (kontrolyaBots_bot), #5 WhatsApp, #6 Web Test, #7 Telegram (kontrolyaBotsTest_bot) |
| Automatización | #1 "Agente IA Incio" (`conversation_created`, inbox 4 → `assign_tracking_template` #6) |
| Agente IA (plantilla) | #6 "CONSULTOR JUNIOR @discourse" (directiva `@discourse`) |
| Variables | `TRACKING_DETECT_INTENT=true`; API key OpenAI desde integración de la cuenta |

## 3. Resumen de resultados

| Caso | Descripción | Tiempo | Resultado |
|---|---|---|---|
| TC-01 | Conversación nueva → crea seguimiento → consulta KB (@discourse) | 17.5 s | ✅ PASS |
| TC-02 | Conversación existente → no crea seguimiento → propone agenda | 3.3 s | ✅ PASS |
| TC-03 | Selección de slot (outgoing no dispara IA; solo número, no fechas) | 1.1 s | ✅ PASS (con limitaciones) |
| TC-04 | Confirmar slot por número → crea evento en Google Calendar | 2.1 s | ✅ PASS |
| TC-10 | Multicanal: 1 seguimiento activo por (contacto, inbox) | — | ✅ PASS |

---

## 4. Casos ejecutados (detalle)

### TC-01 · Conversación nueva → crea seguimiento → consulta KB (@discourse)
- **Precondición:** contacto sin seguimiento activo; entra por inbox 4; automatización #1 activa.
- **Pasos:** crear conversación en inbox 4 y enviar *"Hola me podrías decir quién es el director de kontrolya"*.
- **Real:** conv #28, contacto #26. Se creó **Tracking #41** (status `pending`, programado +1 día, `max_attempts` 1). Router → `:kbase` (confianza 0.9). `KnowledgeBaseResponseService` modo `discourse_integration` → 50 resultados; usa post#236.
- **Respuesta (18:37:48):** *"…El director de Kontrolya CRM es Mario Alberto Duarte Vázquez… 📚 Más información: https://foro.kontrolya.com/t/…/232"*.
- **Tiempo:** 17.5 s (≈ 5 s de delay fijo + ~9 s del job: router + Discourse + generación).
- **Resultado:** ✅ PASS.

### TC-02 · Conversación existente → no crea seguimiento → propone agenda
- **Precondición:** conv #28 existe; el contacto ya tiene Tracking #41 activo.
- **Pasos:** enviar *"Y si quiero agendar una demostración?"*.
- **Real:** no se creó otro seguimiento. Router → `:book_appointment` (0.95) → `AvailabilitySlotService` leyó el Google Calendar de Admin → propuso slots. Respuesta en **3.3 s** (sin el delay de 5 s, porque ya había seguimiento activo).
- **Resultado:** ✅ PASS.

### TC-03 · Selección de slot
- **Sub-hallazgo A (outgoing no dispara IA):** un mensaje escrito como **agente** (outgoing) no activa la IA — es esperado (`message.rb`: `analyze_for_active_trackings, if: :incoming?`).
- **Sub-hallazgo B (solo número, no fechas):** el contacto respondió *"martes 16 a las 16:00"* (incoming) → la IA contestó *"No entendí tu elección 😊 respondé con el número (1 al 5)"* en **1.1 s**. `parse_slot_choice` solo acepta dígito 1-5 o palabra (uno…cinco); **no interpreta fechas**, ni aunque coincidan con un slot ofrecido.
- **Riesgo (falso positivo):** una frase con un dígito 1-5 suelto (ej. "a las 3") seleccionaría la opción 3.
- **Resultado:** ✅ comportamiento esperado, con limitaciones de UX.

### TC-04 · Confirmar slot → crea evento en Google Calendar
- **Pasos:** el contacto envía **"1"** (incoming).
- **Real:** respuesta en **2.1 s**: *"✅ ¡Perfecto! Tu cita está agendada para el lunes 15 de junio de 2026 a las 09:00 – 09:30 hs…"*. Log: `Evento creado en Google Calendar`.
- **Verificación en Google:** evento *"Cita con Andres Liverio — CONFIRMACION CUMPLIMINTO REQUERIMIENTO"* (id `3glebg80mk1…`) a las **2026-06-15 09:00 UTC**, confirmado con `list_events`.
- **Obs. timezone:** el inbox 4 tiene `timezone = UTC`; slots/horario/mensaje son consistentes en UTC. Si el negocio es México, configurar el inbox en `America/Mexico_City` (09:00 UTC = 03:00 MX).
- **Obs. invitado:** `attendees=[]` porque el contacto de WhatsApp/Telegram no tiene email.
- **Resultado:** ✅ PASS (agendado end-to-end).

### TC-10 · Multicanal — 1 seguimiento activo por (contacto, inbox)
- **Contexto:** se cambió el índice único de `(contact_id, status)` a `(contact_id, inbox_id, status)` para permitir seguimientos en paralelo por canal.
- **Verificación con datos reales (creación directa):** contacto #27 "Andres Liverio" → **Tracking #46** (inbox 4) y **Tracking #47** (inbox 7), ambos activos en paralelo.
- **Verificación de barreras (rollback):** segundo seguimiento en el **mismo** inbox = bloqueado por validación de modelo **y** por índice único de BD.
- **Nota:** en Telegram, la misma persona en dos bots distintos son **dos contactos** (#27 y #28); para conversaciones reales en ambos canales habría que fusionarlos.
- **Resultado:** ✅ PASS.

---

## 5. Comparativa de tiempos

| Caso | Conv | Crea seguimiento | Ruta | Busca en | Tiempo |
|---|---|---|---|---|---|
| TC-01 | nueva | ✅ | `:kbase` | Discourse (foro) | 17.5 s |
| TC-02 | existente | ❌ (ya existía) | `:book_appointment` | Google Calendar | 3.3 s |
| TC-03 | existente | ❌ | selección de slot | — (regex local) | 1.1 s |
| TC-04 | existente | ❌ | confirmar slot | Google Calendar (create_event) | 2.1 s |

El **+5 s** solo aplica al **primer** mensaje (cuando una automatización va a crear el seguimiento).

## 6. Hallazgos / correcciones

| # | Hallazgo | Estado |
|---|---|---|
| 1 | Directiva `@buscar_predefinidas` mal escrita en código (`@buscar_predeterminadas`) → la búsqueda canned nunca disparaba y la directiva se colaba al prompt | ✅ Corregido |
| 2 | UI mostraba "plantilla de seguimiento" en vez de "Agente IA" | ✅ Corregido |
| 3 | Multicanal: 1 activo por contacto (sin importar canal) | ✅ Implementado (índice por inbox) |
| 4 | Agendado: confirmación falsa si el calendario se desconfigura entre ofrecer y confirmar | ⏳ Pendiente |
| 5 | Selección de cita solo por número (no interpreta fechas) | ⏳ Pendiente |
| 6 | Mover / cancelar una cita ya agendada no soportado (falta `event_id` y `delete_event`) | ⏳ Pendiente |
| 7 | Timezone del inbox en UTC (config) | ⏳ Pendiente |
| 8 | Borrar conversación con seguimiento asociado falla por FK | ⏳ Pendiente |

## 7. Casos pendientes de testear

- **TC-05** — Mover una cita ya agendada (hoy no soportado).
- **TC-06** — Cancelar una cita ya agendada (hoy no soportado).
- **TC-07** — Calendario desconfigurado entre ofrecer y confirmar (¿cita falsa?).
- **TC-08** — Varios agentes con calendario: política de disponibilidad combinada.
- **TC-09** — Agente sin calendario configurado: mensaje esperado.

## 8. Conclusión

El núcleo del módulo funciona end-to-end: **creación de seguimiento por automatización,
clasificación de intención, respuesta desde Discourse, y agendado real en Google
Calendar**. La regla **multicanal (1 activo por contacto y canal)** quedó implementada y
verificada. Quedan pendientes de testeo/mejora el ciclo de vida de la cita
(mover/cancelar), la negociación de fecha en lenguaje natural y la configuración de
timezone por inbox.
