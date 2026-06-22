---
titulo: Pendiente / no implementado
tipo: implementación
tags: [tickets, pendiente, todo]
---

## Pendiente / no implementado

### User Portal — pendientes tras la Fase P1 (ver [[Plan-User-Portal]])
- **i18n `en` del portal** — la copy de las vistas ERB está hoy en español; `<html lang>` ya sale de `portal.locale`. Falta extraer textos a locales es/en.
- **Tailwind por CDN** — las vistas del portal cargan Tailwind vía CDN (rápido para el MVP); migrar al build de assets para producción.
- ~~**Admin UI del portal**~~ ✅ **hecho** — vista "Portales del cliente" (`Portals.vue`, CRUD) + toggle público por tipo en `TicketTypes.vue`.
- ~~**Admin elige inbox destino (API/Email)**~~ ✅ **hecho** (R1) — selector "Canal destino" en el portal; acuse por ese canal.
- **R2 — destino WhatsApp + plantilla de acuse** — permitir inbox WhatsApp como destino con plantilla aprobada (folio como parámetro), ver [[Plan-User-Portal]] §10.
- **Directiva bot `@estado_ticket`** (P2) — consultar estado por el canal de origen (ej. WhatsApp) sin teclear folio.
- **Adjuntos: límites + throttle** — definir tipos/tamaño permitidos en el form público y rate-limit anti-spam.
- **Dominio propio** (P2/P3) — subdominio (`soporte.dominio.com`) y marca blanca (`custom_domain` ya existe en `case_portals`, reusa el patrón del Help Center).
- **Acuse por email** cuando la conversación nace en el inbox Portal (hoy el acuse vive en la conversación; sale por el canal si se reusó uno externo).

### Modo simple (osTicket) — tras las Fases S1+S2 (ver [[Plan-Modo-Simple]])
- ~~**S2 — colapsar badges de estado**~~ ✅ **hecho** — Index/TicketDetail con `displayStatus`
  + Kanban con columnas simples (5). (Panel de conversación no muestra texto de estado).
- ~~**S3 — métricas y reglas**~~ ✅ **hecho** — Metrics oculta KPIs ITIL (grupo "Calidad" con solo CSAT)
  y TicketRules filtra estados a simples + oculta la acción "Escalar". **Modo simple completo (S1+S2+S3).**

### General
- **Panel de contacto** (3er punto de entrada del diseño) — mostrar tickets históricos del contacto en su perfil. NO se hizo.
- **Reglas pre-cargadas por defecto** (las 7 del diseño) — el seed automático no se implementó; las reglas se crean manualmente desde la UI.
- **⚠️ Borrado de conversación/contacto deja tickets huérfanos (ANALIZAR)** — `case_tickets` NO tiene `dependent:` en `Conversation`/`Contact` ni foreign key en BD para `conversation_id`/`contact_id`. Hoy: al borrar una conversación, el ticket queda con `conversation_id` colgante (benigno, `optional: true` → resuelve a `nil`); al borrar un contacto, queda con `contact_id` colgante siendo **`not null`** → ticket inconsistente (`ticket.contact` = `nil`, vistas que hagan `ticket.contact.name` pueden romper). **Decidir política** (conservar histórico vs cascada) e implementar `dependent: :nullify`/`:restrict_with_error` + FK con `on_delete`. Considerar que Chatwoot borra contactos/conversaciones vía jobs.



## 🔗 Relacionado
- [[Historial-de-implementacion]] · [[00-Indice]]
