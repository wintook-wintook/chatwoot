# Vault — Chatwoot (wintook)

Vault de notas del proyecto, pensado para abrirse con [Obsidian](https://obsidian.md) apuntando
a esta carpeta (`vault/`). Migrado desde la memoria persistente del asistente el 2026-08-03.

## Cómo usarlo

- Cada nota es un archivo Markdown independiente con enlaces `[[wikilink]]` a notas relacionadas.
- Las carpetas son solo organización visual — Obsidian resuelve los links por nombre de nota en
  todo el vault, sin importar la carpeta.
- Las notas de bugs/decisiones incluyen fecha y, cuando aplica, archivo:línea — verificar contra
  el código actual antes de asumir que una referencia sigue vigente (el código cambia, la nota no
  se actualiza sola).

## Estructura

- **Bugs/** — bugs confirmados y corregidos, con causa raíz y fix.
- **Features/** — features agregadas al proyecto, cómo funcionan.
- **Decisiones/** — planes y decisiones pendientes o en curso (no ejecutar sin confirmación).
- **Infraestructura/** — temas de entorno, base de datos, despliegue.
- **Convenciones/** — convenciones de código y estructura del repo.

## Índice de notas

### Bugs
- [[bug-dia-semana-equivocado]] — bot de agenda respondía el día equivocado (2026-08-03)
- [[fix-inbox-delete]] — no se podían borrar canales (2026-05-18)
- [[inbox-round-robin-desync]] — inbox dejaba de recibir mensajes (resuelto 2026-06-19)
- [[fix-whatsapp-named-templates]] — plantillas WhatsApp NAMED sin parameter_name (2026-07-15)
- [[contactpanel-performance]] — console.logs y modales sin v-if en ContactPanel.vue
- [[contactnotes-loop-infinito]] — loop infinito en getter del store de notas
- [[i18n-claves-faltantes-en]] — claves de traducción faltantes en inglés

### Features
- [[bot-seguimientos-openai]] — el bot de seguimientos y su dependencia de OpenAI
- [[discourse-knowledge-base]] — integración Discourse como base de conocimiento (2026-05-08)
- [[automatizacion-tracking-templates]] — acción `assign_tracking_template` en automatizaciones (2026-04-20)
- [[contact-tracking-changes-20260420]] — cambios de comportamiento del bot (20/04/2026)

### Decisiones
- [[refactor-tracking-bot-job-plan]] — plan de reorganización de `contact_tracking_response_analyzer_job.rb` (PENDIENTE)

### Infraestructura
- [[db-wintook-dev-desincronizada]] — BD local compartida con una app Laravel, schema.rb desincronizado
- [[arquitectura-procesos]] — Puma/Sidekiq por instancia, por qué siempre reiniciar ambos

### Convenciones
- [[estructura-y-convenciones]] — rutas de i18n, tags `proyecto@`, convenciones de archivos custom
