---
titulo: Archivos reales del módulo (backend + frontend)
tipo: implementación
tags: [tickets, archivos, backend, frontend]
---

## Archivos backend (TODOS creados y verificados)

| Archivo | Notas de implementación |
|---------|------------------------|
| `db/migrate/20260604000001_create_case_tickets.rb` | ✅ migrada |
| `db/migrate/20260604000002_create_case_events.rb` | ✅ migrada — sin `updated_at` (inmutable) |
| `db/migrate/20260604000003_create_case_rules.rb` | ✅ migrada |
| `app/models/case_ticket.rb` | ✅ |
| `app/models/case_event.rb` | ✅ |
| `app/models/case_rule.rb` | ✅ |
| `app/services/cases/orchestrator_service.rb` | métodos: `find_active_ticket`, `find_or_create_from_message`, `create_for_manual` |
| `app/services/cases/rule_engine_service.rb` | 7 operadores, 9 acciones, `reload` antes de cada acción |
| `app/services/cases/ticket_creator_service.rb` | detecta `@crear_ticket` |
| `app/jobs/case_sla_monitor_job.rb` | cron cada 15min en `config/schedule.yml` |
| `app/controllers/api/v1/accounts/case_tickets_controller.rb` | index, show, create, transition, assign, **metrics** |
| `app/controllers/api/v1/accounts/case_events_controller.rb` | index (timeline) |
| `app/controllers/api/v1/accounts/case_rules_controller.rb` | CRUD |

**Backend modificado:**
- `app/jobs/contact_tracking_response_analyzer_job.rb` — hook en `process_message_for_tracking` + `TicketCreatorService` en `try_kbase_then_conversational`
- `config/routes.rb` — rutas dentro de `resources :case_tickets` (incluye `collection { get :metrics }`)
- `config/schedule.yml` — cron `case_sla_monitor_job` (NO `sidekiq.yml` — el proyecto usa `schedule.yml` con sidekiq-cron)
- `app/models/account.rb` — `has_many :case_tickets` y `has_many :case_rules`

## Archivos frontend (TODOS creados y verificados en browser)

| Archivo real | Función |
|--------------|---------|
| `app/javascript/dashboard/api/caseTickets.js` | API client (incluye `getMetrics`) |
| `app/javascript/dashboard/api/caseRules.js` | API client de reglas |
| `app/javascript/dashboard/store/modules/caseTickets.js` | store único (Fases 3+4+5) |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTicketPanel.vue` | sección panel derecho |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTicketModal.vue` | modal crear ticket |
| `app/javascript/dashboard/components/contacts/CaseTicket/CaseTimeline.vue` | timeline (modal) |
| `app/javascript/dashboard/routes/dashboard/gestorTickets/routes.js` | 4 rutas |
| `app/javascript/dashboard/views/gestorTickets/Index.vue` | lista con filtros + paginación |
| `app/javascript/dashboard/views/gestorTickets/TicketDetail.vue` | detalle + timeline inline |
| `app/javascript/dashboard/views/gestorTickets/TicketRules.vue` | CRUD reglas con **builder visual** |
| `app/javascript/dashboard/views/gestorTickets/Metrics.vue` | dashboard de métricas (Fase 5) |
| `app/javascript/dashboard/components/layout/config/sidebarItems/gestorTickets.js` | menú secundario |
| `app/javascript/dashboard/i18n/locale/{es,en}/gestorTickets.json` | traducciones |

**Frontend modificado:**
- `components/layout/config/default-sidebar.js` ⚠️ (NO el `.jsx` — ver decisión técnica abajo)
- `components/layout/config/sidebarItems/primaryMenu.js` — icono `clipboard`, label `TICKETS`
- `components/layout/Sidebar.vue` — `gestorTickets_*` en `alwaysShowRoutes` de `shouldShowSecondarySidebar`
- `routes/dashboard/dashboard.routes.js` — import + spread `gestorTicketsRoutes`
- `store/index.js` + `store/mutation-types.js` — registro módulo `caseTickets` + 7 mutation types
- `i18n/locale/{es,en}/index.js` — import `gestorTickets.json`
- `i18n/locale/{es,en}/settings.json` — claves `SIDEBAR.TICKETS/ALL_TICKETS/TICKET_METRICS/TICKET_RULES`

**Vistas guardadas** (`feat/tickets_filtros`, detalle en [[Vistas-guardadas]]) — reusa el
modelo nativo `CustomFilter`, no crea tabla propia:
- `db/migrate/20260904180000_add_shared_to_custom_filters.rb` — columna `shared`
- `app/models/custom_filter.rb` · `app/policies/custom_filter_policy.rb`
- `app/controllers/api/v1/accounts/custom_filters_controller.rb`
- `app/views/api/v1/models/_custom_filter.json.jbuilder`
- `views/gestorTickets/SavedViewsModal.vue` (nuevo) · `views/gestorTickets/Index.vue`
- `routes/dashboard/customviews/AddCustomViews.vue` ⚠️ nativo compartido con Conversaciones y Contactos



## 🔗 Relacionado
- [[Rutas-Metricas-Builder]] · [[Archivos-y-fases]] · [[Vistas-guardadas]]
