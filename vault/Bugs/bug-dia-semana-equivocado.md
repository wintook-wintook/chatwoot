# Bug: bot de agenda respondía el día de semana equivocado

**Fecha:** 2026-08-03
**Detectado en:** conversación `/app/accounts/778/conversations/43`
**Archivo:** `app/jobs/contact_tracking_response_analyzer_job.rb`

## Síntoma

Durante la negociación de horario, el cliente escribió "Y para el Martes mejor?" y el bot respondió
"No hay disponibilidad el domingo" — día equivocado. Antes, con "sábado", sí respondía correctamente.

## Causa raíz

No era un problema de índices desalineados: `SLOT_DAY_NAMES` (línea ~1360) está correctamente
alineado con `Date#wday` de Ruby.

El problema real estaba en `parse_requested_datetime` → `extract_datetime_json` (líneas ~1006-1062):
le pedían a GPT-4o-mini que calculara él mismo la fecha calendario (`specific_date` YYYY-MM-DD) a
partir del nombre del día, sin ningún parseo determinístico en Ruby. El modelo a veces fallaba esa
aritmética.

El proyecto ya tenía la solución correcta en otro flujo (reagendar cita ya creada, `:move`, vía
`router_service.rb`): pedirle al LLM solo un `weekday` ISO (1=lunes...7=domingo) y calcular la fecha
real en Ruby con `Date#cwday` (`weekday_to_date`, línea ~1864 — determinístico). Ese mecanismo nunca
se había aplicado al flujo de negociación de horarios.

## Fix aplicado

Rama `fix/agent_ssusa`.

- `parse_requested_datetime` arma `today` con nombre de día en español (antes usaba `%A` sin locale
  → devolvía inglés) y extrae también `weekday`/`weeks_ahead` de la respuesta del LLM.
- El prompt de `extract_datetime_json` pide `weekday` ISO en vez de que el LLM calcule
  `specific_date` directamente para días nombrados — mismo patrón que `router_service.rb`.
- No se tocó `calculate_reschedule_datetime`/`resolve_reschedule_date`/`weekday_to_date`: ya
  soportaban `:weekday` de forma determinística, solo faltaba que este flujo los alimentara.
- Verificado end-to-end con `rails runner` contra el mensaje real de la conversación 43: "martes"
  ahora resuelve correctamente a martes.

## Por qué importa

Confirma que la clase `ContactTrackingResponseAnalyzerJob` no usa ivars compartidos entre métodos —
todo pasa explícito por parámetros. Esto habilita el [[refactor-tracking-bot-job-plan]] (pendiente).

## Regla general para el futuro

Cualquier lugar donde se le pida a un LLM que calcule una fecha de calendario a partir de un nombre
de día relativo ("el martes", "el sábado que viene") debería preferir pedirle un `weekday` ISO +
Ruby determinístico, no confiar en que el LLM haga la aritmética.

## Relacionado
- [[refactor-tracking-bot-job-plan]]
- [[bot-seguimientos-openai]]
