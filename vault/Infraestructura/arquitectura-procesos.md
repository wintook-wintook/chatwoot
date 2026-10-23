# Arquitectura de procesos: Puma + Sidekiq por instancia

Cada instancia del proyecto tiene su propio Puma y su propio Sidekiq independientes:

| Instancia | Puma | Sidekiq |
|---|---|---|
| `/home/chatwoot/chatwoot` (puerto 3000) | PID propio | PID propio |
| `/opt/dev/jose_luis` (puerto 3004) | PID propio | PID propio |
| `/opt/dev/mariana` (puerto 3003) | PID propio | PID propio |
| `/opt/dev/luis` (puerto 3002) | PID propio | PID propio |

## Regla operativa

**Siempre reiniciar Puma Y Sidekiq** al desplegar un fix, no solo uno de los dos. Puma sirve las
peticiones HTTP; Sidekiq ejecuta los jobs en background — son procesos separados con código
cargado en memoria de forma independiente. Reiniciar solo Puma deja Sidekiq con el código viejo y
los jobs (incluido el bot de seguimientos, que corre en Sidekiq) siguen fallando o corriendo con
lógica desactualizada.

```bash
# Reiniciar Puma (graceful, recarga workers)
kill -SIGUSR2 <puma_pid>

# Reiniciar Sidekiq (graceful, termina jobs en curso y sale)
kill -SIGTERM <sidekiq_pid>
# El supervisor (foreman/systemd) lo reinicia automáticamente
```

Si hay jobs acumulados en la dead queue (por ejemplo, inboxes que el usuario intentó borrar y
fallaron mientras el bug seguía activo), reintentarlos tras el reinicio:
```ruby
require 'sidekiq/api'
Sidekiq::DeadSet.new.select { |j| j.display_class == '<NombreDelJob>' }.each(&:retry)
```

Confirmado como causa de que un fix "no se note" en producción en [[fix-inbox-delete]] y
[[fix-whatsapp-named-templates]].

## Relacionado
- [[fix-inbox-delete]]
- [[fix-whatsapp-named-templates]]
