---
key: campo_mi_ruta
title: Mi ruta en campo (celular)
areas: [agenda, service]
keywords: [mi ruta, mi ruta en campo, campo, celular, tecnico, visitas de hoy, voy en camino, llegue, ubicacion, termine, terminar visita, firma, concluir, mis trabajos, como llegar, google maps, llamar, whatsapp, sin senal, visita sin orden, vendedor en campo, dali, dictar reporte, volver a dali, guardar nota, fotos, antes, despues, materiales, refacciones, cotizar trabajo adicional, cotizacion en campo, cierre con el cliente, quien recibe, calificacion, horas, ir a kontrolya, dia anterior, dia siguiente]
pages: [agenda, my_day, case, field_route, dispatch, task_reports]
sources:
  - app/javascript/dashboard/views/field/**/*
  - app/services/field/**/*.rb
  - app/controllers/api/v1/accounts/field_visits_controller.rb
  - app/controllers/api/v1/accounts/agenda_visits_controller.rb
reviewed: 2026-11-14
---
## Para qué sirve
Mi ruta en campo es la pantalla para el celular de quien sale a visitar clientes: técnicos con órdenes de trabajo y vendedores con visitas de su agenda. Muestra las visitas del día en orden de hora y permite avisar que vas en camino, marcar tu llegada y terminar con el reporte, sin el menú completo de la plataforma.

## Dónde está
- Agenda › Mi ruta en campo. Ábrela en el navegador del celular; puedes agregarla a la pantalla de inicio como si fuera una app.
- Tiene dos pestañas: «Mi ruta» (las visitas del día) y «Mis trabajos» (lo que ya terminaste).
- Arriba a la izquierda, «Ir a Kontrolya» te regresa a la pantalla de la que llegaste (o a Inicio si entraste por un enlace). Dentro de una visita ese botón dice «Mi ruta» o «Mis trabajos» y te regresa a la lista.
- Desde Dali en el teléfono: el botón «Mi ruta» de arriba abre esta pantalla, y «Volver a Dali» te regresa.

## Cómo se hace
### Ver tus visitas del día
1. Entra a «Mi ruta». Abre en «Hoy»; cambia de día con las flechas («Día anterior», «Día siguiente»). Si no hay nada dice «No tienes visitas este día.».
2. Cada tarjeta muestra hora, cliente, folio, título, dirección y estado: «Por visitar», «En camino», «Trabajando» o «Terminada».
3. «Cómo llegar» abre la dirección en Google Maps (solo si la visita tiene dirección); «Llamar» y «WhatsApp» contactan al cliente (solo si tiene teléfono).
4. Toca la tarjeta para abrir la visita.

### Atender una visita de orden de trabajo
1. Elige en «Llego en» los minutos (10, 20, 30, 45 o 60 min) y pulsa «Voy en camino»: el cliente recibe un mensaje con tu hora aproximada y el enlace para seguir su servicio.
2. Al llegar pulsa «Llegué»: se guarda la hora y tu ubicación de ese momento, y la orden pasa a en ejecución. Después sale «Llegaste a las …».
3. Marca los puntos del «Checklist» (si la orden tiene lista).
4. En «Bitácora» toma fotos con «📷 Antes» y «📷 Después» (abre la cámara), escribe en «¿Qué hiciste? (puedes dictar)» y pulsa «Guardar nota».
5. En «Materiales y refacciones» busca en «Buscar refacción o servicio» lo que usaste del catálogo.
6. Si hace falta, en «Cotizar trabajo adicional» (solo si la orden tiene contacto) busca los productos, ajusta la cantidad y pulsa «Crear cotización». Sale «Cotización … lista» con «Que el cliente la acepte aquí» (la abre para que el cliente la acepte en tu celular) o «Enviarla por WhatsApp».
7. Pulsa «Terminé»: se abre «Cierre con el cliente». Escribe «¿Quién recibe?», el «Comentario del cliente (opcional)» y la «Firma del cliente» («Borrar» la limpia).
8. Pulsa «Terminar visita». Si falta algo, sale «Antes de terminar falta:» con la lista: terminar las tareas obligatorias, una foto de antes, una foto de después o la conformidad de quien recibió (según lo que pida el tipo de orden).

### Atender una visita sin orden de trabajo
Son las tareas agendadas marcadas con «Es una visita al cliente» (por ejemplo, la visita de un vendedor).
1. Abre la visita y elige en «Llego en» los minutos; pulsa «Voy en camino» (solo mientras está «Por visitar»). Si el cliente tiene conversación, le llega el aviso; si no, solo queda la hora.
2. Pulsa «Llegué» al llegar (guarda hora y ubicación; solo cuenta la primera llegada).
3. Pulsa «Concluir» y llena el reporte de cierre. Arriba eliges «¿Cómo terminó?»: «Se realizó» o «El cliente no asistió» (también lleva qué pasó y el tiempo). Luego resultado, comentario, evidencia y tiempo dedicado.

### Hacerlo platicando con Dali
1. En Dali pregunta «¿qué visitas tengo hoy?» (botón «Visitas de hoy»), «¿cuál sigue?» o «¿qué le hicimos la última vez a Mario?».
2. «Avísale a Mario que llego en 20»: sale la tarjeta «Voy en camino»; al confirmar le llega el aviso con tu hora.
3. «Reporta la visita: limpié los filtros y cambié el capacitor»: sale la tarjeta «Reporte de la visita» con el texto y, en una orden, los puntos de la lista ya marcados. Corrige y confirma.
4. En una orden, el reporte queda en la «Bitácora» y los puntos marcados en el «Checklist»; «Llegué», fotos, firma y «Terminar visita» siguen aquí, en Mi ruta.
5. En una visita sin orden, el reporte de cierre queda hecho (con el tiempo dedicado) y la visita queda como realizada; si dices que el cliente no estaba o no asistió, la tarjeta trae marcado «El cliente no asistió» y queda así.

### Revisar lo que terminaste
1. Entra a «Mis trabajos».
2. Elige «Semana» o «Mes» y muévete con las flechas («Anterior», «Siguiente»).
3. Arriba ves «Órdenes» (cuántas terminaste), «Horas» y «Calificación» de los clientes.
4. Abajo, cada orden terminada con su fecha, cliente, folio, horas («Sin horas» si no hay) y estrellas («Sin calificar» si el cliente no calificó). Tócala para abrirla. Si no hay, dice «No terminaste órdenes en este periodo.».

## Dudas frecuentes
- ¿Me rastrea todo el día? No. La ubicación se toma solo al pulsar «Llegué» y al terminar. Si no das permiso, se guarda sin ubicación («Sin ubicación: revisa el permiso del navegador»).
- ¿Y si no tengo señal? En una orden de trabajo, «Llegué», las notas y «Terminé» se guardan en el celular y se mandan solos al volver la señal, con la hora real. Las fotos sí necesitan señal. Con «Enviar ahora» lo mandas a mano.
- ¿Por qué no veo una orden? Salen las visitas de órdenes que se atienden en campo y que son tuyas (las agendaste o eres el responsable de la orden). Las órdenes sin visita se agendan en Servicio › Despacho.
- «Voy en camino» marca error en una orden si el cliente no tiene ninguna conversación para avisarle.
- Las llegadas de las visitas se consultan en Agenda › Reportes, pestaña Llegadas.

## Quién puede
Cualquier usuario ve en Mi ruta solo sus propias visitas: las visitas de órdenes donde es el responsable o quien la agendó, y las tareas agendadas de visita que él organiza. Para avisar, llegar y terminar una orden necesitas poder editarla (Servicio en todo o en solo lo tuyo; el Técnico lo tiene por omisión).
