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

## Comparativa de tiempos

| Caso | Conv | Crea tracking | Ruta | Busca en | Tiempo |
|---|---|---|---|---|---|
| TC-01 | nueva | ✅ #41 | `:kbase` | Discourse (foro) | **17.5 s** |
| TC-02 | existente | ❌ (ya existía) | `:book_appointment` | Google Calendar | **3.3 s** |

El **+5 s** solo aplica al **primer** mensaje (cuando una automatización va a crear el
tracking). En mensajes posteriores no hay delay.

## Pendiente de testear (ampliar el estudio)
- [ ] Crear evento real al elegir un slot (`:book_appointment` → calendar event).
- [ ] Latencia del 1er mensaje (¿reducir o condicionar el +5 s?).
- [ ] Fallback cuando Discourse/OpenAI fallan (¿pierde la persona del prompt?).
- [ ] Rutas `:rejected` / `:interested` / `:reschedule` end-to-end.
- [ ] Verificar que el seguimiento programado (saliente) se dispara mañana (TC-01, sched +1 día).
