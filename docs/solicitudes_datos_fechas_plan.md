# Plan — `@solicitudes`: pedir todos los datos, fechas que ya pasaron y lo que no está en la hoja

> 27/11/2026. Rama `fix/solicitudes_datos_fechas`, desde `develop` (4d0165a0).
> Salió de probar un agente de agenda de remolques con 9 solicitudes reales de clientes (correos y
> WhatsApp), con un cliente simulado que solo contesta lo que el agente le pregunta.
> Todos los cambios son de `@solicitudes`; nada de esto toca otras directivas.

## Regla de la rama: no afectar a los agentes que ya existen

- Todo el código que cambia vive en `app/services/contact_trackings/service_requests/` y solo se
  ejecuta si el prompt del agente tiene `@solicitudes` (el job lo revisa antes de entrar). Un agente
  sin `@solicitudes` no pasa por aquí.
- Al 27/11/2026, `@solicitudes` lo usaba **un** agente por entorno: local 1 de 35, dev 1 de 115,
  develop (cuenta 2) 1 de 33. Producción no se pudo revisar desde aquí.
- Hay dos tipos de cambio:
  - **Arreglo** (siempre): corrige algo que estaba mal para cualquiera que use `@solicitudes`.
  - **Opción** (apagada por defecto): cambia cómo trabaja solo si la ruta la escribe en
    `@solicitudes(...)`. Sin la opción, todo queda como antes.
- No se toca la búsqueda en hoja (`SheetLookup`, `SheetNumbers`, `Contains`) ni el pie del
  mensaje (`Signature`): los usan muchos agentes.

## Arreglos

| # | Qué pasaba | Cambio | Dónde |
|---|---|---|---|
| A1 | El cliente elegía horario y en el mismo mensaje mandaba peso, medidas y contacto: se apartaba, pero los datos se perdían | Si el mensaje trae algo más que la elección, se guarda en los casos apartados antes de preguntar «¿Confirmo?» | `Choice#capture_data` |
| A2 | «Para hoy» sin hora salía «esa fecha ya pasó» (se comparaba con las 00:00) | Sin hora se compara el día | `DateResolver::Result#past?`, `Scheduler#plan` |
| A3 | Con una fecha u hora que ya pasó, cada turno decía «esa fecha ya pasó / un asesor revisa» y nunca pedía otra | La fecha pasada no queda como fecha del servicio (`past_date`); el turno pide «otra fecha u hora (la que me diste ya pasó)»; «a las 20:00» sola completa ese mismo día | `RequestedDate`, `Turn#date_missing` |
| A4 | Una fecha sin año de hace unos días («7 nov» dicho el 26) saltaba al año siguiente sin avisar | Solo salta de año si pasó hace más de medio año («15 de enero» dicho en noviembre); si no, es fecha pasada (A3) | `DateResolver#build` |
| A5 | «Grúa de 50 t» para una carga de 9 t: la búsqueda de lo más parecido tomaba 50 t (de dos números, el mayor) | Lo más parecido se busca con el peso de la carga; sin peso, como antes | `RelatedUnits#related_text` |
| A6 | Si lo más parecido tampoco tenía horario, decía «a las 11:00 no hay», como si tuviera grúa y estuviera ocupada | La nota dice «no tengo grúa; y lo más parecido: …» | `RelatedUnits#mark_related` |
| A7 | Al confirmar dos servicios, solo se respondía por el que tenía horario; el otro quedaba en silencio | Al confirmar se dice cuáles siguen sin horario | `Actions#unscheduled_text` |

## Opciones (`@solicitudes(...)`, todas apagadas por defecto)

```
@solicitudes(asignar=unidad, datos=primero, sin_dato=pendiente, fecha=mes/dia, faltan=2)
```

| Opción | Qué hace | Por qué es opción |
|---|---|---|
| `asignar=campo` | Ya existía: el campo del caso que recibe la unidad apartada | — (ahora puede ir con otras) |
| `datos=primero` | No ofrece horarios mientras falte un dato obligatorio del tipo de caso | Otro cliente puede preferir ver horarios primero |
| `sin_dato=pendiente` | «No sé el peso» (un dato que se le pidió): queda «Pendiente: el cliente no lo sabe» y ya no se pide. Nunca la fecha | Otro cliente puede exigir el dato |
| `fecha=mes/dia` | 12/03/2026 = 3 de diciembre | Es por agente, no por cliente: con clientes que escriben día/mes, dejarla apagada |
| `faltan=N` | Pide como máximo N datos por mensaje | Estilo |

Además, si el prompt del agente tiene una sección `[GLOSARIO]`, se le pasa al capturista
(`Extractor`) para que entienda cómo escriben sus clientes («TP» sola = tubería). Sin la sección,
el pedido a la IA es idéntico.

## Fuera de esta rama (decidido)

- «Necesito un remolque» sin datos no abre caso en el primer mensaje (lo abre en el segundo).
- Cambiar el equipo de un caso cuando el cliente acepta la alternativa: lo ajusta una persona.
- La búsqueda por palabra «caja» que empata «caja de volteo»: se arregla en la hoja, no en el motor.
- El pie `#etiqueta` / `_Hoja_` / `-TB` del mensaje: es de todos los agentes.

## Cómo se probó

1. Specs: 34 nuevas (opciones, fechas, campos, registro, horarios, turno, elección, confirmación,
   glosario), las 61 de `service_requests` sin cambios, y 1366 de `contact_trackings`, el job y
   las respuestas desde la base de conocimiento: 0 fallas.
2. Rubocop: ninguna ofensa nueva respecto a `develop`.
3. En vivo, con el agente de prueba local y el cliente simulado (ver Resultados).

## Resultados (27/11/2026)

En vivo en el local, agente de prueba con `@solicitudes(asignar=unidad, datos=primero, sin_dato=pendiente, faltan=2)`,
12 pláticas (las 9 solicitudes reales, 2 con fecha u hora pasada y 1 donde el cliente no sabe el peso):

| Antes (sin estos cambios) | Ahora |
|---|---|
| Ofrecía y apartaba horario con datos obligatorios pendientes (2 de 9) | 12/12: los horarios salen solo con todos los obligatorios |
| «No sé el peso» → «Falta: Peso, Medidas» sin fin | Peso y medidas quedan «Pendiente: el cliente no lo sabe»; sigue con fecha y contacto |
| Fecha u hora pasada → «Un asesor revisa» en bucle | «Falta: otra fecha u hora (la que me diste ya pasó)»; «hoy a las 13:00» la completa |
| «Para hoy» sin hora = fecha pasada | Pide la hora |
| 7/11 dicho el 26/11 → 7 nov 2027 | Fecha pasada: pide otra |
| Grúa de 50 t → low boy 60 t sin avisar | «No tengo grúa; lo más parecido que tengo:» con unidades que aguantan las 9 t de la carga |
| Lista de 6 datos de golpe | Máximo 2 por mensaje |
| «TP - KM14» como destino | Origen KM14, carga «TP» (con `[GLOSARIO]` en el prompt) |

Sigue pasando (fuera de esta rama): sin peso y sin el equipo en la hoja, responde «no tengo grúa…
un asesor revisa»; si luego el cliente acepta otro equipo, no se puede cambiar el del caso y lo
contesta el conversacional (lo ajusta una persona).
