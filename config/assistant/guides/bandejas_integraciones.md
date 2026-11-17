---
key: bandejas_integraciones
title: Bandejas, integraciones y equipos
areas: [settings]
keywords: [bandeja, bandejas, bandeja de entrada, canal, canales, agregar canal, otro canal, nuevo canal, agregar bandeja, conectar whatsapp, whatsapp, whatsapp cloud, unoapi, twilio, correo, email, sitio web, chat del sitio, widget, telegram, messenger, instagram, tiktok, line, sms, canal api, horario de atencion, saludo, encuesta de satisfaccion, csat, formulario previo al chat, eliminar bandeja, integracion, integraciones, webhook, api, token de acceso, crm, crm administrativo, kontrolya crm, erp, contpaqi, sistema administrativo, conectar con otro sistema, openai, panel de aplicaciones, dialogflow, traductor, equipo, equipos, crear equipo, asignacion automatica, quien atiende]
pages: [settings, inboxes, integrations, teams, profile, account_settings]
sources: [app/javascript/dashboard/routes/dashboard/settings/inbox/**/*.vue, app/javascript/dashboard/routes/dashboard/settings/integrations/**/*.vue, app/javascript/dashboard/routes/dashboard/settings/teams/**/*.vue, config/integration/apps.yml, config/features.yml, app/javascript/dashboard/i18n/locale/es/inboxMgmt.json, app/javascript/dashboard/i18n/locale/es/integrations.json, app/javascript/dashboard/i18n/locale/es/teamsSettings.json]
reviewed: 2026-11-14
---
## Para qué sirve
- Una bandeja de entrada es donde llegan y se atienden las conversaciones de un canal: un número de WhatsApp, un correo, el chat del sitio web, una red social, etc. Cada canal conectado es una bandeja.
- Integraciones conecta la plataforma con otras herramientas (otro sistema, un CRM, OpenAI…) y activa algunos agentes.
- Equipos agrupa usuarios (por ejemplo «Ventas» o «Soporte») para asignarles conversaciones.

## Dónde está
Ajustes › Bandejas de Entrada, Ajustes › Integraciones y Ajustes › Equipos. Solo las ve el Administrador.
- En Bandejas de Entrada hay una búsqueda («Buscar bandejas...») y un filtro por canal («Todos los canales», «Sitio web», «WhatsApp», «Correo electrónico», «Messenger», «Instagram», «SMS de Twilio», «Telegram», «LINE», «Canal API», «SMS»). Cada bandeja tiene los botones «Ajustes» y «Eliminar».

## Cómo se hace
### Agregar otro canal (una bandeja nueva)
1. Entra a Ajustes › Bandejas de Entrada y pulsa «Añadir Bandeja de Entrada».
2. Elige el canal: Website (chat del sitio web), Messenger, Instagram, WhatsApp, SMS, Email, API, Telegram, Line o TikTok. Los que tu cuenta no tiene activados salen apagados y no hacen nada al pulsarlos; para activarlos hay que pedirlo a soporte de la plataforma.
3. Llena los datos que pide el canal:
   - WhatsApp: en «Proveedor de la API» elige «WhatsApp Cloud», «Twilio» o «Unoapi» (y, si está disponible, «Conexión con Facebook (Embedded Signup)»). En WhatsApp Cloud se piden «Nombre de la bandeja», «Número de teléfono» (con + y lada), «ID del número de teléfono», «ID de la cuenta de negocio» y «API Key».
   - Email: elige «Microsoft», «Google» u «Otros proveedores».
   - Website: «Nombre del sitio web», «Dominio del sitio web», color y mensajes de bienvenida.
   - API: «Nombre del canal» y «URL del webhook». Sirve para conectar un canal que no está en la lista.
   - Telegram: el «Token del bot». SMS: Twilio o Bandwidth.
4. En «Agentes» elige quién atiende la bandeja (al menos uno) y pulsa «Agregar agentes». Solo ellos ven y contestan sus conversaciones.
5. Sale «¡Tu bandeja está lista!». En el chat del sitio web copia el código que se muestra y pégalo en tu página; en WhatsApp Cloud copia la «URL del webhook» y el «Token de verificación del webhook» para ponerlos en Meta. Luego «Más ajustes» o «Ir a la bandeja».

### Cambiar los ajustes de una bandeja
En Ajustes › Bandejas de Entrada pulsa «Ajustes» de la bandeja. Tiene estas pestañas (algunas solo en ciertos canales):
- «Ajustes»: imagen y «Nombre de la bandeja», el saludo del canal («Activar el saludo del canal»), la «Activar encuesta de satisfacción (CSAT)» y, en el chat del sitio web, colores, bienvenida y «Tiempo de respuesta». Guarda con «Guardar».
- «Agentes»: quién atiende, «Activar la asignación automática» (reparte solas las conversaciones nuevas) y «Permitir que el agente borre mensajes».
- «Horario de atención»: «Activar el horario de atención en esta bandeja», el «Mensaje para visitantes fuera de horario», la zona horaria y el horario de la semana. Guarda con «Guardar el horario de atención».
- «Formulario previo al chat» y «Diseño del widget»: solo en el chat del sitio web.
- «Configuración»: los datos técnicos del canal (por ejemplo, en WhatsApp, el «Token de verificación del webhook» y «Cambiar API Key»).
Si un administrador también quiere ver todas las bandejas, debe agregarse a cada una.

### Eliminar una bandeja
1. Pulsa «Eliminar» en la bandeja.
2. Escribe el nombre de la bandeja para confirmar y pulsa «Sí, eliminar …».

### Crear un equipo
1. Entra a Ajustes › Equipos y pulsa «Crear nuevo equipo».
2. Escribe «Nombre del equipo» (mínimo 2 letras) y «Descripción del equipo». «Permitir asignación automática para este equipo.» viene marcada: las conversaciones se reparten solas.
3. Pulsa «Crear equipo».
4. Marca a los usuarios (al menos uno) y pulsa «Añadir usuarios». Luego «Finalizar».
Para cambiarlo después usa «Editar equipo» (detalles y usuarios). Para borrarlo pulsa «Eliminar» y escribe su nombre para confirmar.

### Activar una integración
1. Entra a Ajustes › Integraciones.
2. Busca la tarjeta y pulsa «Configurar». Cada tarjeta dice si está «Activada» o «Desactivada».
3. Llena los datos que pide y guarda. Según la integración verás «Conectar» / «Desconectar» o «Agregar nueva conexión» (por bandeja).

### Avisar a otro sistema con un webhook
1. Entra a Ajustes › Integraciones › Webhook › «Configurar».
2. Pulsa «Agregar nuevo webhook».
3. Escribe la «URL del Webhook» y marca los «Eventos»: «Conversación Creada», «Estado de la Conversación Cambiado», «Conversación Actualizada», «Conversación Resuelta», «Mensaje creado», «Mensaje actualizado», «Widget de chat en vivo abierto por el usuario», «Contacto creado», «Contacto actualizado».
4. Pulsa «Crear webhook». Cada vez que pase uno de esos eventos, la plataforma le avisa a esa dirección.

### Conectar el CRM administrativo
1. Entra a Ajustes › Integraciones y pulsa «Configurar» en «Kontrolya CRM Administrativo» (sincroniza los contactos).
2. Llena «Direccion Url Kontrolya» (la dirección de tu CRM) y «Access Token Kontrolya». La «Webhook URL» viene llena.
3. Guarda. Se prueba la conexión; si falla, revisa la dirección y el token. Para quitarla usa «Desconectar».

## Integraciones de la lista
Activación Bot EVA, Activación agente seguimiento, Activación agente vendedor transaccional, Kontrolya CRM Administrativo (sincroniza contactos), Discourse (usa tu foro como base de conocimiento), Webhook (avisa a otro sistema cuando pasa algo), OpenAI (sugerencias de respuesta, resúmenes y reformular mensajes), Panel de aplicaciones (agrega pantallas de otro sistema con «Nombre» y «Punto final»), Dialogflow y Traductor de Google. Slack, Linear y Capitán solo salen si el servidor los tiene configurados.

## Límites
- No hay tarjeta de integración para CONTPAQi ni para un ERP. CONTPAQi solo existe como fuente de la Base de Conocimiento (ver guía base_conocimiento).
- Para otro CRM o sistema que no está en la lista: usa un Webhook (la plataforma le avisa), el canal API, o la API de la plataforma con el «Token de Acceso» de tu perfil y el «ID de la cuenta» de Ajustes › Configuración de Cuenta.
- Los canales apagados al agregar bandeja no los activa el Administrador de la cuenta: se piden a soporte.

## Dudas frecuentes
- ¿Cómo agrego otro canal? Ajustes › Bandejas de Entrada › «Añadir Bandeja de Entrada» y elige el canal (ver «Agregar otro canal»).
- ¿Cómo lo integro con un CRM administrativo? Con la tarjeta «Kontrolya CRM Administrativo» en Ajustes › Integraciones; para otro CRM, con un Webhook o la API.
- ¿Puedo ordenar las bandejas en el menú? Sí, con «Ordenar en el menú» en Ajustes › Bandejas de Entrada («Subir», «Bajar», «Restablecer», «Guardar»). Solo cambia tu menú, no el de los demás.
- Un usuario no ve las conversaciones de un canal: no está agregado a esa bandeja, o su rol solo le deja ver lo suyo.
- ¿Borrar un equipo borra conversaciones? No; solo les quita la asignación a ese equipo.
- Las plantillas de WhatsApp se dan de alta en Catálogos › Plantillas de WhatsApp (guía respuestas_plantillas).

## Quién puede
Solo el Administrador agrega y cambia bandejas, equipos e integraciones.
