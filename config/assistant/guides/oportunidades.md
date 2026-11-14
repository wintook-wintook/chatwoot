---
key: oportunidades
title: Oportunidades de venta
areas: [sales]
keywords: [oportunidad, oportunidades, crear oportunidad, nueva oportunidad, etapa, mover de etapa, tablero, monto, probabilidad, ponderado, cierre estimado, comprometida, compromiso, ganada, perdida, motivo, posponer, retomar, retomar ahora, cancelar, cambiar estado, reabrir, sin iva, moneda, tareas pendientes, crear proyecto, crear orden de trabajo, cierre vencido, solo comprometidas, resultado, en curso, pospuestas, mostrar cerradas, total de la columna, productos de interes, editar datos de la oportunidad]
pages: [opportunities, case, pipeline, close_reasons, case_types]
sources: [app/javascript/dashboard/views/gestorTickets/commercial/CommercialPanel.vue, app/javascript/dashboard/views/gestorTickets/commercial/OutcomeModal.vue, app/javascript/dashboard/views/gestorTickets/commercial/PostponeModal.vue, app/javascript/dashboard/views/gestorTickets/commercial/CommitmentFields.vue, app/javascript/dashboard/views/gestorTickets/stage/CaseStatusMenu.vue, app/javascript/dashboard/views/gestorTickets/Kanban.vue, app/javascript/dashboard/views/gestorTickets/Index.vue, app/javascript/dashboard/views/gestorTickets/TicketDetail.vue, app/javascript/dashboard/views/gestorTickets/CaseTicketInternalModal.vue, app/javascript/dashboard/views/gestorTickets/filters/CaseScopeBar.vue, app/javascript/dashboard/helper/caseCommercial.js]
reviewed: 2026-11-14
---
## Para qué sirve
Una oportunidad es una venta en curso con un cliente: lleva monto, probabilidad y cierre estimado, y avanza por etapas hasta que se gana, se pierde o se cancela.

## Dónde está
- Ventas › Oportunidades. Arriba eliges cómo verlas: Tablero (las etapas en columnas, con el «Total de la columna»), Lista o Dashboard (el Dashboard de ventas). Se abre en la última que usaste.
- Para filtrar de quién son: «Mías», «No asignadas» o «Todas».
- En el Tablero eliges un tipo de oportunidad (sus etapas son las columnas) y en «Mostrar cerradas:» cuántas cerradas ver: No mostrar, Últimos 7, 30 o 90 días, o Todo el historial.
- En la Lista eliges el resultado: En curso, Ganadas, Perdidas, Pospuestas, Canceladas o Todas. Sus columnas incluyen Monto (sin IVA), Probabilidad, Cierre estimado y Etapa.
- Al abrir una oportunidad, sus datos comerciales van en una línea bajo el título: monto, probabilidad → ponderado y cierre.

## Cómo se hace
### Crear una oportunidad
1. Entra a Ventas › Oportunidades y pulsa «Oportunidad» (o el nombre del tipo, si elegiste uno).
2. Elige el «Tipo de caso»; si quieres, la «Organización (opcional)», y luego el «Contacto»: una oportunidad siempre necesita contacto.
3. Escribe el «Título» y, si quieres, la «Descripción».
4. Llena «Monto (sin IVA)», «Moneda», «Cierre estimado» y «Probabilidad %». Marca «Comprometida por el cliente» si ya te dijo cuándo paga o firma: la fecha pasa a ser la «Fecha comprometida» (obligatoria) y puedes escribir la «Nota del compromiso».
5. Si quieres, elige «Productos de interés», «Categoría» y «Prioridad».
6. En la pestaña «Asignación manual» puedes elegir equipo y responsable.
7. Pulsa «Crear oportunidad».

### Moverla de etapa
1. En el Tablero arrastra la tarjeta a otra columna, o dentro de la oportunidad usa «Cambiar estado ▾» y elige la etapa.
2. Al cambiar de etapa toma la probabilidad de la nueva columna. Mover una oportunidad no le avisa al cliente.
3. Si la sueltas en una columna de cierre (por ejemplo Ganada, Perdida o Cancelada) se pide el resultado y el motivo; en Pospuesta, la fecha para retomarla.

### Editar los datos comerciales
1. Pulsa la línea de datos o el lápiz («Editar datos de la oportunidad»).
2. Cambia «Monto (sin IVA)», «Moneda», «Cierre estimado», «Probabilidad %» o el compromiso del cliente (con su nota). Con compromiso, la fecha pasa a ser la «Fecha comprometida».
3. Pulsa «Guardar» (o «Descartar»). Cerrada ya no se edita: hay que reabrirla. Si el cliente escribe después en la conversación, la oportunidad no se reabre sola; en su historial queda el aviso.

### Ganarla o perderla
1. Pulsa «Ganada» o «Perdida» arriba en la oportunidad. Sale «Cerrar oportunidad …», donde en «Resultado» también puedes cambiar a Ganada, Perdida o Cancelada.
2. Elige el «Motivo». Si el catálogo no tiene motivos para ese resultado, escribe la «Nota» (en Ganada no hace falta). Al ganarla, la probabilidad pasa a 100%.
3. Si la oportunidad tiene más de una cotización abierta y la ganas, elige «¿Cuál cotización aceptó el cliente?».
4. Pulsa «Cerrar oportunidad».
5. Si tiene tareas pendientes, decide qué pasa con ellas: «Cancelarlas», «Conservarlas sin caso» o «Concluirlas ahora» (con su reporte de cierre), y pulsa «Continuar».

### Posponer, retomar o cancelar
1. Abre «Cambiar estado ▾».
2. «Posponer»: pon la fecha en «Retomar el», el «Motivo» (si hay en el catálogo) y una «Nota (opcional)», y pulsa «Posponer». Ese día vuelve sola a la etapa donde estaba y se avisa al responsable.
3. Ya pospuesta, el menú ofrece «Cambiar fecha o motivo» y «Retomar ahora» (la regresa antes de la fecha). En la línea de datos se lee «Pospuesta hasta …».
4. «Cancelar»: la cierra como Cancelada, con motivo.

### Reabrir
1. En una oportunidad cerrada pulsa «Reabrir».
2. Escribe el motivo y confirma con «Reabrir caso».

## Dudas frecuentes
- ¿El monto lleva IVA? No. El monto de la oportunidad siempre es sin IVA; con una sola cotización, toma el subtotal menos descuento de esa cotización.
- ¿Qué es el ponderado? Monto × probabilidad: lo que «probablemente» entra.
- ¿Cómo veo las que ya debieron cerrar? Usa el botón rojo «Cierre vencido» de la barra de filtros. «Solo comprometidas» deja solo las que el cliente ya se comprometió a pagar. En «Filtros», «¿Qué fecha?» ofrece «Cierre / promesa», «Ganada o perdida el» y «Alta».
- Ganada con una cotización: esa cotización queda ganada y las demás abiertas pasan a canceladas.
- Las cotizaciones de la oportunidad están en «Más ▾» › Cotizaciones. Ver la guía Cotizaciones.
- Una oportunidad ganada muestra «Crear proyecto» o «Crear orden de trabajo», si tu empresa los usa: el nuevo caso toma el cliente, la conversación, el asunto y la descripción, y queda ligado a ella.
- Si el Tablero dice «Aún no hay tipos de oportunidad», el administrador debe crear uno de clase Ventas en Catálogos › Tipos de caso.
- Las etapas, colores y probabilidades se cambian en Catálogos › Tipos de caso; los motivos, en Catálogos › Motivos de cierre (administrador).
- También puedes pedirle a Dali que cree, mueva, gane o posponga una oportunidad; siempre te pide confirmar.

## Quién puede
Depende del nivel de Ventas de tu rol: con «Todo» ves y trabajas todas; con «Solo lo suyo», las tuyas; con «Ve todo (sin cambiar)», solo miras. Los montos solo se ven con el permiso «Ver montos». Reabrir solo lo hacen el Administrador y el Supervisor.
