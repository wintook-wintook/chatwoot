# Fix: plantillas WhatsApp NAMED sin parameter_name

**Detectado:** 2026-07-08 (cuenta 576, inbox 1769 "Provistock WhatsApp", WhatsApp Cloud API)
**Commiteado:** 2026-07-15 — commit `2188003d8` en `develop`

## Causa raíz

Meta exige `parameter_name` en cada parámetro de plantillas con `parameter_format: "NAMED"`.
Chatwoot armaba los parámetros descartando la clave del hash y mandando solo
`{type: 'text', text: value}`, rompiendo **cualquier** plantilla NAMED (no específico de una
cuenta). Meta respondía `(#100) Invalid parameter — Parameter name is missing or empty`.

## Fix

**Archivo:** `app/services/whatsapp/send_on_whatsapp_service.rb`

Se agregaron `build_processed_parameters` y `named_parameter_template?`: consultan
`channel.message_templates` por nombre y, si `parameter_format == "NAMED"`, agregan
`parameter_name: key`. Si es posicional (o no se encuentra la plantilla), comportamiento idéntico
al anterior. La línea original quedó comentada (no borrada) a pedido del usuario.

De paso se eliminó un `rubocop:disable Metrics/CyclomaticComplexity` que había quedado redundante
tras el refactor (el método bajó de complejidad y el disable se volvió innecesario).

## Historia: por qué se reaplicó dos veces

El primer intento (2026-07-08) se verificó con `rails runner` pero **nunca se guardó** — no hubo
commit ni stash, se perdió en algún `git pull`/reset posterior. El 2026-07-15 se detectó que el
código en disco no tenía el fix (contradiciendo el recap viejo) y se reaplicó desde cero, esta vez
con commit inmediato.

**Lección:** no dar por hecho que un fix documentado sigue en el working tree — verificar el
archivo real antes de asumir que solo falta desplegar. [[db-wintook-dev-desincronizada]] ya
advertía que este repo tiene ruido de schema/anotaciones sin commitear constantemente, lo cual hace
fácil perder cambios reales entre medio.

## Verificación (2026-07-15, con datos reales de la BD local, sin mocks)

- Canal id=53 (inbox 1333), plantilla `saludo` (NAMED) → payload con `parameter_name: "nombre"` y
  `parameter_name: "vendedor"` ✅
- Canal id=6, plantilla `contador` (POSITIONAL) → payload sin `parameter_name`, idéntico al
  comportamiento previo → sin regresión ✅
- Rubocop limpio sobre el archivo.
- No se corrió la suite de RSpec (mismo problema de entorno: `test` y `production` apuntan a la
  misma BD).

## Pendiente

- Falta reiniciar Puma y Sidekiq para que la cuenta 576 tome el código nuevo — ver
  [[arquitectura-procesos]].
- Mensajes `message_id 8765822` y `8768190` (conversación 25178090, status `failed`) no se
  reintentaron — reenviar manualmente si se decide, una vez desplegado.
- Hallazgo aparte no relacionado: conversación 25178152 (display_id 405) falla por error **131042**
  (elegibilidad de pago del WABA en Meta Business Manager) — no es bug de código.
- Mismo patrón sin auditar en proveedor `whatsapp_360_dialog` (no debería verse afectado, no
  probado en canal real).

## Relacionado
- [[db-wintook-dev-desincronizada]]
- [[arquitectura-procesos]]
