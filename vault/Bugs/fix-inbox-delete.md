# Fix: no se podían borrar canales (inboxes)

**Fecha:** 2026-05-18
**Instancia afectada:** `/home/chatwoot/chatwoot` (puerto 3000)
**Síntoma:** al borrar un canal desde la UI aparecía "Could not delete inbox. Please try again
later." El canal quedaba en la lista sin borrarse, incluso recargando.

## Investigación

El controlador `Api::V1::Accounts::InboxesController#destroy` encola `DeleteObjectJob` y devuelve
200 OK inmediatamente — el error real no estaba ahí. El log de nginx confirmó 200 OK en todas las
peticiones `DELETE`. El borrado real ocurre en Sidekiq, de forma asíncrona.

`Sidekiq::DeadSet.new.select { |j| j.display_class == 'DeleteObjectJob' }` mostró 26 jobs muertos.
Reproduciendo con `Inbox.find(id).destroy!` en `rails runner` aparecieron dos errores en cadena:

```
PG::ForeignKeyViolation: ERROR: insert or update on table "contact_trackings" violates foreign key constraint
PG::UndefinedTable: ERROR: relation "inbox_response_sources" does not exist
```

## Causa raíz 1 — FK constraints sin asociaciones declaradas

Tablas custom con FK a `inboxes` (`contact_trackings`, `command_sessions` con `inbox_id NOT NULL`;
`tracking_templates` con `inbox_id` nullable) nunca fueron declaradas como asociaciones en el
modelo `Inbox`. Al hacer `DELETE FROM inboxes`, Postgres rechazaba la operación porque los hijos
seguían existiendo. Las tablas nativas de Chatwoot no tienen este problema porque no tienen FK
constraints hacia `inboxes`.

Por qué `dependent: :destroy` y no `:destroy_async`: con `destroy_async` Rails encola un job para
borrar los hijos y de inmediato intenta borrar el padre — Postgres valida el FK en el momento
exacto del DELETE, antes de que el job async corra, y lo rechaza. Con `destroy` (sincrónico), el
`DELETE FROM contact_trackings` ocurre dentro de la misma transacción, antes de borrar el inbox.

**Fix → `app/models/inbox.rb`:**
```ruby
has_many :contact_trackings, dependent: :destroy
has_many :command_sessions, dependent: :destroy
has_many :tracking_templates, dependent: :nullify
```

## Causa raíz 2 — enterprise concern con tabla inexistente

`enterprise/app/models/enterprise/concerns/inbox.rb` agrega `has_many :inbox_response_sources`
dinámicamente cuando el vector extension de Postgres está activo. En este ambiente el extension
está activo pero la tabla `inbox_response_sources` nunca fue creada (se crea opcionalmente vía
`Features::ResponseBotService#create_tables`, nunca ejecutado). Al destruir el inbox, Rails
intentaba resolver el `dependent: :destroy_async` de esa asociación y fallaba con
`PG::UndefinedTable`.

**Fix:**
```ruby
if Features::ResponseBotService.new.vector_extension_enabled? &&
   ActiveRecord::Base.connection.table_exists?(:inbox_response_sources)
  add_response_related_associations
end
```

## Despliegue

**Obligatorio reiniciar Puma Y Sidekiq** — ver [[arquitectura-procesos]]. Jobs acumulados en la
dead queue se reintentan con:
```ruby
require 'sidekiq/api'
Sidekiq::DeadSet.new.select { |j| j.display_class == 'DeleteObjectJob' }.each(&:retry)
```

## Verificación (2026-05-18)

Cuenta 568: creado inbox "WebForDelete" (id 1671) → borrado desde UI (200 OK) → `Inbox.exists?(1671)`
= `false`. Ciclo completo en 36 segundos. Fix confirmado.

## Relacionado
- [[arquitectura-procesos]]
