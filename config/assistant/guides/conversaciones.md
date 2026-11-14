---
key: conversaciones
title: Conversaciones
areas: [conversations]
keywords: [conversacion, conversaciones, chat, chat con clientes, chat con el cliente, whatsapp, correo, bandeja, responder, mensaje, nota privada, asignar, asignar a mi, resolver, reabrir, abrir, pendiente, posponer, etiqueta, filtro, filtrar conversaciones, guardar filtro, carpeta, editar carpeta, ventana 24 horas, plantilla, menciones, mencionar, mencionar a un companero, arroba, avisar a un companero, no atendidas, sin responder, ligar caso, programar mensaje, mias, no asignadas, todas, ordenar, prioridad, urgente, marcar como no leido, seleccionar varias, cambiar estado, bloquear contacto, desbloquear, enviar transcripcion, buscar mensajes, cambiar el diseno, participantes, unirse a la conversacion, macros, firma, grabar audio, adjuntar, emoji]
pages: [conversations, mentions, unattended, conversation, case, contact, labels]
sources:
  - app/javascript/dashboard/components/ChatList.vue
  - app/javascript/dashboard/components/ChatListHeader.vue
  - app/javascript/dashboard/components/widgets/conversation/**/*.vue
  - app/javascript/dashboard/components/widgets/WootWriter/ReplyTopPanel.vue
  - app/javascript/dashboard/components/widgets/WootWriter/ReplyBottomPanel.vue
  - app/javascript/dashboard/components/buttons/ResolveAction.vue
  - app/javascript/dashboard/routes/dashboard/conversation/*.vue
  - app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue
  - app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js
  - app/javascript/dashboard/components/layout/config/sidebarItems/conversations.js
  - app/javascript/dashboard/i18n/locale/es/chatlist.json
  - app/javascript/dashboard/i18n/locale/es/conversation.json
  - app/finders/conversation_finder.rb
reviewed: 2026-11-14
---
## Para qué sirve
Aquí llegan y se contestan los mensajes de los clientes de todos los canales (WhatsApp, correo, chat de la página web y otros).

## Dónde está
Conversaciones, en el menú de la izquierda. Su menú tiene: «Todas las Conversaciones», «Menciones», «No Atendidas», «Vista de bandeja» (si tu empresa la tiene), «Chat interno» (si está encendido), «Carpetas» (tus filtros guardados, si tienes), «Equipos» (si hay equipos), las «Bandejas de Entrada» agrupadas por canal y «Etiquetas».

## Cómo se hace
### Encontrar una conversación
1. Arriba de la lista elige la pestaña: «Mías», «No asignadas» o «Todas» (cada una con su número).
2. Con el botón «Ordenar conversaciones» eliges el «Estado» (Abiertas, Resueltas, Pendientes, Pospuestas o Todas) y «Ordenar por»: «Última actividad» (más recientes o más antiguas primero), «Creado en» (más recientes o más antiguas primero), «Prioridad» (más alta o más baja primero) o «Respuesta pendiente» (más largo o más corto primero).
3. Para ver un solo canal, equipo o etiqueta, elígelo en el menú.
4. Para buscar por texto, arriba de la lista pulsa «Buscar mensajes en conversaciones»: escribe 3 o más letras y ve los resultados en las pestañas «Todos», «Contactos», «Conversaciones» y «Mensajes». Sirve el número de conversación, el correo, el teléfono o un pedazo del mensaje.

### Filtrar y guardar el filtro en Carpetas
1. Pulsa el ícono de embudo «Filtrar conversaciones».
2. Arma las condiciones con «Agregar filtro» y únelas con «Y» u «O». Puedes filtrar por: «Estado», «Nombre del asignado», «Nombre del buzón» (la bandeja), «Nombre del equipo», «Identificador de la conversación», «Nombre de la campaña», «Etiquetas», «Idioma del navegador», «Nombre del país», «Enlace de referencia», «Creado en», «Última actividad» y los atributos personalizados.
3. Pulsa «Aplicar filtros». Con «Limpiar filtros» (la X roja) quitas todo.
4. Para guardarlo, pulsa el ícono de guardar «Guardar filtro», ponle nombre en «Nombra este filtro» y guárdalo: queda en «Carpetas» del menú.
5. Dentro de una carpeta: «Editar carpeta» cambia sus condiciones («Actualizar carpeta») y «Eliminar filtro» la borra.

### Responder o dejar una nota privada
1. Abre la conversación; abajo está la caja para escribir.
2. En «Responder» el mensaje le llega al cliente. En «Nota privada» solo lo ve tu equipo (el botón dice «Agregar nota»).
3. Shift + Enter hace un salto de línea. Escribe «/» para insertar una respuesta predefinida.
4. En una nota privada escribe @ y el nombre de un compañero para mencionarlo: le llega un aviso y la conversación sale en su «Menciones».
5. Con los botones de abajo eliges un emoji, adjuntas archivos («Adjuntar archivos», también arrastrándolos), grabas audio («Grabar audio», según el canal), prendes o apagas tu firma y, en WhatsApp, eliges una plantilla con «Plantillas de Whatsapp».
6. Si la conversación es de otra persona, arriba de la caja sale «Esta conversación no está asignada a ti…» con el botón «Asignar a mí».

### Asignar, etiquetar y resolver
1. En el panel derecho, en «Acciones de la conversación», cambia el «Responsable» («Asignar a mí» te la pasa a ti), el «Equipo asignado», la «Prioridad» (Ninguna, Urgente, Alta, Media o Baja) y las «Etiquetas de la conversación». Ahí también está «Embudo de contactos» para poner la conversación en un embudo.
2. También con clic derecho sobre la conversación en la lista: «Marcar como no leído», «Marcar como resuelto», «Marcar como pendiente» o «Reabrir conversación» (según su estado), «Posponer» (hasta la próxima respuesta, mañana o la próxima semana), «Prioridad», «Asignar etiqueta», «Asignar responsable» y «Asignar equipo».
3. Cuando termines, pulsa «Resolver» arriba a la derecha. Su flechita trae «Posponer hasta» (próxima respuesta, una hora, mañana, la próxima semana, el próximo mes o «Personalizado…») y «Marcar como pendiente». Una resuelta se vuelve a abrir con «Reabrir»; una pendiente o pospuesta, con «Abrir».
4. Junto a «Resolver» están «Bloquear contacto» (ya no te llegan avisos de sus conversaciones nuevas; se quita con «Desbloquear contacto») y «Enviar transcripción» (manda la conversación por correo).

### Cambiar varias conversaciones a la vez
1. En la lista, pasa el mouse sobre la foto de cada conversación y marca su casilla.
2. Arriba sale «N conversaciones seleccionadas» con: «Asignar etiquetas», «Cambiar estado», «Asignar responsable» y «Asignar equipo».
3. Solo se seleccionan las conversaciones que se ven en la página.

### Ligar a un caso
1. En el panel derecho, el botón «+ Crear caso» crea un caso ligado a esta conversación; si el contacto ya tiene casos dice «Casos (N)» y ahí los ves o creas otro.
2. Desde el caso, «Conversaciones N ▾» liga o agrega conversaciones del contacto.

### Menciones
1. Entra a Conversaciones › Menciones.
2. Salen las conversaciones donde un compañero te mencionó con @ en una nota privada.
3. Tienen las mismas pestañas, orden y estado que «Todas las Conversaciones».

### No atendidas
1. Entra a Conversaciones › No Atendidas.
2. Salen las conversaciones que nadie ha contestado todavía o donde el cliente escribió y espera respuesta.
3. Cuando alguien de tu equipo le contesta al cliente, sale de esta lista.

## El panel de la derecha
- Se abre y cierra con el nombre del contacto, arriba de la conversación.
- Arriba: el contacto con sus datos (correo, teléfono, identificador, redes), el aviso si pidió no ser contactado o si su correo rebotó, y su puntuación de prospección si la tiene. Los íconos son: «Editar», «Crear tarea» y «+ Cotización» (si tu empresa usa casos), «Programar mensaje» y «Notas»; en «···» está «Fusionar contacto» (si puedes editar en Clientes) y «Eliminar contacto» (solo el Administrador). El ícono junto al nombre abre la ficha en otra pestaña.
- Los botones «Delegar seguimiento» (un agente IA le da seguimiento) y el de casos.
- Secciones que se abren y se pueden reordenar arrastrando: «Acciones de la conversación» (con el embudo de contactos, responsable, equipo, prioridad y etiquetas), «Participantes de la conversación» (quién la sigue; «Unirse a la conversación» te agrega y te llegan sus avisos), «Información de la conversación», «Atributos del contacto», «Conversaciones anteriores» y «Macros».

## Límites
- La búsqueda pide al menos 3 caracteres.
- Si tu empresa ocultó los filtros a los agentes, solo el Administrador ve el botón «Filtrar conversaciones».
- La lista carga de 25 en 25; al bajar se cargan más.

## Dudas frecuentes
- WhatsApp no me deja escribir: pasaron más de 24 horas desde el último mensaje del cliente. Sale «Solo puedes responder a esta conversación usando un mensaje de plantilla debido a restricción de ventana de 24 horas». Manda una plantilla aprobada con el botón «Plantillas de Whatsapp»; cuando el cliente conteste, ya puedes escribir libre.
- ¿Se puede mencionar a alguien en el chat con un cliente? Sí, pero en una nota privada: cambia a «Nota privada», escribe @ y el nombre del compañero. El cliente no la ve; a tu compañero le llega un aviso y la conversación sale en su «Menciones». En un mensaje normal al cliente no se menciona. Para hablar entre el equipo sin conversación de por medio está el Chat interno.
- ¿Diferencia entre Menciones y No Atendidas? Menciones: donde alguien te mencionó con @. No Atendidas: las que esperan respuesta de tu equipo.
- Vista de bandeja: tus avisos (asignaciones, menciones, mensajes nuevos) en una lista; se explica en su propia guía.
- Programar un mensaje: el ícono de reloj del panel, o pídeselo al asistente («mándale mañana a las 9 que ya está su cotización»).
- ¿Cómo veo la lista más amplia? El ícono «Cambiar el diseño», junto a la búsqueda, cambia entre la lista angosta y la ancha.

## Quién puede
Según el nivel de Conversaciones del rol: «Todo» y «Ve todo (sin cambiar)» ven todas; «Solo lo suyo» ve solo las asignadas a él (sin la pestaña «Todas») y «No asignadas» solo si su rol puede tomar lo que no tiene dueño. Asignar a otra persona pide el permiso «Asignar a otra persona»; sin él solo puedes tomarla para ti (sale «Tu rol no permite asignar a otra persona.»). El rol Consulta no entra a Conversaciones.
