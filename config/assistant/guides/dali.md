---
key: dali
title: El asistente (Dali)
areas: []
keywords: [asistente, dali, equipo, compañero, dia de otro, el dia de, que tiene hoy, asignar tarea a un compañero, usuario o contacto, ctrl j, preguntale, pedirle, tarjeta, confirmar, propuesta, nombre del asistente, que puedes hacer, que haces, que sabes hacer, para que sirves, alcance, alcance de dali, funciones, capacidades, en que me ayudas, borrador, mensaje programado, delegar seguimiento, ventas, meta, conversacion nueva, openai, via dali, telefono, celular, app, instalar, qr, dictar, voz, microfono, portal, contestar, responder, sin responder, quien me escribio, que tengo pendiente, mencion, me mencionaron, chat interno, sin asignar, nota interna, plantilla, 24 horas, visitas, ruta, campo, voy en camino, reporte de la visita, nfc, etiqueta nfc, expo, liga, link, ir a la pantalla, mi perfil, abre mi perfil, conversacion nueva, abrir en kontrolya, modelo de openai, modelo para analisis de ventas, preguntas de ejemplo, sugerencias, arma mi cuenta, armar mi cuenta, configurar mi cuenta con dali, llamar, llamale, marcale, llamada de whatsapp]
pages: [profile, account_settings, my_day, field_route]
sources:
  - app/javascript/dashboard/components/assistant/**/*.vue
  - app/javascript/dashboard/views/dali/**/*.vue
  - app/services/assistant/**/*.rb
  - app/controllers/api/v1/accounts/assistant_controller.rb
  - app/javascript/dashboard/routes/dashboard/settings/account/AccountAssistantSettings.vue
  - app/javascript/dashboard/routes/dashboard/settings/profile/DaliOnPhone.vue
reviewed: 2026-11-14
---
## Para qué sirve
El asistente (se llama Dali, o el nombre que le puso tu empresa) es el ayudante de quien trabaja en la plataforma: le pides las cosas con tus palabras, escritas o dictadas, y él consulta, registra y te deja listo lo que hay que hacer.
- Contesta sobre tus clientes, casos, agenda, conversaciones y ventas.
- Te propone la acción ya llena (una tarea, una cita, una cotización, la respuesta a un cliente) y tú solo la confirmas: nada se hace sin confirmar.
- Te explica cómo se usa la plataforma.
- Está en todas las pantallas y en una app para el teléfono (ahí, con dictado por voz y avisos).

## Dónde está
- En la caja «Pregúntale a …» de la barra de arriba, en todas las pantallas: escribe y da Enter. Enter con la caja vacía o doble clic en la caja abre el panel.
- Con el teclado: Ctrl + J (Cmd + J en Mac) lo abre o lo cierra; Esc lo cierra.
- El panel se abre a la derecha (arriba dice «Tu asistente · Ctrl + J»; el «+» es «Conversación nueva» y la ✕ lo cierra) y sigue abierto mientras navegas. Entiende lo que estás viendo: si estás en un caso, contacto, organización o conversación, «esto» es ese registro.
- En el teléfono: el portal de Dali, a pantalla completa y con dictado (ver «Usarlo en el teléfono»).

## Qué puede hacer
Su alcance, por área (con un ejemplo de cómo pedirlo):
- Mi día: lo que tienes hoy o esta semana, tareas, citas y lo vencido. «¿Qué tengo hoy?»
- Conversaciones: qué te espera, por partes (sin responder, te mencionaron, chat interno sin leer y, a quien reparte, sin asignar); lee la conversación y te deja la respuesta lista para enviar; fuera de las 24 h de WhatsApp propone la plantilla aprobada ya llena. «¿Qué tengo pendiente?», «dile a Mario que su equipo llega el jueves».
- Equipo: contesta en el chat interno y deja notas internas que el cliente no ve. «Contéstale a Ana que ya le mandé el precio.»
- Tu equipo: asignarle una tarea a un compañero y, si tu rol ve la Agenda de todos (Administrador, Supervisor), ver el día de una persona del equipo: sus tareas, citas y atrasadas. «Agrégale una tarea a mi compañero Luis», «¿qué tiene hoy Ana?»
- Clientes: busca contactos, organizaciones y casos (con el mismo buscador de la lupa), cuenta qué ha pasado con un cliente y da de alta contactos nuevos. «¿Qué pasó con Acme?»
- Registrar: notas, tareas, tareas agendadas (llamadas, reuniones, visitas) y mensajes programados al cliente. «Agéndame una llamada con Mario mañana a las 10.»
- Tareas: cancelarlas con su motivo, pasarlas a la agenda o sacarlas de ella, reportar su avance sin completarlas y contar su historial. «Reporta avance de la T003: llamé al proveedor, 20 minutos», «¿cómo va la T004?»
- Casos y oportunidades: crear un caso, pasarlo a otra etapa, marcarlo como ganado, perdido o cancelado, posponerlo o retomarlo, y cambiar monto, cierre estimado, probabilidad o el compromiso del cliente. «Marca ganada la oportunidad de Acme.»
- Cotizaciones (si puedes crear en Ventas): armarlas con los productos y precios del Catálogo (la tarjeta trae cantidad, «Precio sin IVA», subtotal, IVA y total; al confirmar queda en borrador), mandárselas al cliente y ver las que tiene abiertas. «Cotízale a Mario 3 paneles y la instalación.»
- Ventas (si tienes acceso a Ventas): cómo vas contra la meta, ranking de vendedores y clientes, oportunidades que cierran, vencidas o estancadas, y la salud del embudo. Las cifras son sin IVA; con «Solo lo suyo» son solo tus números. «¿Cómo voy este mes?»
- Seguimiento IA: delegar el seguimiento de un cliente a un agente IA (también con tus plantillas de seguimiento), preguntar cómo va y pausarlo, reanudarlo o cancelarlo. «Dale seguimiento a Mario hasta que confirme la cotización.»
- Trabajo en campo (si tienes acceso a la Agenda): tus visitas del día, cuál sigue, qué se le hizo la última vez al cliente, avisarle «voy en camino» y dictar el reporte de la visita (ver la guía «Mi ruta en campo»). «Avísale que llego en 20.»
- Tareas con el cliente (si tu empresa usa casos): qué le falta a un cliente, quién tiene tareas vencidas y asignarle una tarea que trabaja en su portal (ver la guía «Tareas con el cliente y su portal»). «Pídele a Acme que firme el contrato.»
- Captar en la expo (si tienes acceso a Campañas): el enlace NFC de un evento para grabarlo en una etiqueta desde el teléfono y cuántos se captaron. «Quiero grabar la etiqueta NFC de la expo para Ana.»
- Armar tu cuenta (solo administradores): te pregunta a qué se dedica tu negocio y propone los tipos de caso con sus etapas y los motivos de venta ganada y perdida; al confirmar los crea (solo agrega, no cambia los que ya tienes). «Ayúdame a armar mis etapas, vendemos paneles solares.»
- Llamar por WhatsApp: «llámale a Mario», «márcale al cliente de este caso». Te deja la tarjeta «Llamar por WhatsApp» con el cliente, su teléfono y la bandeja; al confirmar, la llamada sale de tu navegador con el mismo cuadro del botón «Llamar» y hablas tú (Dali no habla en la llamada). Si el cliente no ha permitido llamadas, se le manda la solicitud. Solo en bandejas de WhatsApp con llamadas salientes y si eres de esa bandeja o administrador.
- Ayuda de uso: explicar cómo se hace algo, dónde está y para qué sirve. Cada pantalla que menciona sale como liga: haz clic para ir. «¿Cómo creo un contrato?»
- Borradores: redacta un mensaje para que lo copies. En Plantillas de WhatsApp, «Crear con Dali» arma la plantilla completa.

## Cómo se hace
### Pedirle algo
1. Escribe lo que necesitas: «¿qué tengo hoy?», «¿qué pasó con Acme?», «agéndame una llamada con Mario mañana a las 10», «¿cómo creo un contrato?».
2. Al empezar te saluda y te sugiere preguntas de ejemplo según tu rol («¿Qué tengo hoy?», «¿Cómo vamos este mes?» y «¿Qué oportunidades cierran esta semana?» si tienes Ventas, «¿Cómo se usa la Agenda?», «¿En qué me puedes ayudar?»); después de cada respuesta puede sugerirte cómo seguir. Haz clic en una para preguntarla.
3. Mientras trabaja dice «Dali está pensando…» (con el nombre de tu asistente).
4. El botón «+» («Conversación nueva») de arriba del panel empieza una conversación nueva.

### Confirmar lo que propone
1. Cuando le pides hacer algo, aparece una tarjeta con los datos ya llenos (título, fecha, responsable, texto…). Su nombre dice qué es: «Nota», «Tarea», «Tarea agendada», «Mensaje programado», «Nuevo contacto», «Crear caso», «Cambiar etapa», «Cerrar oportunidad», «Posponer», «Nueva cotización», «Enviar cotización», «Responder», «Nota interna (el cliente no la ve)», «Cancelar», «Agenda ↔ tarea», «Avance de tarea», «Voy en camino», «Reporte de la visita», «Tarea del cliente», «Enlace NFC», etc. Una tarea agendada avisa «Se agrega a tu Google Calendar» si lo tienes conectado.
2. Revísala y corrige lo que haga falta en la misma tarjeta.
3. Pulsa «Confirmar» para que se haga, o «No» para descartarla. Nada se hace sin confirmar.
4. Al quedar hecha, la tarjeta dice «Hecho» y, cuando aplica, «Ver» abre lo que se creó.
5. Una respuesta a un cliente se manda con «Enviar»: sale por su conversación (WhatsApp, correo, chat…) a tu nombre, como si la escribieras en la pantalla.
6. Un borrador no se confirma: se copia con «Copiar» y tú lo pegas donde lo vayas a mandar.

### Usarlo en el teléfono
1. En tu perfil (Configuración de Perfil), en la sección «Usar Dali en mi teléfono», pulsa «Mostrar código QR».
2. Apunta la cámara del teléfono al código: entras ya firmado al portal de Dali de tu empresa. El código sirve una sola vez y vence en 5 minutos; si vence, pulsa «Generar otro código».
3. Sin QR: en el teléfono abre la dirección de la plataforma terminada en /dali y entra con tu correo y contraseña; te lleva directo a Dali.
4. Instálalo como app para tener su ícono: en Android, menú ⋮ › «Instalar en este teléfono»; en iPhone, desde Safari, Compartir › «Agregar a inicio». Los pasos completos están en la guía «Dali en el teléfono».
5. Para dictar (solo en el teléfono), toca el micrófono, habla y vuelve a tocarlo: el texto queda en el cuadro para que lo revises y lo mandes. Cada nota puede durar hasta 2 minutos.
6. Los botones de abajo empiezan la plática ya encaminada, según tu rol: «Mi día», «Sin responder» (si puedes escribir en Conversaciones), «Cotizar» (si puedes crear en Ventas), «Visitas de hoy» (si tienes Agenda), «Agendar», «Anotar» y «Ventas» (si tienes Ventas).
7. En el teléfono Dali no cambia de pantalla solo: cuando quiere abrir algo deja el botón «Abrir en Kontrolya». Lo que abre (una cotización, un caso) se abre en la plataforma; el botón «Volver a Dali» te regresa. Arriba, «Mi ruta» (si tienes Agenda) abre el portal de campo (llegar, fotos, firma). En el menú ⋮ están «Ir a Kontrolya» y, si estás en varias empresas, el cambio de empresa.

### Contestar una conversación
1. Pregunta «¿qué tengo pendiente?», «¿qué tengo sin responder?» o «¿quién me escribió?» (en el teléfono, el botón «Sin responder»). Dali te contesta por partes, solo las que traigan algo:
   - Sin responder: tus conversaciones abiertas asignadas a ti donde el último mensaje es del cliente y nadie le ha contestado (la que más lleva esperando primero). Una respuesta de un bot no cuenta como contestada.
   - Te mencionaron: donde alguien te mencionó con @ en una nota interna y no has escrito nada desde entonces; dice quién y qué te dijo. Sale de la lista en cuanto escribes algo en esa conversación (respuesta o nota) o se resuelve.
   - Chat interno: las salas con mensajes sin leer, de quién y si alguno te menciona. Al pedirle que te lo lea, queda leído.
   - Sin asignar esperando: solo para quien reparte (administradores y supervisores), cuántas hay por bandeja y desde cuándo la más vieja.
2. Dile qué contestar con tus palabras: «dile a Mario que su equipo llega el jueves». Dali lee la conversación y redacta la respuesta.
3. Revisa el texto en la tarjeta «Responder», corrígelo si hace falta y pulsa «Enviar».
4. Si pasaron más de 24 horas desde el último mensaje del cliente en WhatsApp, solo se puede mandar una plantilla aprobada: Dali te propone la que encaje, ya llena, y la tarjeta la muestra tal como le llegará.
5. Para contestarle a quien te mencionó sin que lo vea el cliente: «contéstale a Ana que ya le mandé el precio». Dali te deja la tarjeta «Nota interna (el cliente no la ve)».
6. En el chat interno: «léeme lo que me escribió Ana» y «dile que sí»: el mensaje sale en esa sala, no a un cliente.

## Límites
- No le escribe al cliente sin tu confirmación: te deja una tarjeta (respuesta, envío de cotización), un borrador o un mensaje programado.
- No hace acciones masivas (a muchos clientes a la vez): para eso están las campañas.
- No le contesta solo a los clientes: eso lo hacen los agentes IA (Agentes listos, Seguimiento IA). Dali es el asistente de quien trabaja en la plataforma.
- Solo ve y propone lo que tu rol te permite.
- Si no sabe algo de cómo se usa la plataforma, te lo dice y anota la pregunta para que la documenten.
- Necesita la integración de OpenAI activa; sin ella el panel avisa «Activa la integración de OpenAI para usar el asistente».

## Dudas frecuentes
- ¿Qué puedes hacer? ¿Cuál es tu alcance? Lo de «Qué puede hacer»: consultar, registrar, contestar a tus clientes con tu confirmación, vender (cotizaciones y metas), dar servicio (casos y tareas), trabajo en campo y explicar la plataforma, en la computadora y en el teléfono; siempre dentro de lo que tu rol permite.
- ¿Dali atiende solo a mis clientes? No: te deja la respuesta lista y tú la mandas. Para que un agente atienda solo una bandeja, usa Agentes IA › Agentes listos.
- Le pedí «contéstale» y me preguntó «¿A cuál?»: pasa cuando su mensaje anterior listó varias conversaciones (por ejemplo «¿Qué tengo pendiente?») y no dijiste a quién. Dile el nombre o el número («contéstale a Andrés», «la #3»). La tarjeta «Responder» dice arriba, en grande, a quién va: revísalo antes de «Enviar».
- ¿Cómo sabe si hablo de alguien de mi equipo o de un cliente? Por tus palabras: «usuario», «compañero», «del equipo», «vendedor», «técnico», a quien le asignas la tarea o de quien pides el día es del equipo; «cliente», «contacto», «prospecto» o «la empresa…» es un cliente. Si solo dices el nombre («agrégale una tarea a Ana»), la tarea es para esa persona: si está en tu equipo, queda como responsable (la tarjeta lo muestra antes de confirmar); si no, la busca entre tus clientes.
- ¿«Mi día» de Dali es igual al de la página? Sí: si preguntas por un día (hoy, mañana o ayer), Dali usa la misma lista que Agenda › Tareas › Mi día y la tarjeta del Resumen. Muestra solo las citas que siguen agendadas, primero «Mi orden de hoy» y luego por prioridad, y no muestra lo que pasaste a otro día. Te enseña las primeras 10 tareas y te dice cuántas más hay. Si preguntas por varios días (la semana), te da las citas agendadas y las tareas que vencen o que pasaste a un día de ese rango.
- ¿Puedo ver el día de otra persona? Sí, si tu rol ve la Agenda de todos: pregúntale «¿qué tiene hoy Ana?» o, en Agenda › Tareas › Mi día, elige a la persona en «Día de:». Con «solo lo suyo» solo ves tu día.
- Cuando me explica algo, ¿cómo llego a la pantalla? Cada pantalla que nombra (por ejemplo «Ventas › Oportunidades») sale como liga: haz clic y te lleva sin perder la plática. En el teléfono se abre en la plataforma y «Volver a Dali» te regresa. Si le dices «ábrela», la abre él.
- «Abre mi perfil» abre tu perfil (tu usuario: nombre, foto, contraseña, avisos y Dali en el teléfono). La configuración de la empresa (nombre, idioma, marca, asistente) es «la configuración de la cuenta», en Ajustes.
- ¿Dónde queda lo que hizo? En la actividad del caso, marcado como «vía» el asistente.
- ¿Se puede cambiar su nombre? Sí, en Ajustes › Configuración de Cuenta, sección Asistente, «Nombre del asistente». Vacío = Dali.
- ¿Recuerda lo que platicamos? Sí, la conversación sigue al volver; con «+» empiezas otra.
- ¿Es la misma plática en el teléfono y en la computadora? Sí: es la misma conversación, con los mismos permisos.
- No me deja dictar: permite el micrófono al navegador (o a la app) cuando lo pida; si lo negaste, actívalo en los permisos del sitio.

## Quién puede
Todos los usuarios lo usan, cada uno con lo que su rol le deja ver y hacer. Solo el Administrador cambia su nombre y, en Ajustes › Configuración de Cuenta › Asistente, el «Modelo de OpenAI» y el «Modelo para análisis de ventas» (el que usa cuando explica cifras de ventas; uno más potente responde mejor pero cuesta más por consulta).
