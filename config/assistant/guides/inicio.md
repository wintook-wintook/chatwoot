---
key: inicio
title: Inicio, Mi resumen y notificaciones
areas: []
keywords: [inicio, mi resumen, resumen, pantalla de inicio, que tengo hoy, mi dia, notificaciones, avisos, avisos importantes, enterado, no leidas, marcar todo como hecho, ver todo, mi negocio, resumen del negocio, presupuesto, mi capacitacion, capacitacion, probar agentes, probador, logo, mi semana, mis casos, mis conversaciones, esperan tu respuesta, agenda de hoy, lo mas urgente, sla en riesgo, listos para pasar de etapa, promesas de pago, periodo, explicame la semana, al iniciar sesion]
pages: [my_summary, my_day, notifications, business_summary, budget, academy, agent_tester, profile, business_summary_access]
sources:
  - app/javascript/dashboard/views/gestorTickets/home/MySummary.vue
  - app/javascript/dashboard/views/gestorTickets/tasks/MyDayNotices.vue
  - app/javascript/dashboard/routes/dashboard/notifications/components/*.vue
  - app/javascript/dashboard/views/gestorTickets/summary/BusinessSummary.vue
  - app/javascript/dashboard/components/layout/config/sidebarItems/v2/index.js
  - app/services/cases/my_summary.rb
reviewed: 2026-11-17
---
## Para qué sirve
Inicio es tu punto de partida: te dice qué tienes que hacer hoy, qué te avisaron y cómo va tu semana, sin buscar en cada pantalla.

## Dónde está
- Inicio, el primer ícono del menú de la izquierda. El logo de tu empresa, arriba a la izquierda, también lleva a Inicio.
- Su menú tiene: «Mi resumen», «Mi negocio» y «Presupuesto» (estas dos solo si te tocan), «Mi capacitación» y «Probar agentes».
- Si tienes avisos sin leer, el número sale sobre el ícono de Inicio y en la pestaña «Notificaciones».

## Cómo se hace
### Ver Mi resumen
1. Entra a Inicio › Mi resumen. Arriba sale tu saludo («Buenos días, …»), «Esto es lo que tienes para hoy.» y tres pestañas: «Resumen», «Mi día» y «Notificaciones».
2. En «Resumen» salen estos bloques:
   - «Lo más urgente de Mi día»: tus 5 tareas más urgentes, con su folio y el motivo (vencida, vence hoy…). Si no tienes, dice «No tienes tareas pendientes. ¡Bien!».
   - «Agenda de hoy»: tus tareas agendadas de hoy con su hora (solo si tienes).
   - «Mis conversaciones»: cuántas tienes abiertas y cuántas esperan tu respuesta («3 abiertas · 1 esperan tu respuesta»), y hasta 5 de las que esperan, con cuánto llevan esperando (la que más lleva, primero).
   - «Mis casos» (solo si hay algo): «Con SLA en riesgo o vencido», «Listos para pasar de etapa» (terminaron las tareas obligatorias de su etapa; algunos piden documentar antes) y «Promesas de pago de esta semana», hasta 5 de cada uno.
   - «Mi semana»: casos resueltos, tareas hechas y ventas ganadas de lunes a hoy, contra los mismos días de la semana pasada («semana pasada: N»). «ventas ganadas» solo sale si hay alguna.
3. Haz clic en una tarea para abrir la pestaña Tareas de su caso; en una cita, un caso o una conversación para abrirlo.
4. «Ver todo» en «Lo más urgente de Mi día» te pasa a la pestaña «Mi día»; en «Mis conversaciones» te lleva a Conversaciones.
5. Si hay avisos importantes, arriba sale «Tienes N avisos importantes» (rojo si alguno es de peso alto). Ábrelo: clic en un aviso abre su caso o conversación; «Enterado» lo marca como leído.

### Trabajar Mi día desde Inicio
1. Pulsa la pestaña «Mi día». Es la misma de Agenda › Tareas: tus pendientes en el orden sugerido, «Mi orden de hoy», la agenda de hoy y «Hecho hoy».
2. Ahí puedes completar tareas o pasarlas a mañana sin salir de Inicio. Los detalles están en la guía de la Agenda.

### Revisar notificaciones
1. Pulsa la pestaña «Notificaciones» (muestra cuántas tienes sin leer).
2. Haz clic en una notificación: se marca como leída y abre la conversación o el caso al que se refiere.
3. Para dejarlas todas como leídas, pulsa «Marcar todo como hecho» (solo sale si tienes alguna sin leer).
4. Van de 15 en 15; abajo cambias de página. Sin ninguna, dice «No hay notificaciones».

### Mi negocio
1. Entra a Inicio › Mi negocio (o al botón «Resumen del negocio» de arriba a la derecha en Mi resumen).
2. Es la foto de toda la empresa: «Lo que necesita tu atención», ventas, soporte, órdenes, proyectos, conversaciones y personas, comparado con el periodo anterior.
3. Arriba a la derecha eliges el «Período»: «Este mes», «Mes pasado», «Este trimestre», «Trimestre pasado», «Este año», «Año pasado» o «Personalizado» (con «Desde» y «Hasta»).
4. «Explícame la semana» le pide a Dali un resumen de esas cifras. El detalle está en la guía de Informes.

### Presupuesto
Inicio › Presupuesto muestra el avance de las ventas contra la meta. Cómo se captura y se lee está en la guía de Presupuesto.

### Mi capacitación
Inicio › Mi capacitación (o el botón «Mi capacitación N/M» arriba a la derecha en Mi resumen, resaltado mientras te falten pasos) tiene tus lecciones y ejercicios, que la plataforma revisa sola. El detalle está en la guía de la Academia.

### Probar agentes
Inicio › Probar agentes es para platicar como cliente con un agente IA «En prueba», sin WhatsApp, y marcar con 👎 lo que contestó mal. Solo salen los agentes que alguien puso «En prueba». El detalle está en la guía del Probador de agentes.

## Dudas frecuentes
- ¿Puedo entrar directo a otra pantalla al iniciar sesión? Sí: en tu perfil (Configuración de Perfil), en «Al iniciar sesión, ir a», elige «Inicio (Mi resumen)», «Conversaciones» o «Mi día».
- No veo «Agenda de hoy», «Mis casos» o «ventas ganadas»: si no tienen nada, no se muestran.
- Mis números de la semana solo cuentan lo tuyo, no lo del equipo.
- Si tu empresa no usa casos, Inicio no aparece y el logo lleva a Conversaciones.
- Me dice «No tienes acceso al Resumen del negocio. Pídeselo a un administrador.»: tu rol no lo ve; el administrador te lo da en Ajustes › Casos y etapas › Resumen del negocio: acceso.

## Quién puede
- Mi resumen, Mi día y Notificaciones: todos; cada quien ve lo suyo. Quien ve la Agenda de todos (Administrador, Supervisor) puede ver el Mi día de otra persona en Agenda › Tareas › Mi día, con «Día de:».
- Mi negocio: el Administrador, los roles que ven todos los Informes (como Supervisor y Consulta) y las personas que el administrador autorice en Ajustes › Casos y etapas › Resumen del negocio: acceso.
- Presupuesto: quien tiene acceso a Ventas.
- Mi capacitación: todos; cada quien ve lo de su rol. «Configura tu cuenta» solo los administradores.
- Probar agentes: todos pueden probar, dar 👎 y guardar pruebas. Aplicar correcciones, lotes y bitácora: solo quien puede cambiar agentes.
