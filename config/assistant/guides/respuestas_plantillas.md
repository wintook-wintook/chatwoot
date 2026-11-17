---
key: respuestas_plantillas
title: Respuestas predefinidas y plantillas de WhatsApp
areas: [conversations]
keywords: [respuesta predefinida, respuestas predefinidas, codigo corto, diagonal, respuesta rapida, categoria, prompt de contenido, vectorizar, fuente de datos, plantilla, plantillas de whatsapp, nueva plantilla, aprobada, rechazada, en revision, meta, ventana 24 horas, reabrir whatsapp, sincronizar, variables, buscar respuesta, eliminar varias, editar respuesta, sugeridas, empezar desde, recordatorio de pago, confirmacion de cita, promocion con imagen, encabezado, pie, botones, respuesta rapida, liga, copiar codigo, datos del sistema, vista previa, guardar borrador, enviar a revision, duplicar, ver en meta, calidad, se puede enviar, eliminar plantilla, filtros de plantillas]
pages: [conversations, conversation, canned_responses, whatsapp_templates]
sources:
  - app/javascript/dashboard/routes/dashboard/settings/canned/*.vue
  - app/javascript/dashboard/routes/dashboard/settings/whatsappTemplates/*.vue
  - app/javascript/dashboard/routes/dashboard/settings/whatsappTemplates/*.js
  - app/javascript/dashboard/components/widgets/conversation/WhatsappTemplates/*.vue
  - app/javascript/dashboard/i18n/locale/es/cannedMgmt.json
  - app/javascript/dashboard/i18n/locale/es/whatsappTemplates.json
  - app/controllers/api/v1/accounts/canned_responses_controller.rb
  - app/models/whatsapp_template.rb
reviewed: 2026-11-14
---
## Para qué sirve
- Respuestas predefinidas: textos guardados para contestar rápido. También son información que los agentes IA consultan para contestarle al cliente.
- Plantillas de WhatsApp: mensajes aprobados por Meta. Son lo único que puedes mandar por WhatsApp cuando pasaron más de 24 horas desde el último mensaje del cliente.

## Dónde está
En Catálogos › Respuestas Predefinidas y Catálogos › Plantillas de WhatsApp.

## Cómo se hace
### Crear una respuesta predefinida
1. Entra a Catálogos › Respuestas Predefinidas y pulsa «Agregar respuesta predefinida».
2. Escribe el «Código corto» (el nombre con que la vas a llamar; es obligatorio) y, si quieres, elige su «Categoría» (o «Sin categoría»).
3. En la pestaña «Mensaje» escribe el texto (es obligatorio). Escribe {{ para insertar un dato que se llena solo, como el nombre del contacto.
4. Opcional, para los agentes IA: en «Prompt de Contenido» explica cómo debe usar el agente ese mensaje (el cliente no lo ve). Si el mensaje no es información para el cliente sino instrucciones para el agente, marca «El mensaje es el prompt».
5. Pulsa «Enviar».

### Buscar, editar y eliminar respuestas
1. En la lista busca con «Buscar en el nombre o el contenido…» y filtra por categoría («Todas las categorías», «Sin categoría» o una tuya). «Quitar filtros» limpia todo.
2. Las columnas son «Nombre», «Contenido», «Categoría», «Fuente de datos», «Creada», «Cambió» y «Acciones». Pulsa el título de una columna para ordenar.
3. En «Acciones», el lápiz («Editar») abre la respuesta y el bote («Eliminar») la borra, después de confirmar.
4. Para borrar varias, marca sus casillas (o «Seleccionar todas las de esta página») y pulsa «Eliminar»; sale «Se eliminarán N respuesta(s) predefinida(s)…» y confirmas con «Sí, eliminar».
5. Abajo eliges cuántas ver «Por página».

### Usarla al responder
1. En la caja de respuesta de una conversación escribe «/» y el código corto.
2. Elige la respuesta de la lista: se pega en la caja y puedes ajustarla antes de enviar.

### Organizarlas por categoría
1. Pulsa «Categorías». Escribe el nombre en «Nueva categoría» y pulsa «Agregar». El nombre no lleva paréntesis ni «!» al principio.
2. Ahí mismo, en «Tus categorías», puedes «Renombrar» o «Eliminar» una (sus respuestas no se borran, quedan sin categoría).
3. En «Sugeridas por los nombres» salen grupos de respuestas que ya empiezan igual: «Crear y asignar» crea esa categoría y se las pone.
4. En la lista puedes filtrar por categoría o seleccionar varias y usar «Cambiar categoría…».

### Que los agentes IA las encuentren
La columna «Fuente de datos» dice si cada respuesta ya está lista para los agentes. Si dice «No está en la fuente de datos», pulsa «Vectorizar». Necesita la integración de OpenAI activa.

### Ver y filtrar las plantillas de WhatsApp
1. Entra a Catálogos › Plantillas de WhatsApp.
2. Busca con «Nombre de la plantilla…» y filtra por estado, bandeja, categoría, idioma y tipo («Solo texto», «Con imagen», «Con video», «Con documento», «Con botones», «Con copiar código»). «Limpiar» quita los filtros.
3. Las columnas son «Nombre», «Bandeja», «Idioma», «Categoría», «Estado», «Se puede enviar», «Creada», «Actualizada» y «Acciones». Si Meta la rechazó, sale el motivo; si ya tiene calidad, sale «Calidad: Alta, Media o Baja».
4. En «Acciones»: «Editar» (o seguir el borrador), «Duplicar», «Ver en Meta» y «Eliminar».
5. Haz clic en una plantilla para ver su detalle: «Estado en Meta» paso a paso, «Último envío a Meta», el motivo del rechazo con su consejo, la «Calidad», «Se puede enviar» y sus «Datos» (encabezado, variables, botones e «ID en Meta»).

### Crear una plantilla de WhatsApp
1. Entra a Catálogos › Plantillas de WhatsApp y pulsa «Nueva plantilla».
2. Si quieres, en «Empezar desde:» elige un ejemplo: «En blanco», «Recordatorio de pago», «Confirmación de cita» o «Promoción con imagen».
3. Elige la «Bandeja de WhatsApp», el «Nombre» (se arma solo: minúsculas, sin espacios ni acentos), el «Idioma» y la «Categoría»: «Servicio» (avisos de algo que el cliente ya pidió: pagos, citas, pedidos, envíos) o «Marketing» (promociones, ofertas e invitaciones). Las de «Autenticación» se crean en WhatsApp Manager de Meta.
4. En «Encabezado» elige «Ninguno», «Texto» (máx. 60 letras), «Imagen» (JPG o PNG, hasta 5 MB), «Video» (MP4, hasta 16 MB) o «Documento» (PDF, hasta 100 MB); el archivo lo subes, lo arrastras o pegas su liga.
5. Escribe el «Mensaje» (hasta 1024 letras). Con «Negrita», «Cursiva», «Tachado» y «Código» le das formato; con «Variable» o «Datos del sistema» agregas datos que cambian: nombre del contacto, primer nombre, apellido, correo, teléfono, empresa, nombre del agente, número de conversación, bandeja o fecha de hoy. Si la variable se llama como un atributo personalizado, se llena con ese dato; con cualquier otro nombre la escribe el agente al mandarla.
6. Agrega el «Pie (opcional)», corto y sin variables.
7. En la pestaña «Botones» agrega, si quieres, «Respuesta rápida», «Liga» (fija o que termina con un dato del cliente), «Teléfono» o «Copiar código». Meta permite hasta 10 botones, 2 de liga, 1 de teléfono y 1 de copiar código.
8. En la pestaña «Variables» pon un ejemplo de cada variable: Meta los revisa y salen en la vista previa.
9. Revisa la «Vista previa» y «Lista para Meta» («Todo en orden: ya la puedes mandar a revisión.»). Pulsa «Enviar a revisión», o «Guardar borrador» para terminarla después. Si sales con cambios sin guardar te pregunta «¿Salir sin guardar?».

### Crear una plantilla con Dali
1. En «Nueva plantilla», arriba está «Crear con Dali». Escribe qué quieres lograr, por ejemplo «avisar que el pedido ya salió y cuándo llega»; si quieres, elige el tono (cercano, formal o directo).
2. Pulsa «Proponer»: llena el Nombre (estructurado: área_propósito_detalle, por ejemplo ventas_recordatorio_cotizacion), la Categoría con su porqué, el Encabezado, el Mensaje, el Pie, los Botones de respuesta rápida y los ejemplos de las variables.
3. Las variables del contacto (nombre, empresa, agente…) se llenan solas al enviar; las demás (por ejemplo {{fecha_entrega}}) se avisan abajo: se llenan al enviar.
4. Si no te gusta, «Otra propuesta»; para cambios, escríbelos en «Ajustar» (más corta, sin emojis…).
5. La Bandeja (el canal) la eliges tú. Revisa todo y pulsa «Guardar borrador» o «Enviar a revisión»: Dali no guarda ni manda nada solo.

### Usar una plantilla en la conversación
1. Abre la conversación de WhatsApp y pulsa el botón «Plantillas de Whatsapp», abajo de la caja de respuesta.
2. Busca en «Buscar Plantillas» y elige la plantilla. Solo salen las aprobadas de esa bandeja.
3. Revisa las «Variables»: las que salen del contacto se llenan solas («Se llenó con: …»); si al contacto le falta ese dato, escríbelo. Si el encabezado lleva archivo, se manda el de la plantilla o eliges «Subir archivo» o «Pegar liga»; si tiene botones de liga o código, escribe su dato.
4. Pulsa «Enviar Mensaje» («Regresar» vuelve a la lista). Cuando el cliente conteste, se abre otra vez la ventana de 24 horas y puedes escribir libre.

## Dudas frecuentes
- Estados de una plantilla: Borrador, Enviada, En revisión, Aprobada, Rechazada, Pausada por Meta, Deshabilitada por Meta o En apelación. Solo las aprobadas se pueden mandar.
- Me la rechazaron: abre la plantilla para ver el motivo, corrígela con «Editar» y vuelve a mandarla.
- ¿Qué puedo cambiar de una plantilla ya enviada? Solo la categoría y el contenido; al guardar («Guardar y reenviar») vuelve a revisión. El nombre, el idioma y la bandeja quedan fijos. En un borrador puedes cambiar todo menos la bandeja.
- No me deja editar: solo se editan las aprobadas, las rechazadas, las pausadas y los borradores. Mientras Meta la revisa sale «No se puede editar mientras Meta la revisa o en su estado actual.». Para una parecida, usa «Duplicar».
- Hice la plantilla directo en Meta: pulsa «Sincronizar» para traerla.
- Si eliminas una plantilla que ya llegó a Meta, también se borra allá (solo ese idioma) y ese nombre no se puede volver a usar durante 30 días. Un borrador solo se borra aquí. Antes de borrar revisa dónde se usa; si está en uso, te lo dice y pide marcar «Entiendo que esos envíos pueden fallar hasta que cambie la plantilla.» para «Eliminar de todos modos».
- La pantalla de Respuestas Predefinidas también tiene las pestañas «Vocabulario», «Sinónimos», «Foros» y «Menú del sistema»; son de la configuración del bot y no se explican aquí.

## Quién puede
- Respuestas predefinidas: los usuarios que entran a Catálogos › Respuestas Predefinidas pueden crearlas y usarlas; cualquiera las usa con «/» al responder.
- Plantillas de WhatsApp: solo el Administrador las crea y edita. Mandarlas en una conversación lo hace quien atiende esa conversación.
