# Bug: inbox deja de recibir — cola Redis round-robin desincronizada

**Detectado:** ~2026-06 · **Resuelto (fix permanente en develop):** 2026-06-19, commit `dc4fec9aa`

## Síntoma

El inbox "deja de funcionar" o "no recibe" mensajes. El workaround manual era: eliminar todos los
colaboradores → Guardar → volver a agregarlos → Guardar. Después de eso el inbox volvía a funcionar.

## Cómo funciona el sistema de auto-asignación

Chatwoot mantiene una lista en Redis por inbox para el round-robin de asignación automática:
`ROUND_ROBIN_AGENTS:<inbox_id>` (`lib/redis/redis_keys.rb`).

`InboxMember` (`app/models/inbox_member.rb`) tenía callbacks incrementales:
```ruby
after_create  :add_agent_to_round_robin   # lpush user_id a Redis
after_destroy :remove_agent_from_round_robin  # lrem user_id de Redis
```

`AutoAssignment::InboxRoundRobinService#available_agent` llama `reset_queue unless validate_queue?`,
donde `validate_queue?` compara miembros en DB vs. lista en Redis.

## Por qué "dejaba de recibir"

La cola Redis se desincroniza cuando Redis se reinicia/flushea, un agente fue eliminado pero su ID
quedó en la lista, o hubo un crash durante un callback de alta/baja. Con la cola desincronizada:
`validate_queue?` detecta el problema y llama `reset_queue`, pero si `allowed_online_agent_ids` está
vacío (todos en `busy` o sin presencia activa) `available_agent` retorna `nil` y la conversación
queda sin asignar — nadie recibe notificación, el inbox parece "muerto".

El mecanismo de auto-corrección solo se dispara si `enable_auto_assignment = true` Y llega una
conversación nueva a `open` — sin tráfico entrante no hay trigger del reset.

## Por qué el workaround (quitar/agregar colaboradores) funcionaba

Cada `after_destroy`/`after_create` de `InboxMember` disparaba `lrem`/`lpush` en Redis — en efecto,
un `reset_queue` manual forzado desde la UI, sin depender de que llegara una conversación.

## Fix rápido por consola (ya no debería ser necesario)

```ruby
inbox = Inbox.find(<inbox_id>)
AutoAssignment::InboxRoundRobinService.new(inbox: inbox).reset_queue
```

## Fix permanente — IMPLEMENTADO (develop, commit `dc4fec9aa`)

`app/models/inbox_member.rb` ahora hace un rebuild completo de la cola en vez de add/remove
incremental:
```ruby
after_create  :sync_round_robin_queue
after_destroy :sync_round_robin_queue

def sync_round_robin_queue
  return unless inbox.present?
  ::AutoAssignment::InboxRoundRobinService.new(inbox: inbox).reset_queue
end
```

`reset_queue` limpia la key de Redis y reconstruye desde `inbox.inbox_members` en DB, tanto en
alta como en baja — la cola siempre queda igual que la DB. Trade-off: el orden del round-robin se
reinicia con cada cambio de colaboradores (aceptable en la práctica). Specs en
`spec/models/inbox_member_spec.rb` y `spec/services/auto_assignment/inbox_round_robin_service_spec.rb`.

**Estado:** el workaround manual y el fix rápido por consola ya no deberían ser necesarios salvo que
el problema reaparezca por otra causa.

## Archivos clave
| Archivo | Rol |
|---|---|
| `app/models/inbox_member.rb` | Callbacks que mantienen la cola Redis |
| `app/services/auto_assignment/inbox_round_robin_service.rb` | validate/reset/available_agent |
| `app/services/auto_assignment/agent_assignment_service.rb` | Filtra por agentes online |
| `app/models/concerns/auto_assignment_handler.rb` | Trigger de auto-asignación en Conversation |
| `lib/redis/redis_keys.rb` | Clave Redis `ROUND_ROBIN_AGENTS:<inbox_id>` |
