---
titulo: Pendiente / no implementado
tipo: implementación
tags: [tickets, pendiente, todo]
---

## Pendiente / no implementado

- **Panel de contacto** (3er punto de entrada del diseño) — mostrar tickets históricos del contacto en su perfil. NO se hizo.
- **Reglas pre-cargadas por defecto** (las 7 del diseño) — el seed automático no se implementó; las reglas se crean manualmente desde la UI.
- **⚠️ Borrado de conversación/contacto deja tickets huérfanos (ANALIZAR)** — `case_tickets` NO tiene `dependent:` en `Conversation`/`Contact` ni foreign key en BD para `conversation_id`/`contact_id`. Hoy: al borrar una conversación, el ticket queda con `conversation_id` colgante (benigno, `optional: true` → resuelve a `nil`); al borrar un contacto, queda con `contact_id` colgante siendo **`not null`** → ticket inconsistente (`ticket.contact` = `nil`, vistas que hagan `ticket.contact.name` pueden romper). **Decidir política** (conservar histórico vs cascada) e implementar `dependent: :nullify`/`:restrict_with_error` + FK con `on_delete`. Considerar que Chatwoot borra contactos/conversaciones vía jobs.



## 🔗 Relacionado
- [[Historial-de-implementacion]] · [[00-Indice]]
