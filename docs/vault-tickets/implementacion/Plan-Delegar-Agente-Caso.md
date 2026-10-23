# Plan — Delegar un caso a un agente IA (con la Automatización como eje)

> **Estado: PLAN, sin programar** (rediseñado 2026-10-22). El usuario pidió solo el plan:
> «no hagas nada, vamos a crear solo el plan». Se retoma cuando lo llame.
> Relacionado: [[Plan-Empresa-Un-Solo-Hombre]] (este plan es su motor: F0, F2 y F3)
> · [[Plan-Bandeja-Prioridad]] («Mi día» recibe las tareas de regreso)

## La idea en una frase

Desde el caso, el humano **delega a un agente IA**. Cada agente trae **sus propias
automatizaciones**, y esas automatizaciones (del módulo de Automatización que ya existe,
usando un **catálogo único de acciones**) son las que hacen que los agentes se activen, se
pasen el trabajo, avisen al cliente y le regresen el caso al humano.

## Decisiones tomadas (2026-10-22)

1. **En el caso solo existe «Delegar a agente».** El humano elige un **agente**, no una
   automatización. Para no confundir, en el caso **no se pueden elegir automatizaciones**: las
   automatizaciones vienen con el agente.
2. **Cada agente tiene una pestaña «Automatizaciones»** con las que están ligadas a él.
   Configuración → Automatización sigue mostrando **todas**.
3. **Las Reglas del agente (palabras clave) se quedan como están**: cancelar, pausar, objetivo
   cumplido, interesado, agendó.

## Lo que hay hoy (revisado)

| Dónde | Qué lo dispara | Acciones que tiene |
|---|---|---|
| **Automatización** (`AutomationRule`: `event_name`, `conditions`, `actions`, por cuenta) | Eventos de la conversación: creada, actualizada, abierta, mensaje | Asignar agente o equipo, etiquetar, cambiar estado o prioridad, nota privada, mensaje, webhook, correo, **asignar caso** (`assign_case_type`), **asignar agente IA** (`assign_tracking_template`), campaña, pausar o cancelar seguimiento |
| **Reglas del agente** (`KeywordActionService`) | Palabra clave en un mensaje | Cancelar, pausar, objetivo cumplido, interesado, agendó (las dos últimas también etiquetan y asignan) |
| **Reglas de casos** (`Cases::RuleEngineService`) | Caso creado, mensaje, SLA vencido | Asignar agente o equipo, prioridad, estado, escalar, cerrar, notificar, etiquetar; `trigger_tracking` declarada y nunca programada |

Cada lugar tiene su propia lista, con acciones repetidas y nombres distintos, y ninguno sabe de
los otros. Además, la Automatización solo ve eventos de la **conversación**: un cambio de etapa,
una promesa vencida o una visita para mañana no le llegan.

## 1. La Automatización es el eje

Una automatización sigue siendo **cuándo → si → qué**, con más eventos y las acciones del catálogo.

| Cuándo (eventos) | Hoy | Se agrega |
|---|---|---|
| Conversación | Creada, actualizada, abierta, mensaje | — |
| **Caso** | — | Creado, cambia de etapa, sin movimiento N días, N días antes de una fecha, promesa vencida, resuelto, ganado o perdido |
| **Agente** | — | Delegación iniciada, cumplió su objetivo, no lo logró, el cliente pide un humano, palabra clave detectada |

- Los eventos por tiempo («sin movimiento», «antes de la fecha», «promesa vencida») se revisan con
  una tarea programada cada hora (ya hay una así para el SLA).
- **Una automatización puede ligarse a varios agentes.** Por ejemplo, «Si el cliente pide un
  humano → tarea al responsable y terminar la delegación» sirve para todos.
- Las automatizaciones que no están ligadas a ningún agente funcionan como hoy: para toda la cuenta.
- Las ligadas a un agente solo corren **mientras ese agente tiene delegado el caso** (o la
  conversación).

## 2. Catálogo único de acciones

Cada acción se define una vez: qué hace, sobre qué actúa, qué datos pide y desde dónde se puede
usar. Automatización, Reglas de casos y Reglas del agente muestran la lista del catálogo,
filtrada por lo que tiene sentido en cada lugar («Mover de etapa» solo si hay caso).

| Acción | Actúa sobre | Hoy existe en |
|---|---|---|
| Asignar responsable / equipo | Conversación o caso | Automatización, Reglas de casos |
| Poner / quitar etiqueta | Conversación | Automatización, Reglas de casos |
| Cambiar prioridad / estado | Conversación o caso | Automatización, Reglas de casos |
| Nota privada / mensaje al cliente | Conversación | Automatización |
| Asignar caso (crear o cambiar tipo) | Caso | Automatización |
| **Delegar a agente IA** | Caso + seguimiento | Nueva (reemplaza a `trigger_tracking` y amplía «asignar agente IA») |
| **Terminar delegación** (cumplida / no cumplida) | Caso + seguimiento | Nueva |
| Pausar / cancelar seguimiento | Seguimiento | Automatización, Reglas del agente |
| Marcar interesado / agendó / objetivo cumplido | Seguimiento | Reglas del agente |
| **Crear tarea** al responsable | Caso | Nueva |
| **Mover de etapa** | Caso | Nueva |
| **Marcar comprometida** | Caso comercial | Nueva |
| Escalar / cerrar caso | Caso | Reglas de casos |
| Notificar | Persona | Reglas de casos |

- Las acciones de siempre se registran en el catálogo **tal como están**: las reglas existentes
  siguen funcionando igual.
- Una acción nueva se programa una vez y aparece en los tres lugares.
- **Delegar a agente IA** como acción permite que un agente le pase el caso a otro (de
  «Seguimiento comercial» a «Cobranza» al ganar la venta).

## 3. Delegar desde el caso

En el encabezado del detalle, **junto a «Asignado a»** (delegar no reemplaza a asignar):

```
Responsable: Ana López ▾      🤖 Delegar a agente IA
```

La ventanita pide:
- **Agente:** la lista de Agentes IA. Cada uno muestra cuántas automatizaciones trae.
- **Instrucción para este caso** (opcional): «Recuérdale el pago de la factura 123».
- **Cuándo empieza:** ahora o en una fecha.

Al confirmar:
- Se crea el seguimiento con ese agente, **ligado al caso**.
- El agente recibe su Entrenamiento más el **contexto del caso**: folio, título, etapa, monto,
  fecha comprometida e instrucción.
- Se dispara el evento **«Delegación iniciada»**, y se activan las automatizaciones del agente.
- Encabezado: `Responsable: Ana López · 🤖 Delegado a Agente Cobranza · desde 22 oct  [Retomar]`.
- Etiqueta 🤖 en la Lista y el Tablero.
- Línea de tiempo: «Delegado a Agente Cobranza por Ana».

El responsable sigue siendo Ana: el agente trabaja, pero el caso es de ella.

## 4. La pestaña «Automatizaciones» del agente

- Muestra solo las automatizaciones ligadas a ese agente.
- Desde ahí se crea una nueva (queda ligada a él) o se liga una existente.
- Al crear un agente se ofrece una automatización básica: «Si no logra su objetivo → tarea al
  responsable».

Ejemplos (lo que antes eran las tablas de reglas por etiqueta y por evento):

| Automatización del agente | Cuándo | Qué hace |
|---|---|---|
| Cliente pide humano | El cliente pide un humano | Crear tarea al responsable + terminar delegación |
| Pago confirmado | Palabra clave «ya pagué» / etiqueta `pago-confirmado` | Terminar delegación como cumplida + tarea «Verificar el depósito» |
| Promesa de pago | Etiqueta `promesa-pago` | Marcar comprometida (en «Sugerir»: crea tarea de aprobación) |
| No contesta | El agente no logró su objetivo | Crear tarea «No respondió, llamar» |
| Cotización enviada | Etiqueta `cotizacion-enviada` | Mover a la etapa «Propuesta» |
| Pasa a cobranza | Caso ganado | Delegar a «Cobranza»: «Da seguimiento al pago» |

## 5. Lo que funciona sin configurar nada

- «Objetivo cumplido» → la delegación termina como **cumplida**, con nota en el caso.
- «Cancelar», «pausar» o intentos agotados → la delegación termina y el responsable recibe una
  **tarea en «Mi día»**: «El agente no logró… (motivo)».
- Si un humano toma la conversación, el agente se calla y la delegación queda **pausada**.

## Reglas para que no se vuelva un caos

- **Un solo agente delegado por caso a la vez.** Una delegación nueva reemplaza a la anterior y
  queda anotado.
- **El responsable humano no cambia:** delegar no es reasignar.
- **Sin ciclos:** una automatización que dispara a otra tiene un límite de cadena (3 saltos); una
  acción no puede volver a disparar la misma automatización.
- **Si un humano toma la conversación, el agente se calla.**
- **WhatsApp:** fuera de la ventana de 24 h, solo con las plantillas aprobadas del seguimiento.
- **Lo que mueve dinero empieza en «Sugerir»** (autonomía por acción, F2 del plan de la empresa
  de un solo hombre): marcar comprometida o un descuento crean una tarea de aprobación.
- **Todo en la línea de tiempo:** qué automatización corrió, por qué evento, qué hizo cada
  acción, delegado, devuelto y por qué.

## Fases

| Fase | Qué | Estado |
|---|---|---|
| D1 | Catálogo de acciones en el servidor; registrar las existentes sin cambiarlas; acciones nuevas: delegar, terminar delegación, crear tarea, mover de etapa, marcar comprometida | ⬜ |
| D2 | Delegar desde el caso: botón, ventanita, seguimiento ligado al caso con contexto, 🤖 en Lista/Tablero, «Retomar», línea de tiempo | ⬜ |
| D3 | Fin automático de la delegación (cumplido / cancelado / intentos agotados / humano toma) + tarea en «Mi día» | ⬜ |
| D4 | Automatización ligada a agentes (varios agentes por automatización) + pestaña «Automatizaciones» en el agente + eventos de agente | ⬜ |
| D5 | Eventos del caso en Automatización (etapa, sin movimiento, antes de fecha, promesa vencida, resuelto, ganado/perdido) + job horario | ⬜ |
| D6 | Reglas de casos y Reglas del agente usan el catálogo; límite de cadena y bitácora | ⬜ |
| D7 | Autonomía por acción (automático / sugerir / apagado), enlazada con F2 | ⬜ |
| D8 | Etapas con plantilla de tareas en la Automatización: evento **«Etapa completada»** (se terminaron las tareas obligatorias) y acciones **«Mover de etapa»** y **«Crear tareas de la plantilla»** (ej.: al entrar a Propuesta → delegar a «Seguimiento comercial»). Viene de la T5 de [[Plan-Plantilla-Tareas-Etapa]] | ⬜ |

## Decisiones que quedan

1. ¿El botón va **junto a «Asignado a»**? (propuesto)
2. ¿Las acciones nuevas de la primera versión son **crear tarea, terminar delegación, mover de
   etapa y marcar comprometida**?
3. Cuando el agente no logra su objetivo, ¿basta la **tarea en «Mi día»** o también una
   **notificación**?
4. ¿Las automatizaciones ligadas a un agente corren **solo mientras tiene delegado el caso**?
   (propuesto)

## Bitácora

- 2026-10-21 — Primer diseño: botón «Delegar» y reglas de casos por etiqueta.
- 2026-10-22 — Rediseño: la Automatización es el eje, catálogo único de acciones, cada agente
  con sus automatizaciones (una automatización puede ser de varios agentes). Decisiones: en el
  caso solo «Delegar a agente» (no se eligen automatizaciones); pestaña «Automatizaciones» en el
  agente solo con las suyas; las Reglas del agente se quedan. Solo plan, nada programado.
- 2026-10-22 — Se suma D8 (la T5 de [[Plan-Plantilla-Tareas-Etapa]]): evento «Etapa completada» y acciones de etapa en la Automatización.
