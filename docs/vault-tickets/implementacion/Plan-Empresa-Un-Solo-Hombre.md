# Plan — Empresa de un solo hombre (todo ligado y automatizado)

> **Estado: ABIERTO, en pausa** (2026-10-21). Se retoma cuando el usuario lo llame
> («retoma el plan de la empresa de un solo hombre»). Nada programado todavía.
> Base: [[kontrolya_operacion_autonoma_analisis]] (`docs/kontrolya_operacion_autonoma_analisis.md`)
> · relacionado: [[Plan-Resumen-Negocio]], [[Plan-Metricas-Comercial]], [[Plan-Bandeja-Prioridad]]

## La meta en una frase

Una empresa que la opera **una sola persona** con Kontrolya: los agentes IA atienden, venden,
dan soporte, agendan, facturan y cobran; **el humano solo hace lo que los agentes no pueden**
(aprobar lo que mueve dinero, decidir, el trabajo físico y los clientes que piden una persona),
y lo hace desde **una sola herramienta**: «Mi día» + el Resumen del negocio, también en el celular.

## Principios (del análisis)

1. **Una sola puerta:** el agente coordinador recibe todo (todos los canales) y decide qué
   especialista atiende: Soporte · Comercial · Administración (cobranza, facturación) ·
   Operación (órdenes) · Proyectos.
2. **El caso es la memoria y el contrato:** todo lo de más de un turno vive en un caso; cada
   tarea es de un agente o del humano; la línea de tiempo registra a los dos.
3. **Autonomía por acción** (off / sugerir / automático + umbrales). Lo irreversible o lo que
   mueve dinero empieza en «Sugerir»; sube a automático cuando la aprobación sin cambios es alta.
4. **El humano entra por excepciones** en «Mi día» (aprobar · dato faltante · cliente molesto ·
   baja confianza · trabajo físico · decisión), con botones para resolverlas ahí mismo; al
   resolver, el agente retoma solo.
5. **Un solo humano:** todas las áreas apuntan a él (la tabla de responsables por área queda
   lista para cuando crezca a varios).
6. **No hacer contabilidad:** Kontrolya opera; primero cobrar (liga de pago), luego facturar
   (CFDI vía PAC) y, si hay ERP, conector de escritura.

## El día del dueño (cómo se debe sentir)

- En la mañana abre **«Mi día»**: 5–10 cosas que solo él puede hacer, ordenadas por urgencia,
  cada una resoluble con un clic (aprobar descuento, aprobar factura, responder a un cliente
  molesto, confirmar una visita).
- Abre el **Resumen del negocio**: cuánto vendió, cuánto entra esta semana, qué necesita su
  atención; «Explícame la semana».
- Todo lo demás pasó solo y está en la línea de tiempo de cada caso.

## Fases (del análisis, §7) — estado

| Fase | Qué | Estado |
|---|---|---|
| F0 | Una sola puerta (coordinador; BotSeller, cobrador modo B y CONTPAQi como especialistas); todo lo de más de un turno crea/continúa un caso | ⬜ |
| F1 | Excepciones del agente en «Mi día» con botones; tomar/devolver conversación | ⬜ |
| F2 | Autonomía por acción + umbrales (ampliar `CaseAiConfig`) | ⬜ |
| F3 | Eventos de casos → agentes (acción «encargar a un agente» en reglas de casos) | ⬜ |
| F4 | Responsables por área (para un solo hombre: todo a él; listo para crecer) | ⬜ |
| F5 | Cobrar: cotización → pedido, liga de pago, registro de pago | ⬜ |
| F6 | Facturar: CFDI 4.0 vía PAC (borrador → aprobación → timbrado → envío) | ⬜ |
| F7 | Tablero de agentes: % autonomía, minutos humanos por caso, costo IA | ⬜ |

Ya hecho que sirve a este plan: casos de 4 clases, «Mi día» con puntaje y plan IA,
oportunidad comprometida + promesa vencida, Resumen del negocio (con conversaciones y análisis
IA), período de calendario, filtros de una sola fecha.

## Decisiones pendientes del usuario (para retomar)

1. ¿El coordinador es la puerta única de todos los canales (F0)?
2. ¿«Mi día» es la única herramienta del humano (F1)?
3. Umbrales iniciales: descuento máximo automático y monto máximo de factura automática.
4. ¿Primero cobrar con liga de pago (F5) y después facturar vía PAC (F6), o al revés? ¿Qué
   pasarela (Mercado Pago, Conekta, Stripe, Clip) y qué PAC?
5. ¿Qué ERP usan más los clientes (conector de escritura)?
6. ¿Piloto por Comercial (donde ya está casi todo el ciclo)?

## Bitácora

- 2026-10-21 — Se abre el plan a partir del análisis. En pausa: el usuario va a pasar otros puntos.
- 2026-10-22 — Se diseña el motor en [[Plan-Delegar-Agente-Caso]]: la Automatización es el eje (eventos de caso y de agente), catálogo único de acciones y cada agente con sus automatizaciones. Cubre F0, F2 y F3. Solo plan.
- 2026-10-22 — Hecha la puerta de entrada del humano: [[Plan-Inicio-Mi-Resumen]] (Inicio con avisos por peso, Mi día, agenda, conversaciones, casos y semana).
