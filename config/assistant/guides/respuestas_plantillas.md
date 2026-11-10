---
key: respuestas_plantillas
title: Respuestas predefinidas y plantillas de WhatsApp
areas: [conversations]
keywords: [respuesta predefinida, respuestas predefinidas, codigo corto, diagonal, respuesta rapida, categoria, prompt de contenido, vectorizar, fuente de datos, plantilla, plantillas de whatsapp, nueva plantilla, aprobada, rechazada, en revision, meta, ventana 24 horas, reabrir whatsapp, sincronizar, variables]
pages: [conversations, conversation, canned_responses, whatsapp_templates]
---
## Para qué sirve
- Respuestas predefinidas: textos guardados para contestar rápido. También son información que los agentes IA consultan para contestarle al cliente.
- Plantillas de WhatsApp: mensajes aprobados por Meta. Son lo único que puedes mandar por WhatsApp cuando pasaron más de 24 horas desde el último mensaje del cliente.

## Dónde está
En Catálogos › Respuestas Predefinidas y Catálogos › Plantillas de WhatsApp.

## Cómo se hace
### Crear una respuesta predefinida
1. Entra a Catálogos › Respuestas Predefinidas y pulsa «Agregar respuesta predefinida».
2. Escribe el Código corto (el nombre con que la vas a llamar) y, si quieres, elige su Categoría.
3. En la pestaña Mensaje escribe el texto.
4. Opcional, para los agentes IA: en «Prompt de Contenido» explica cómo debe usar el agente ese mensaje (el cliente no lo ve). Si el mensaje no es información para el cliente sino instrucciones para el agente, marca «El mensaje es el prompt».
5. Pulsa «Enviar».

### Usarla al responder
1. En la caja de respuesta de una conversación escribe «/» y el código corto.
2. Elige la respuesta de la lista: se pega en la caja y puedes ajustarla antes de enviar.

### Organizarlas por categoría
1. Pulsa «Categorías». Escribe el nombre en «Nueva categoría» y pulsa «Agregar».
2. Ahí mismo puedes renombrar o eliminar una (sus respuestas no se borran, quedan sin categoría).
3. En la lista puedes filtrar por categoría o seleccionar varias y usar «Cambiar categoría…».

### Que los agentes IA las encuentren
La columna «Fuente de datos» dice si cada respuesta ya está lista para los agentes. Si dice «No está en la fuente de datos», pulsa «Vectorizar». Necesita la integración de OpenAI activa.

### Crear una plantilla de WhatsApp
1. Entra a Catálogos › Plantillas de WhatsApp y pulsa «Nueva plantilla».
2. Elige la Bandeja de WhatsApp, el Nombre, el Idioma y la Categoría (Servicio, Marketing o Autenticación).
3. Escribe el Mensaje; agrega Encabezado, Pie y Botones si los necesitas. Para los datos que cambian usa variables y pon un ejemplo de cada una.
4. Revisa la vista previa y pulsa «Enviar a revisión», o «Guardar borrador» para terminarla después.

### Crear una plantilla con IA
1. En «Nueva plantilla», arriba está «Crear con IA». Escribe qué quieres lograr, por ejemplo «avisar que el pedido ya salió y cuándo llega»; si quieres, elige el tono (cercano, formal o directo).
2. Pulsa «Proponer»: llena el Nombre (estructurado: área_propósito_detalle, por ejemplo ventas_recordatorio_cotizacion), la Categoría con su porqué, el Encabezado, el Mensaje, el Pie, los Botones de respuesta rápida y los ejemplos de las variables.
3. Las variables del contacto (nombre, empresa, agente…) se llenan solas al enviar; las demás (por ejemplo {{fecha_entrega}}) se avisan abajo: se llenan al enviar.
4. Si no te gusta, «Otra propuesta»; para cambios, escríbelos en «Ajustar» (más corta, sin emojis…).
5. La Bandeja (el canal) la eliges tú. Revisa todo y pulsa «Guardar borrador» o «Enviar a revisión»: la IA no guarda ni manda nada sola.

### Usar una plantilla en la conversación
1. Abre la conversación de WhatsApp y pulsa el botón de plantillas de WhatsApp, abajo de la caja de respuesta.
2. Busca y elige la plantilla.
3. Revisa las variables: las que salen del contacto se llenan solas; escribe las que falten.
4. Pulsa «Enviar Mensaje». Cuando el cliente conteste, se abre otra vez la ventana de 24 horas y puedes escribir libre.

## Dudas frecuentes
- Estados de una plantilla: Borrador, Enviada, En revisión, Aprobada, Rechazada, Pausada por Meta, Deshabilitada por Meta o En apelación. Solo las aprobadas se pueden mandar.
- Me la rechazaron: abre la plantilla para ver el motivo, corrígela con «Editar» y vuelve a mandarla.
- ¿Qué puedo cambiar de una plantilla ya enviada? Solo la categoría y el contenido; al guardar vuelve a revisión. El nombre, el idioma y la bandeja quedan fijos.
- Hice la plantilla directo en Meta: pulsa «Sincronizar» para traerla.
- Si eliminas una plantilla que ya llegó a Meta, también se borra allá y ese nombre no se puede volver a usar durante 30 días.

## Quién puede
- Respuestas predefinidas: los usuarios que entran a Catálogos › Respuestas Predefinidas pueden crearlas y usarlas; cualquiera las usa con «/» al responder.
- Plantillas de WhatsApp: solo el Administrador las crea y edita. Mandarlas en una conversación lo hace quien atiende esa conversación.
