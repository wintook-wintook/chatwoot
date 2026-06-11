---
titulo: Archivos a crear + plan de fases original
tipo: diseño
tags: [tickets, archivos, fases]
---

## Archivos a crear

### Backend (nuevos)

| Archivo | Función |
|---------|---------|
| `db/migrate/..._create_case_tickets.rb` | Tabla `case_tickets` |
| `db/migrate/..._create_case_events.rb` | Tabla `case_events` |
| `db/migrate/..._create_case_rules.rb` | Tabla `case_rules` |
| `app/models/case_ticket.rb` | Modelo con enums, validaciones, transiciones, SLA |
| `app/models/case_event.rb` | Modelo de evento |
| `app/models/case_rule.rb` | Modelo de regla |
| `app/services/cases/orchestrator_service.rb` | find_or_create |
| `app/services/cases/rule_engine_service.rb` | Motor de reglas |
| `app/services/cases/ticket_creator_service.rb` | Detecta @crear_ticket y crea el ticket |
| `app/jobs/case_sla_monitor_job.rb` | Monitor de SLA (cron cada 15min) |
| `app/controllers/api/v1/accounts/case_tickets_controller.rb` | CRUD + transition + assign |
| `app/controllers/api/v1/accounts/case_events_controller.rb` | Index (timeline) |
| `app/controllers/api/v1/accounts/case_rules_controller.rb` | CRUD |

### Backend (modificados)

| Archivo | Qué agregar |
|---------|-------------|
| `app/jobs/contact_tracking_response_analyzer_job.rb` | Hook `Cases::OrchestratorService` al inicio de `process_message_for_tracking` (con rescue) |
| `config/routes.rb` | Rutas de `case_tickets`, `case_events`, `case_rules` |
| `config/sidekiq.yml` | Cron `CaseSlaMonitorJob` cada 15 minutos |

### Frontend (Fase 3 — panel derecho)

| Archivo | Función |
|---------|---------|
| `conversation/CaseTicketPanel.vue` | Sección del ContactPanel — badge + botones |
| `conversation/CaseTicketModal.vue` | Modal de creación de ticket |
| `conversation/CaseTimeline.vue` | Timeline de events del ticket |

### Frontend (Fase 4 — vista dedicada)

| Archivo | Función |
|---------|---------|
| `gestorTickets/gestorTickets.routes.js` | Ruta `/tickets/list` |
| `gestorTickets/Index.vue` | Vista principal — lista con filtros y badges SLA |
| `gestorTickets/TicketDetail.vue` | Detalle + timeline |
| `gestorTickets/TicketRules.vue` | Gestión de reglas |
| `gestorTickets/api.js` | Llamadas al backend |
| `i18n/locale/es/gestorTickets.js` | Traducciones ES |
| `i18n/locale/en/gestorTickets.js` | Traducciones EN |

---

## Convención de identificación

- **Archivos nuevos:** encabezado `// ====... @tickets_cases`
- **Líneas en archivos existentes:** comentario inline `// @tickets_cases`

---

## Fases de implementación

| Fase | Contenido | Días estimados |
|------|-----------|---------------|
| **0** | Migraciones + modelos | 1-2 |
| **1** | Servicios + jobs + integración bot | 2-3 |
| **2** | API REST (controladores + rutas) | 2 |
| **3** | Panel derecho conversación (ContactPanel) | 2-3 |
| **4** | Vista "Gestor de Tickets" en sidebar | 3-4 |
| **5** | Métricas y reportes | 2-3 |

**Orden de dependencias:**
```
FASE 0 → FASE 1 → FASE 3
FASE 0 → FASE 2 → FASE 4
FASE 3 + FASE 4 → FASE 5
```

---



## 🔗 Relacionado
- Lo realmente construido: [[Archivos-reales]]
- [[Historial-de-implementacion]]
