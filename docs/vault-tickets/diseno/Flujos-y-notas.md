---
titulo: Flujos de referencia + notas importantes
tipo: diseño
tags: [tickets, flujos, notas]
---

## Flujos de referencia rápida

### Flujo A: Problema técnico por WhatsApp (automático)
```
Mensaje → ContactTrackingResponseAnalyzerJob
→ Hook Gestor de Tickets: ¿hay ticket activo? NO → crea CaseTicket (support, high)
→ RuleEngine: assign_team "Soporte", change_priority urgent si "no funciona"
→ RouterService: :tracking → KBase busca solución → responde al cliente
→ CaseEvent: message_received + message_sent registrados
→ SLA activo: 30min first_response_time_target (urgent)
```

### Flujo B: Cotización enviada → seguimiento automático
```
Agente envía cotización → CaseTicket commercial → status: waiting_on_customer
→ OrchestratorService crea ContactTracking (D+1, D+3, D+5)
→ Cliente responde "me interesa" → RouterService: :interested
→ CaseTicket: status → escalated → assign_team Comercial
→ CaseEvent: escalated + assigned + notificación al asesor
```

### Flujo C: SLA vencido → escalado automático
```
CaseSlaMonitorJob (cada 15min): detecta ticket urgent sin first_response_at > 30min
→ CaseEvent: sla_overdue registrado
→ RuleEngine: escalate + assign_team "Soporte Senior" + notify_agent supervisor
→ CaseTicket: status → escalated, sla_status → overdue, badge en rojo
```

### Flujo D: Agente crea ticket manual desde conversación
```
Agente abre conversación → ContactPanel → [+ Crear ticket]
→ Modal: case_type=support, title="Error al guardar cotización", priority=high
→ OrchestratorService.create → RuleEngineService evalúa reglas
→ Panel: badge "SUPPORT · IN_PROGRESS · High · SLA: 1h 55min"
→ Agente resuelve → [Cambiar estado → Resolved]
→ 72h después: cierre automático por CaseSlaMonitorJob
```

### Flujo E: KBase no resuelve → @crear_ticket crea el ticket
```
Mensaje → :kbase/:tracking → KnowledgeBaseResponseService → sin resultados
→ Cases::TicketCreatorService detecta @crear_ticket en complementary_prompt
→ Crea CaseTicket (support, origin: bot)
→ RuleEngine evalúa reglas → asignación automática
→ Responde al cliente: "Tu caso fue registrado, un asesor te contactará"
→ CaseEvent: ticket_created registrado
```

---

## Notas importantes

- Tablas, columnas y enums siempre en **inglés** — igual que Chatwoot.
- El `ContactTracking` NO es el ticket — es una **acción automatizada sobre el ticket**. No mezclar.
- `Conversation` es el contenedor de mensajes — `CaseTicket` es el contenedor del problema.
- `CaseRuleEngine` evalúa en cascada por `position`. Si `continue_on_match: false` (default), para en el primer match.
- Auto-cierre: 72h después de status `resolved` sin actividad → `closed`.
- El bot NO controla la lógica del ticket directamente — emite events que el motor procesa.
- Todo el código del Gestor de Tickets va en `rescue` en el hook del job — un fallo nunca rompe el flujo de atención existente.

---



## 🔗 Relacionado
- [[Servicios-Directiva-Integracion]] · [[00-Indice]]
