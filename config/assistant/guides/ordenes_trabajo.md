---
key: ordenes_trabajo
title: Órdenes de trabajo y reporte de servicio
areas: [service]
keywords: [orden de trabajo, ordenes, crear orden, tecnico, visita, programar visita, visita vencida, visitas vencidas, por programar, programadas, en ejecucion, checklist, lista de verificacion, bitacora, fotos antes despues, horas reales, horas estimadas, cronometro, materiales, refacciones, firma, conformidad, quien recibio, reporte de servicio, enviar reporte, trabajo adicional, cotizar en sitio, tecnico externo, facturable, enviar al tecnico, equipo de la orden, metricas de ordenes, retrabajos, a la primera]
pages: [case, cases, service_cases, quotes, dispatch, field_route, maintenance]
sources: [app/javascript/dashboard/views/gestorTickets/workOrder/*.vue, app/javascript/dashboard/views/gestorTickets/CaseTicketInternalModal.vue, app/javascript/dashboard/views/gestorTickets/Index.vue, app/javascript/dashboard/helper/caseFilters.js, app/javascript/dashboard/views/gestorTickets/typeDetail/FieldWorkTab.vue]
reviewed: 2026-11-23
---
## Para qué sirve
Una orden de trabajo es un trabajo planeado para un cliente: tiene técnico (su responsable), dirección, visitas, horas, materiales y, al final, un reporte de servicio con la conformidad de quien recibió. Lo común a todos los casos está en la guía de casos.

## Dónde está
- Servicio › Casos, clase Órdenes (si tu cuenta la tiene activa).
- En la orden: «Más ▾› Reporte de servicio» junta todo el trabajo de campo y los datos de la orden.
- El técnico la trabaja desde el celular en Agenda › Mi ruta en campo.

## Cómo se hace
### Crear una orden
1. En Servicio › Casos elige Órdenes y pulsa «+ Orden de trabajo».
2. En «Datos del caso» elige tipo, contacto y título; escribe las «Horas estimadas» y marca «Facturable» si se cobra.
3. En «Asignación manual» elige al técnico como Responsable.
4. En «Dirección» escribe la «Dirección del servicio»: se usa como lugar de la visita.
5. Pulsa «Crear orden de trabajo».
También nace con «Crear orden de trabajo» desde un caso de Soporte o una oportunidad ganada (toma cliente, conversación, asunto y descripción, y queda ligada), o sola desde un mantenimiento.

### Encontrar órdenes en la Lista
1. Elige «Mías», «No asignadas» o «Todas» y la etapa: Abiertas, Por programar, Programadas, En ejecución, Pausadas, Terminadas, Cerradas o Canceladas.
2. En «Filtros»: Fecha (Visita, Alta o Cerrado el), Facturable, Prioridad, Servicio, Categoría y Responsable.
3. El aviso «Visitas vencidas (N)» deja solo las que tienen una visita cuya hora ya pasó.
La lista muestra Próxima visita, Horas (real / est.), Técnico y Etapa.

### Programar la visita
1. En «Reporte de servicio», en la tarjeta «Orden de trabajo», pulsa «Programar visita».
2. Elige fecha y hora. Se crea una tarea agendada; si la orden se atiende en campo, el técnico la ve en Mi ruta en campo.
3. Arriba dice «Próxima visita:» con la fecha (o «sin programar»). Si la hora pasa sin terminar, sale «Visita vencida». También se agenda y reasigna desde Servicio › Despacho.

### Llevar el reporte de servicio
1. «Dónde se atiende»: En campo o En oficina o remoto (por omisión, «(como dice el tipo)»). En campo y con técnico, «Enviar al técnico» le manda la visita a su WhatsApp.
2. «Equipo»: el equipo del cliente que se atiende (o «Sin equipo»). Si nació de un mantenimiento, dice «Del mantenimiento «…»».
3. «Checklist»: las tareas de la etapa; las marcadas «Obligatoria» se deben terminar. Palomearlas aquí o en Mi ruta no pide reporte por punto (la orden cierra con su reporte de servicio); concluirlas desde Tareas, Mi día o el caso sí pide el reporte de cierre.
4. «Bitácora»: escribe qué se hizo y pulsa «Agregar nota»; también «Foto antes», «Foto después» y «Archivo».
5. «Horas»: «Iniciar» y «Terminar» para el cronómetro, o escribe «Minutos» y una «Nota» y pulsa «Agregar». Abajo sale «Horas reales: …».
6. En la tarjeta «Orden de trabajo» editas «Dirección del servicio», «Horas estimadas», «Horas reales» y «Facturable», y pulsas «Guardar» (o «Descartar»).
7. «Materiales»: concepto, cantidad, unidad y costo unitario, con «Agregar», o búscalo en el catálogo. Se suma el importe y el «Total».

### Terminar con la conformidad del cliente
1. En el celular, el técnico pulsa «Terminé».
2. Escribe «¿Quién recibe?», el comentario del cliente (opcional) y recoge la «Firma del cliente».
3. Pulsa «Terminar visita»: se guardan la hora, la ubicación y la conformidad, y la orden queda terminada.
4. Para cerrar la orden en la computadora («Cambiar estado»), sale «Cerrar orden de trabajo»: se piden las «Horas reales», quién «Recibió» y, si quieres, una «Nota de conformidad». Pulsa «Cerrar orden».

### Enviar el reporte al cliente
1. En «Reporte para el cliente» pulsa «Enviar al cliente»: le llega el enlace por su conversación y queda «Enviado el …».
2. «Copiar enlace» y «Ver reporte» sirven para compartirlo o revisarlo.
El reporte muestra técnico, dirección, equipo, horas, lo que se revisó, qué se hizo, fotos, materiales y quién recibió.

### Cotizar trabajo adicional en sitio
1. En la visita (celular), en «Cotizar trabajo adicional», busca en el catálogo y pon la cantidad.
2. Pulsa «Crear cotización».
3. Elige «Que el cliente la acepte aquí» (la acepta en ese momento) o «Enviarla por WhatsApp».
En la computadora: «Más ▾› Cotizaciones» › «Cotizar trabajo adicional».

## Dudas frecuentes
- ¿Por qué no me deja terminar? Sale «Para terminar la orden falta:» con lo pendiente: terminar las tareas obligatorias y, si el tipo lo pide, una foto de antes, una de después o la conformidad de quien recibió.
- ¿Cómo salen las horas reales? Se suman solas: cronómetro, tiempo a mano, visitas y reportes de tareas.
- ¿Se manda solo el reporte? Depende del tipo: «Enviar solo al terminar» o «Revisar antes de enviar». Se configura en Catálogos › Tipos de caso › pestaña Trabajo en campo, junto con «Se ejecuta en campo» y pedir fotos o conformidad.
- «Enviar al técnico» necesita el contacto del técnico en Ajustes › Usuarios.
- Técnico sin usuario: en «Técnico externo» pulsa «Dar enlace», pon nombre y WhatsApp (opcional) y «Crear enlace». Luego «Enviar por WhatsApp» o «Quitar enlace». Sirve hasta que termina la visita o 7 días.
- «Portal del cliente» (Copiar enlace): el cliente ve en qué va su orden, confirma la visita o pide otra fecha y califica al terminar. La tarjeta dice «Confirmó la visita» o «Pide otra fecha: …».
- El Dashboard de Órdenes (filtro «Todos los técnicos» o uno) muestra abiertas, visitas vencidas, cumplimiento, horas real vs. estimado, retrabajos, materiales facturables, «A la primera» y la calificación del cliente, por técnico y por tipo.
- Una orden cerrada queda en solo lectura.

## Quién puede
- Trabajar órdenes: quien tenga Servicio en todo o en solo lo suyo (el Técnico, por omisión, solo las suyas).
- Configurar el tipo (Trabajo en campo): solo el Administrador.
