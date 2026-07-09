---
titulo: Servicios, directiva @crear_ticket e integración con el bot
tipo: diseño
tags: [tickets, servicios, jobs, hook, bot]
---

## Servicios a crear

| Servicio | Ubicación | Función |
|---------|-----------|---------|
| `Cases::OrchestratorService` | `app/services/cases/orchestrator_service.rb` | `find_or_create` ticket desde mensaje o acción manual |
| `Cases::RuleEngineService` | `app/services/cases/rule_engine_service.rb` | Evalúa reglas en cascada sobre un `CaseTicket` |
| `Cases::TicketCreatorService` | `app/services/cases/ticket_creator_service.rb` | Detecta directiva `@crear_ticket` y crea el ticket cuando la IA no pudo resolver |
| `CaseSlaMonitorJob` | `app/jobs/case_sla_monitor_job.rb` | Job periódico (cada 15min) — detecta SLA at_risk/overdue, cierre automático 72h |

---

## Directiva `@crear_ticket` (patrón igual a `@buscar_foro` / `@buscar_predefinidas`)

Se agrega en el `complementary_prompt` del `ContactTracking`, igual que las directivas de búsqueda existentes.

**Cuándo se dispara:** cuando `KnowledgeBaseResponseService` no pudo resolver la consulta (retorna `false`), el job verifica si existe `@crear_ticket` en el `complementary_prompt` y delega a `Cases::TicketCreatorService`.

**Qué hace:** crea un `CaseTicket` interno en Wintook, responde al cliente confirmando el ticket, evalúa las reglas de automatización y registra el evento. Solo opera dentro de Wintook — sin integración a servicios externos.

### El `complementary_prompt` cumple dos funciones a la vez

| Parte | Quién la lee | Para qué |
|-------|-------------|----------|
| Las directivas (`@buscar_foro`, `@crear_ticket`, etc.) | El **servicio** (código) | Decide qué acción ejecutar |
| El texto libre alrededor | La **IA** (GPT) | Entiende el contexto, el porqué y cómo responder al cliente |

El administrador configura ambas cosas en un solo campo, controlando el comportamiento completo del bot sin tocar código.

**Ejemplo de `complementary_prompt` completo:**
```
Eres un asistente de soporte técnico de Kontrolya.
Primero busca la solución en la base de conocimiento: @buscar_foro(soporte-tecnico).
Si no encuentras una respuesta específica al problema, no improvises.
Usa @crear_ticket para registrar el caso y avisa al cliente que un asesor lo atenderá.
```

- El **código** detecta `@buscar_foro(soporte-tecnico)` → llama `KnowledgeBaseResponseService`
- Si no resuelve → detecta `@crear_ticket` → llama `Cases::TicketCreatorService`
- La **IA** lee el texto completo para saber cómo comunicarse con el cliente en cada paso

### Orden de ejecución en el job

```
[1] KnowledgeBaseResponseService  (@buscar_predefinidas / @buscar_foro)
      → si resuelve: responde y termina
      → si NO resuelve: continúa

[2] Cases::TicketCreatorService   (@crear_ticket)
      → si directiva presente: crea ticket, confirma al cliente y termina
      → si NO hay directiva: continúa

[3] Respuesta conversacional genérica (fallback)
```

### Tabla completa de directivas del sistema

| Directiva en `complementary_prompt` | Quién la lee | Servicio | Qué hace |
|-------------------------------------|-------------|----------|----------|
| `@buscar_predefinidas` | Código | `KnowledgeBaseResponseService` | Busca en pgvector (respuestas predefinidas) |
| `@buscar_foro(nombre)` | Código | `KnowledgeBaseResponseService` | Busca en Discourse via API semántica |
| `@crear_ticket` | Código | `Cases::TicketCreatorService` | Crea `CaseTicket` en Wintook si KBase no resolvió |
| Texto libre | IA (GPT) | — | Contexto, tono, instrucciones de comportamiento |

---

## Integración con código existente (SIN romper nada)

### Hook en `ContactTrackingResponseAnalyzerJob`

Agregar al inicio de `process_message_for_tracking`, **envuelto en rescue**:

```ruby
# [Gestor de Tickets] hook — falla silenciosamente para no romper el bot
begin
  ticket = Cases::OrchestratorService.new(
    account:      message.account,
    contact:      message.conversation.contact,
    conversation: message.conversation
  ).find_active_ticket

  if ticket
    ticket.update_columns(first_response_at: Time.current) if ticket.first_response_at.nil?
    ticket.case_events.create!(
      account:    message.account,
      event_type: :message_received,
      origin:     :bot,
      payload:    { message_id: message.id }
    )
    Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
  end
rescue => e
  Rails.logger.error("[GestorTickets] hook error: #{e.message}")
end
# → todo el código existente continúa sin cambios
```

### Mapeo RouterService → CaseTicket

| Ruta del RouterService | event_type | Cambio de status |
|------------------------|------------|-----------------|
| `:rejected` | `status_changed` | → `cancelled` |
| `:interested` | `escalated` | → `escalated` |
| `:reschedule` | `tracking_triggered` | → `waiting_on_customer` |
| `:kbase` · `:tracking` · `:botseller` | `message_sent` | sin cambio |

---

## Cómo se crea un ticket — dos formas

### Forma 1: Automática (el bot lo crea)
Cuando llega un mensaje dentro de un `ContactTracking` activo, `Cases::OrchestratorService` verifica si hay un `CaseTicket` activo para ese contacto. Si no existe, lo crea con `case_type`, `priority` y `origin` inferidos. Las reglas se evalúan de inmediato.

### Forma 2: Manual (el agente lo crea desde el panel)
El agente presiona **[+ Crear ticket]** en el panel derecho de la conversación. Se abre un modal con los campos: Tipo, Título, Prioridad y Descripción. Al confirmar, `Cases::OrchestratorService` crea el ticket y `Cases::RuleEngineService` evalúa las reglas automáticamente.

---



## 🔗 Relacionado
- [[Modelo-de-datos]] · [[Flujos-y-notas]] · [[Archivos-reales]]
