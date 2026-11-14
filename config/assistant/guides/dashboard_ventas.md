---
key: dashboard_ventas
title: Dashboard de ventas
areas: [sales, reports]
keywords: [dashboard de ventas, metricas de ventas, como vamos, dinero en juego, mes a mes, por que perdemos, tasa de cierre, ciclo promedio, ticket promedio, pronostico, ponderado, embudo de ventas, estancadas, comprometido, promesas, motivos de perdida, ranking de vendedores, cotizaciones enviadas, aceptacion, foto de hoy, cierre estimado, ver como tabla, todos los equipos, calcular]
pages: [pipeline, opportunities, quotes]
sources:
  - app/javascript/dashboard/views/gestorTickets/commercial/CommercialMetrics.vue
  - app/javascript/dashboard/views/gestorTickets/commercial/CommercialFunnel.vue
  - app/javascript/dashboard/views/gestorTickets/commercial/metrics/*.vue
  - app/javascript/dashboard/views/gestorTickets/filters/CalendarPeriodPicker.vue
  - app/controllers/api/v2/accounts/case_reports_controller.rb
reviewed: 2026-11-14
---
## Para qué sirve
El Dashboard de ventas responde con números cómo va la venta: qué se ganó, cuánto hay en juego, cómo se compara mes contra mes, por qué se pierde y cómo van las cotizaciones.

## Dónde está
- Informes › Dashboard de ventas.
- También en Ventas › Oportunidades, con la opción Dashboard (junto a Lista y Tablero).
- Arriba filtras por tipo de oportunidad, vendedor («Todos los vendedores») y equipo («Todos los equipos»); en ¿Cómo vamos? y ¿Por qué perdemos? también el «Período». En Dinero en juego, en lugar del período sale «Foto de hoy». Los montos siempre van por moneda.
- Al volver, la pantalla recuerda la pestaña, el tipo, el período, el vendedor y el equipo que dejaste.

## Cómo se hace
### Leer cada pestaña
1. ¿Cómo vamos?: lo decidido en el período que elijas (Este mes, Mes pasado, Este trimestre, Trimestre pasado, Este año, Año pasado o Personalizado, con Desde y Hasta), comparado con el período anterior («comparado con …»). Muestra Ganado en el período, Tasa de cierre, Ciclo promedio (días del alta a ganada), Ticket promedio, Recuperadas, Promesas cumplidas, el Ranking de vendedores y la tabla «Por tipo».
2. Dinero en juego: la foto de hoy de lo abierto. En proceso, Pronóstico ponderado (monto × probabilidad), Cierra este mes, Comprometido esta semana y este mes, el Embudo de ventas por etapa, Requieren atención y el «Pronóstico por mes de cierre estimado» (Mes, Oportunidades, Monto, Ponderado y Comprometido).
3. Mes a mes: compara mes contra mes ganadas contra perdidas, tasa de cierre y oportunidades nuevas. Elige la «Ventana» (Últimos 12 meses, Este año o Año pasado), Cantidad o Monto (con Monto, elige la moneda), y pulsa «Calcular». Si cambias filtros después, avisa que los números son de los filtros anteriores: pulsa «Recalcular».
4. ¿Por qué perdemos?: lo perdido y cancelado en el período (Perdidas y Canceladas, con su parte de lo decidido), con Motivos de pérdida y Motivos de cancelación.
5. Cotizaciones: Enviadas, Aceptación (90 días), Monto en juego, Ganadas, Vencidas, Respuesta del cliente y la tabla «Por responsable». Incluye las cotizaciones que no tienen oportunidad. Los filtros de tipo, vendedor y equipo no aplican a esta pestaña.

### Encontrar oportunidades atoradas
1. Entra a la pestaña Dinero en juego.
2. En «Oportunidades estancadas» elige «Días sin moverse» (Más de 7, 15 o 30 días) y pulsa «Calcular». Las que pasan ese límite se marcan con ⚠ en el embudo y en la lista.
3. En «Requieren atención» salen primero las promesas vencidas (el cliente se comprometió y no ha pagado), luego los cierres estimados vencidos y las estancadas. Haz clic para abrir cada una.

### Ver qué cierra pronto
1. En Dinero en juego, en el «Embudo de ventas», usa «Cierre estimado» (Cierre: cualquier fecha, vencido, esta semana, este mes, próximo mes, este trimestre o sin fecha). Solo acota las oportunidades en curso; las «Ganadas» al final del embudo siguen el período elegido en ¿Cómo vamos?.
2. Elige la moneda («Todas las monedas» o una) y activa «Valor ponderado» para ver montos por probabilidad, o «Perdidas y canceladas» para incluirlas.

## Dudas frecuentes
- ¿Por qué Dinero en juego no tiene período? Porque lo abierto es la foto de hoy: una oportunidad abierta hace meses sigue en juego.
- ¿Lo ganado y lo perdido con qué fecha cuenta? Con la fecha en que se cerró la oportunidad, dentro del período.
- ¿Qué es «Comprometido»? Lo que el cliente prometió pagar o firmar en una fecha (casilla «Comprometida por el cliente» en la oportunidad).
- ¿Qué son las «Recuperadas»? Oportunidades que se habían perdido y después se ganaron.
- Cada gráfica se puede ver como barras o como tabla («Ver como tabla»).
- Las metas y lo logrado contra la meta están en Inicio › Presupuesto. Ver la guía Presupuesto de ventas.

## Quién puede
Entra quien tiene acceso a Ventas o a Informes. Si tu rol tiene Ventas en «Solo lo suyo» (y no tiene Informes), ves solo tus propios números.
