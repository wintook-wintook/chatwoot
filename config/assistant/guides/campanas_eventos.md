---
key: campanas_eventos
title: Campañas y eventos
areas: [campaigns]
keywords: [ficha de campana, ligas de campana, palabra clave, registrado, no invitar, volver a invitar, casos de prueba, probar campana, simular campana, prueba real, contactos de prueba, lista de correos, lista fria, subir lista, csv, cuarentena, prospectos de lista, lista de exclusion, campana con vendedor ia, motor 2.0, vendedor de campana, campana 2.0, embudo de campana, resumen con ia, prueba a/b, asunto, clics, plantilla por toque, siguiente campana, no leyeron, campana, campanas, campana de agente ia, nueva campana, agregar campana, poner en curso, pausar campana, asignar agente ia, asignacion masiva, segmento, etiqueta, evento, eventos, invitados, confirmo, asistio, check-in, importar csv, pagina web, sms, dashboard de campanas, prospectos, entregar, nfc, etiqueta nfc, acercar el celular, expo, feria, stand, gafete, captar, wa.me, vender un servicio, vender un producto, promocion, promover, campana de sms, campana sms, campana unica, campana continua, campana de pagina web, sitio web, widget, chat del sitio, mensaje proactivo, hora programada, audiencia, campana whatsapp, whatsapp masivo, envio masivo, curso, demostracion, webinar, cupo, cerrar evento, reabrir evento, no asistio, cancelo, quitar del evento, eliminar evento]
pages: [campaigns, events, campaigns_sms, campaigns_web, contacts, trackings, inboxes, labels]
sources: [app/javascript/dashboard/views/campaigns2/*.vue, app/controllers/api/v1/accounts/motor2_campaigns_controller.rb, app/services/tracking_campaigns/motor2_*.rb, app/services/tracking_campaigns/event_reminder*.rb, app/services/tracking_campaigns/offer_*.rb, app/services/tracking_campaigns/survey_*.rb, app/services/tracking_campaigns/renew_enroll.rb, app/services/contacts/campaign_audience_filters.rb, app/javascript/dashboard/views/events/*.vue, app/javascript/dashboard/views/events/eventHelpers.js, app/javascript/dashboard/i18n/locale/es/events.json, app/controllers/api/v1/accounts/events_controller.rb, app/controllers/api/v1/accounts/event_capture_links_controller.rb, app/models/event*.rb, app/javascript/dashboard/routes/dashboard/settings/campaigns/*.vue, app/javascript/dashboard/i18n/locale/es/campaign.json, app/models/campaign.rb, app/policies/campaign_policy.rb, app/services/sms/oneoff_sms_campaign_service.rb]
reviewed: 2026-11-25
---
## Para qué sirve
- Una campaña de agente IA pone a un Agente IA a escribirle a un grupo de contactos y sigue cómo responde cada uno.
- Eventos lleva la lista de una feria, curso o demostración: quién está invitado, quién confirmó y quién asistió, para hacerles campañas después.
- Una campaña de SMS manda un mismo mensaje por SMS, a una hora, a los contactos que tienen ciertas etiquetas.
- Una campaña de Página web le muestra un mensaje en el chat de tu sitio a quien visita una página.

## Dónde está
En el menú Campañas, en este orden:
- Campañas › De agentes IA: la lista de campañas con su avance.
- Campañas › Página web (título «Campañas Webpage»): mensajes en el chat del sitio web.
- Campañas › SMS (título «Campañas SMS»): mensajes por SMS.
- Campañas › Dashboard (es el mismo que Informes › Dashboard de campañas): cifras de todos los seguimientos.
- Campañas › Eventos: la lista de eventos; al pulsar uno se abre su página.
- En la ficha del contacto, la pestaña «Eventos» muestra en cuáles está.

## Cómo se hace
«Agregar campaña» crea una campaña con Vendedor IA (Motor 2.0): primero eliges el tipo.

### Crear una campaña con Vendedor IA (Motor 2.0)
La campaña trae todo: qué busca, lo que sabe la IA, qué se manda, a quién, cuándo y cómo contesta. Ocho pasos como pestañas, en el orden de la plática (Invitar tiene sus propios 5 pasos, abajo); a la derecha ves cómo le llega el mensaje y «Probar», donde tú eres el contacto.
Al pulsar «Agregar campaña» eliges el tipo (Ofrecer, Invitar, Reactivar, Recordar o renovar, Encuesta) y entras directo; ya no se cambia (para otro tipo, crea otra campaña).
1. Objetivo: «¿Qué cuenta como logrado?» según el tipo: confirma que va; se registra o compra por su cuenta y avisa con una palabra clave (por ejemplo REGISTRADO; «me interesa» no cuenta); confirma que ya pagó o renovó; le interesa y pasa a quien sigue; agenda una cita. También el nombre corto (llena {{oferta}}), el evento en Invitar y el canal (bandeja de WhatsApp o de correo).
2. La ficha: lo ÚNICO que sabe la IA; si le preguntan algo que no está ni en sus fuentes, dice que no tiene el dato. Los datos del tipo (Invitar: cuándo, dónde, costo, para quién es y para quién no, qué se verá; Ofrecer: qué es, precio, vigencia, condiciones; Reactivar: qué hay de nuevo e incentivo; Recordar: qué le toca, cómo hacerlo, dónde pagar), «Preguntas y objeciones autorizadas», «Ligas» (cada una con cuándo se manda: con la información, solo si la pide o solo si tiene un problema, como «no me llegó el correo») e «Imágenes y archivos» (hasta 10). En Encuesta, hasta 3 preguntas y desde qué calificación es baja.
3. Audiencia: un segmento, una etiqueta, los asistentes de un evento o «Los que agreguen mis automatizaciones». Ves cuántos le llegan y quiénes quedan fuera y por qué (también los que tienen la etiqueta «no…» de ese tipo de campaña).
   - «Subir una lista de correos» (solo correo: en WhatsApp bloquean tu número): CSV con correo/email (obligatorio), nombre, empresa y teléfono, hasta 5,000 renglones. Se quitan mal escritos, repetidos, de rol (info@…), dados de baja y rebotados. Los nuevos quedan en cuarentena (no salen en Contactos hasta que contestan o dan clic) y se borran solos si nunca contestan; la revisión pide un máximo por día (empieza con 50 a 100).
4. Mensajes, lo que se MANDA: cuántos toques y cada cuánto. En WhatsApp: la apertura (la plantilla de cada toque y de dónde sale cada variable, también lo último que compró, su fecha y su monto; o el texto si escribió en 24 h) y la «Información completa» que sale tal cual y una sola vez cuando le interesa, con sus imágenes («Insertar liga…» pone una liga de la ficha). En correo: el asunto (y un asunto B), cada correo por bloques (vacío: lo escribe la IA; el primero lleva todo) y, del segundo en adelante, el texto para quien ya dio clic. En Encuesta por correo, la primera pregunta va con botones del 0 al 10.
5. Respuestas y resultados: lo que contesta tal cual al lograrlo, en «no esta vez» (pregunta una vez si le escribimos la próxima), si acepta y si pide que no le escriban, y la etiqueta que le queda al contacto (por ejemplo registrado, volver-a-invitar, no-invitar). Quien tiene la etiqueta «no…» ya no entra a las siguientes campañas de ese tipo; «baja», «stop» o «darme de baja» lo da de baja de todo.
6. Cómo atiende: el nombre, la voz, tu empresa, sus fuentes y precios, cómo cotiza y con quién agenda, el seguimiento, la firma de correo, tus indicaciones y a quién pasa al interesado. Viene con lo de tu última campaña.
7. Cuándo: en cuanto la lances o en una fecha, fin opcional, horario de atención, máximo por día y «No escribirle si otra campaña le escribió hace menos de N días».
   - En cada toque: horario de la bandeja (sin horario, de 9 a 19 h entre semana), el máximo por día cuenta todos los toques, un mensaje de campañas al día por contacto, nada a quien se dio de baja o ya atiende una persona. Si contesta, ya no salen los toques que faltaban.
8. Revisar y lanzar: el resumen y la lista en verde, amarillo o rojo (cómo atiende, OpenAI, ficha, palabra clave, ligas, audiencia, canal, plantillas, asunto, relevo, fechas, plantillas que cobra Meta). Con algo en rojo no deja lanzar. «Guardar borrador» la deja Guardada.

### Campaña para invitar a un evento (Invitar)
Invitar va en 5 pasos:
1. El evento: lo eliges y se ven su fecha, lugar, liga y cupo (la IA ya los sabe). «+ Crear evento» y «Editar evento» abren el formulario ahí mismo, sin salir de la campaña. «¿Cómo confirma?»: «Aquí en la plática» o «Se registra por su cuenta»; en el segundo van juntas la liga de registro y la palabra clave. Abajo: costo, para quién es, preguntas, ligas y archivos.
2. Invitados: el canal y a quién. En «Asistentes de un evento» puedes elegir OTRO evento (la expo pasada) sin cambiar al que invitas.
3. Mensajes: invitación, información completa, toques a quien no contesta y «Recordatorios del evento»: un día antes (a los que confirmaron y, con un texto de última invitación, a los que no han contestado) y una hora antes (solo confirmados, con la liga); nunca a quien dijo que no. En WhatsApp, pasadas 24 h solo salen con plantilla (Meta la cobra).
4. Cuando contesta: respuestas y etiquetas listas («Personalizar»), a quién pasa si pide una persona y «Opciones avanzadas».
5. Revisar y lanzar: nombre, cuándo empieza (termina sola al empezar el evento), opciones avanzadas y las pruebas (los «Casos» corren solos; «Chatear» y «Más pruebas»).

### Campaña para ofrecer un producto o promoción (Ofrecer)
Ofrecer va en 6 pasos:
1. La oferta: busca en tu Catálogo; cada producto llega con su nombre, precio, descripción y foto (la foto se agrega sola como imagen de la oferta). Pon el precio de promoción o el % de descuento y la vigencia (fecha): ese día la campaña termina sola y después la IA dice que la promoción ya terminó. Abajo, condiciones, para quién es, preguntas, ligas y archivos. Si no está en el Catálogo, escribe qué es y su precio.
2. Cuando le interesa: una opción y su configuración: «Lo paso a alguien» (agente de la bandeja o persona, y en cuánto tiempo le deben escribir), «Le armo la cotización» (borrador o se la manda, con el precio de promoción mientras dure), «Le agendo una cita» (en el calendario de quién) o «Compra en línea» (liga de compra y palabra clave juntas).
3. A quién: el canal y la audiencia.
4. Mensajes: apertura, «Armar la información completa con la oferta», toques a quien no contesta y «Si contestó y luego se calla».
5. Cuando contesta y 6. Revisar y lanzar: como en Invitar. Los Casos incluyen «Pide cotización» (con el precio de promoción) y «La promoción ya venció».

### Reactivar, Recordar y Encuesta
- Reactivar (6 pasos): primero «A quién reactivas»: «No compran desde hace…» N días (su última cotización ganada o contrato; quien tiene contrato activo no entra) y, si quieres, de una categoría; la muestra dice lo último que compró cada uno. Luego «Qué les ofreces» (productos con precio de promoción y vigencia, como Ofrecer), «Cuando le interesa», Mensajes ({{ultima_compra}}), respuestas y lanzar.
- Recordar (5 pasos): «Qué recuerdas»: de qué contratos (o todos) y en qué días antes de vencer se le escribe (hasta 4; de fábrica 7, 1 y el día). Cada contacto recibe los suyos según la fecha de SU contrato; la campaña queda prendida y cada mañana entran los que ya les toca. «Cómo se paga»: «Dice que ya pagó» (queda una tarea al responsable del contrato para verificarlo), «Lo paso a alguien» o «Paga en línea» (liga de pago y palabra clave). Los saldos de facturas los cobra el Agente de Cobranza.
- Encuesta (6 pasos): «Las preguntas»: hasta 5, cada una con su tipo (0–10, 1–5, sí o no, abierta) y desde cuánto es baja. «Si califica bajo»: a quién le llega el caso, tipo, prioridad y qué se le contesta. «A quién»: de entrada «Atendidos hace poco» (caso resuelto o cotización ganada en los últimos N días). En Resultados: NPS de la pregunta de 0 a 10 y los comentarios.

### Probar la campaña antes de lanzarla
En «Revisar y lanzar», a la derecha:
- «Casos»: pruebas que se arman solas con tu campaña («sí, me interesa», una duda concreta, la palabra clave, «ahorita lo hago», «no puedo esta vez», «no me manden nada», algo de otro tema, «gracias», «no me llegó el correo», pedir la liga otra vez…). «Correr todos» dice cuáles salen bien, qué contestó y qué hizo.
- «Simular la campaña»: con un contacto (o «Simular conmigo») ves cada toque personalizado, cuándo sale y qué pasa según conteste (y con qué etiqueta). No manda nada.
- «Chatear»: tú eres el contacto.
- «Prueba real»: la manda de verdad a hasta 5 correos o WhatsApp de prueba, un toque cada pocos minutos. No cuenta en los resultados; «Terminar prueba» la cancela.

### Resultados de una campaña con Vendedor IA
- Embudo: inscritos, enviados, entregados, leídos o dieron clic, contestaron, les interesó, relevo, cita, cotizaciones y ganadas. Clic en un cuadro para ver esos contactos.
- El objetivo: lo lograron, no esta vez, aceptan la próxima y no quieren que les escribamos, con su etiqueta.
- Por toque, salidas (con los omitidos y su motivo), ventas, y por tipo (confirmaron en Invitar; promedio y bajas en Encuesta).
- «Resumir con IA» y «Siguiente campaña con…» (los que no leyeron, no contestaron, dieron clic, les interesó o dijeron que no).
- Arriba: Modificar (si está Guardada), Pausar o Reanudar, Duplicar y Actualizar. En la lista se filtran con «Con Vendedor IA» / «Clásicas».

### Campañas clásicas (Motor 1.0)
Ya no se crean campañas nuevas con el Motor 1.0: «Agregar campaña» siempre es con Vendedor IA (Motor 2.0). Las clásicas que ya existen siguen en la lista (filtro «Clásicas (Motor 1.0)»), con sus resultados, y se pueden pausar, reanudar o terminar como siempre.

### Desde la lista de contactos
1. En Clientes › Contactos aplica un filtro o abre una etiqueta.
2. Pulsa «Asignar Agente IA»: se abre la campaña nueva con esos contactos como audiencia.

### Ver resultados
1. Abre la campaña en la lista.
2. Arriba ves «Control (ejecución)», «Entrega de Mensajes» y el «Embudo» (contactados, respondieron, interesados, con cita…).
3. En la pestaña «Prospectos» ves a cada contacto con su estado; «Entregar» pasa un interesado a un vendedor. En «Inscritos» ves quién entró y por dónde.

### Crear una campaña de SMS
1. Entra a Campañas › SMS y pulsa «Crear una campaña única».
2. Escribe el «Título» y el «Mensaje» (texto simple). Los dos son obligatorios.
3. En «Seleccionar Bandeja de Entrada» elige la bandeja de SMS que envía.
4. En «Audiencia» elige una o varias etiquetas: el mensaje les llega a todos los contactos con cualquiera de esas etiquetas que tengan teléfono.
5. En «Hora programada» elige cuándo sale. Si la dejas vacía, sale en cuanto se crea.
6. Pulsa «Crear». Se manda una sola vez; después queda como «Completado» (antes, «Activo»).
7. Una campaña de SMS no se puede editar: solo «Eliminar» («Sí, Eliminar» para confirmar).

### Crear una campaña de Página web
1. Entra a Campañas › Página web y pulsa «Crear una campaña continua».
2. Escribe el «Título» y el «Mensaje» (con formato).
3. En «Seleccionar Bandeja de Entrada» elige la bandeja de sitio web (la del chat de tu página).
4. En «Enviado por» elige quién firma el mensaje: «Bot» o una persona de esa bandeja.
5. En «URL» pon la dirección de la página donde debe salir; tiene que empezar con http:// o https://.
6. En «Tiempo en la página (Segundos)» pon cuántos segundos espera antes de mostrarlo (viene en 10).
7. Marca «Habilitar campaña» (viene marcada) y, si quieres, «Activar solo durante el horario laboral».
8. Pulsa «Crear». Mientras esté «Habilitado», a cada visitante de esa página le aparece el mensaje en el chat; si contesta, se abre una conversación.
9. Para cambiarla pulsa «Editar» (ahí también la apagas desmarcando «Habilitar campaña») o «Eliminar».

### Crear un evento
1. Entra a Campañas › Eventos y pulsa «Nuevo evento».
2. Escribe el «Nombre» y elige el «Tipo» (Feria, Curso, Demostración, Webinar u Otro) y el «Estado» (Borrador, Abierto o Cerrado; viene en Abierto).
3. «Inicia» (obligatorio) y, si quieres, «Termina», «Lugar», «Enlace (si es en línea)», «Cupo», «Responsable» y «Descripción».
4. Pulsa «Guardar».
5. En la lista ves cada evento con su fecha, cuántos están como Invitado, Confirmó y Asistió, y su estado. Puedes buscar con «Buscar por nombre o lugar» y filtrar con «Todos los estados».

### Llevar la lista del evento
1. Abre el evento. Las pestañas «Todos», «Invitado», «Confirmó», «Asistió», «No asistió» y «Canceló» filtran la lista; «Buscar contacto» busca en ella.
2. En «Agregar como» eliges el estado y agregas con «Agregar contacto» o con «Agregar un segmento» (elige el segmento y pulsa «Agregar»). Si alguien ya estaba, no se duplica ni cambia su estado.
3. También puedes bajar la «Plantilla CSV» y usar «Importar»: columnas contacto (correo o teléfono) y estado (invitado, confirmó, asistió, no asistió, canceló). Si ya está, se le cambia el estado; las filas con error se reportan con su renglón.
4. El día del evento pulsa «Asistió» en cada contacto, o cambia su estado en la lista. La «x» («Quitar del evento») lo saca de la lista.
5. Al terminar, «Cerrar evento»: los que confirmaron y no llegaron quedan como «No asistió». Con el evento cerrado ya no se agregan contactos; «Reabrir» lo vuelve a abrir.
6. Arriba también están «Editar» y el bote («Eliminar evento»): se borra el evento y su lista, los contactos no se borran.
7. Abajo, «Campañas de este evento» muestra las campañas que lo usan.

### Captar en la expo «acercando el celular» (NFC)
1. Abre el evento y baja a «Acercar el celular (NFC)»; pulsa «Nuevo enlace».
2. Elige el WhatsApp que recibe, el vendedor (opcional: los prospectos de ese enlace se le asignan a él) y el mensaje que el cliente va a enviar. Se le agrega solo un código «Ref …» para reconocerlo. Pulsa «Crear enlace».
3. Graba el enlace en una etiqueta NFC (sticker o tarjeta NTAG213/215): en Chrome de Android pulsa «Grabar en etiqueta» y acerca la etiqueta a la parte de atrás del teléfono; en iPhone usa «Copiar enlace» y grábalo con una app como NFC Tools.
4. Pégala en el mostrador («Acerca tu celular») o en el gafete de cada vendedor (un enlace por vendedor).
5. El cliente acerca su celular, se le abre WhatsApp con el mensaje listo y lo envía. Queda en el evento como «Asistió», su conversación con la etiqueta del evento (evento-…) y, si el enlace es de un vendedor y nadie la atiende, asignada a él. Como él escribió primero, le puedes contestar libremente.
6. Desde el teléfono también se lo puedes pedir a Dali: «quiero grabar la etiqueta NFC de la Expo Industrial para Ana». Dali arma la tarjeta (evento, WhatsApp, vendedor y mensaje); al confirmar, toca «Grabar en etiqueta» y acerca la etiqueta (en iPhone, «Copiar enlace»). «¿Cuántos captamos en la expo?» también lo contesta.
7. En cada enlace ves cuántos se captaron. «Probar» abre el enlace para revisarlo; «Borrar» lo quita (las etiquetas que ya lo tengan dejan de ligar al evento).

## Dudas frecuentes
- ¿Cuándo empieza a enviar? Al pulsar «Guardar y poner en curso» o, si solo la guardaste, «Poner en curso» en la lista. Una campaña «Guardada» se puede cambiar con «Modificar»; ya en curso, no.
- ¿Puedo detenerla? Sí, «Pausar campaña» y luego «Reanudar campaña». El agente sigue contestando a quien ya respondió.
- ¿Cuántos contactos caben? Una campaña por segmento, etiqueta o filtro admite hasta 1,000 contactos; si te pasas, ajusta el filtro o excluye contactos.
- ¿Una campaña puede tomar a los que asistieron? Sí: en «¿Es de un evento?» elige el evento y «Asistió». Si es continua, entra cada contacto en cuanto lo marcan.
- Página web y SMS necesitan una bandeja de sitio web o de SMS ya creada; si no hay, la pantalla lo avisa («Por favor cree una bandeja de entrada de SMS…»). Las bandejas se crean en Ajustes › Bandejas de entrada.
- Quiero hacer una campaña para vender un servicio, ¿qué opciones hay? Depende de cómo quieras llegar al cliente:
  - Por SMS, a contactos que ya tienes: etiquétalos (por ejemplo «interesados-poliza») y crea una campaña en Campañas › SMS con esa «Audiencia», el mensaje de tu servicio y la «Hora programada».
  - En tu sitio web, a quien lo visita: en Campañas › Página web crea una campaña con la «URL» de la página del servicio y un mensaje como «¿Te ayudo a cotizar?».
  - Con un evento (demostración, curso, webinar o feria): créalo en Campañas › Eventos, invita a tus contactos y marca quién confirmó y asistió; en una feria puedes captar con la etiqueta NFC.
  - Con un Agente IA que les escriba y dé seguimiento uno por uno: existen en Campañas › De agentes IA (ver arriba).
  Las campañas de SMS y de Página web no mandan por WhatsApp; para escribirle por WhatsApp a un grupo de contactos están las de Campañas › De agentes IA.
- ¿El asistente puede lanzar una campaña? No, eso se hace desde Campañas.
- No me sale «Nuevo enlace» en el NFC: hace falta una bandeja de WhatsApp con número («Necesitas una bandeja de WhatsApp con número para crear el enlace.») y poder cambiar en Campañas.
- ¿Qué teléfonos leen la etiqueta NFC? iPhone XS o más nuevo (la lee solo) y Android con NFC encendido. Si alguno no la lee, el mismo enlace sirve como QR.
- ¿Puedo pasar mi número al cliente acercando los celulares? No: los teléfonos no comparten contactos así con la plataforma. Por eso es al revés: el cliente te escribe y así quedan su número y su permiso.
- Solo cuenta el primer mensaje de la conversación: si el cliente ya te había escrito antes, no se vuelve a ligar.

## Quién puede
Depende del área Campañas del rol. El Administrador y los roles con Campañas en «Todo» crean campañas y eventos. Con «Ve todo (sin cambiar)» (el Supervisor, por omisión) solo se mira: en Eventos no salen «Nuevo evento», «Editar», «Importar», «Cerrar evento», «Agregar como» ni los botones de cada contacto. Vendedor, Técnico / Soporte y Consulta no entran por omisión. Página web y SMS son solo del Administrador (ver, crear, editar y eliminar). Al agregar contactos a un evento (por segmento o CSV) solo entran los contactos que tu rol puede ver en Clientes.
