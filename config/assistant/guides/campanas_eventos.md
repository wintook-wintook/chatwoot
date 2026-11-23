---
key: campanas_eventos
title: Campañas y eventos
areas: [campaigns]
keywords: [probar campana, simular campana, prueba real, contactos de prueba, lista de correos, lista fria, subir lista, csv, cuarentena, prospectos de lista, lista de exclusion, campana con vendedor ia, motor 2.0, vendedor de campana, campana 2.0, embudo de campana, resumen con ia, prueba a/b, asunto, clics, plantilla por toque, siguiente campana, no leyeron, campana, campanas, campana de agente ia, nueva campana, agregar campana, poner en curso, pausar campana, asignar agente ia, asignacion masiva, segmento, etiqueta, evento, eventos, invitados, confirmo, asistio, check-in, importar csv, pagina web, sms, dashboard de campanas, prospectos, entregar, nfc, etiqueta nfc, acercar el celular, expo, feria, stand, gafete, captar, wa.me, vender un servicio, vender un producto, promocion, promover, campana de sms, campana sms, campana unica, campana continua, campana de pagina web, sitio web, widget, chat del sitio, mensaje proactivo, hora programada, audiencia, campana whatsapp, whatsapp masivo, envio masivo, curso, demostracion, webinar, cupo, cerrar evento, reabrir evento, no asistio, cancelo, quitar del evento, eliminar evento]
pages: [campaigns, events, campaigns_sms, campaigns_web, contacts, trackings, inboxes, labels]
sources: [app/javascript/dashboard/views/campaigns2/*.vue, app/controllers/api/v1/accounts/motor2_campaigns_controller.rb, app/services/tracking_campaigns/motor2_*.rb, app/javascript/dashboard/views/events/*.vue, app/javascript/dashboard/views/events/eventHelpers.js, app/javascript/dashboard/i18n/locale/es/events.json, app/controllers/api/v1/accounts/events_controller.rb, app/controllers/api/v1/accounts/event_capture_links_controller.rb, app/models/event*.rb, app/javascript/dashboard/routes/dashboard/settings/campaigns/*.vue, app/javascript/dashboard/i18n/locale/es/campaign.json, app/models/campaign.rb, app/policies/campaign_policy.rb, app/services/sms/oneoff_sms_campaign_service.rb]
reviewed: 2026-11-23
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
Al pulsar «Agregar campaña» eliges cuál: «Campaña clásica (Motor 1.0)», la de siempre con un Agente a medida, o «Campaña con Vendedor IA (Motor 2.0)», marcada como Beta.

### Crear una campaña con Vendedor IA (Motor 2.0)
Necesitas un «Vendedor de campaña» (Agentes listos). Seis pasos como pestañas; a la derecha siempre ves cómo le llega el mensaje (el teléfono en WhatsApp o el correo) y «Probar», donde tú eres el contacto y el vendedor te contesta con la oferta de esta campaña.
1. Objetivo: Ofrecer, Invitar, Reactivar, Recordar o renovar o Encuesta, y qué sigue si le interesa (relevo o cita). El nombre es opcional: si lo dejas vacío se arma solo.
2. Oferta y vendedor: el Vendedor de campaña que atiende, el canal (solo bandejas de WhatsApp o de correo; va aquí para que el paso Audiencia ya cuente a quién le llega) y qué ofreces con sus detalles (precio, vigencia, condiciones); en Invitar, el evento; en Encuesta, hasta 3 preguntas y desde qué calificación es baja. «No escribirle si otra campaña le escribió hace menos de N días» evita saturar al contacto. «Si le interesa (o pide una persona), pasa a»: lo que diga el vendedor, el agente de la bandeja o una persona o equipo de esta campaña. «Objeciones de esta oferta»: lo que suelen contestar a esta oferta y la idea para responder (además de las generales del vendedor; si se repite, gana la de la campaña). «Imágenes y archivos de esta oferta» (hasta 10): la foto de la promoción o el flyer del evento, con qué es y cuándo va (en el toque N, cuando muestre interés, cuando lo pida o al confirmar); los generales siguen en el vendedor.
3. Audiencia: un segmento, una etiqueta, los asistentes de un evento (con su estado) o «Los que agreguen mis automatizaciones». Ves cuántos le llegan, cuántos ya están en conversación con un agente, cuántos no tienen teléfono o correo y puedes quitar contactos.
   - «Subir una lista de correos» (solo correo; en WhatsApp no se ofrece porque escribirle a quien no te conoce hace que bloqueen y reporten tu número): CSV con encabezados correo/email (obligatorio), nombre, empresa y teléfono, hasta 5,000 renglones. Antes de crear nada se quitan los que no tienen correo o está mal escrito, los repetidos, los de rol (info@, ventas@…), los que antes se dieron de baja o rebotaron y los de dominios que no reciben correo. Si el correo ya es de un contacto tuyo, se usa ese. Los nuevos quedan en cuarentena: no salen en Contactos hasta que contestan o dan clic (entonces pasan a contacto normal); los que nunca contestan se borran solos a los días que elijas (30 por omisión) después de que termina la campaña, y los que se dieron de baja o rebotaron quedan en una lista de exclusión para no volver a cargarlos. Con lista, la revisión pide un máximo por día (empieza con 50 a 100) y recomienda una bandeja o dominio aparte. En el tablero se ve cuántos venían, cuántos se descartaron y por qué, cuántos ya son contactos y cuántos siguen en cuarentena.
4. Mensajes: cuántos toques y cada cuánto. En WhatsApp eliges la plantilla aprobada de cada toque. En correo: el asunto (con {{contacto}} y {{empresa}}), un asunto B opcional para la prueba A/B, y cada correo por bloques (título, texto, botón, imagen); un correo sin bloques lo escribe el vendedor con IA. «Enviarme una prueba» te lo manda a tu correo. Las ligas cuentan clics y al final va la liga para darse de baja.
5. Cuándo: en cuanto la lances o en una fecha (futura), fin opcional (después del inicio), solo en horario de atención y máximo de mensajes por día.
   - Reglas en cada toque, no solo el primero: horario de la bandeja (sin horario, de 9 a 19 h de lunes a viernes, en la zona de la bandeja); el máximo por día cuenta todos los toques; nunca más de un mensaje de campañas al día por contacto (si otra campaña le escribió, espera 24 h); a quien se dio de baja o ya atiende una persona no le sale nada; al llegar la fecha de fin, los toques que falten ya no salen. Si contesta, ya no salen los toques que faltaban: le responde el vendedor.
6. Revisar y lanzar: un resumen (inicio, fin, ritmo, máximo por día, horario) y una lista en verde, amarillo o rojo (vendedor, OpenAI activo, oferta, calendarios si la meta es cita, audiencia, canal, plantilla de cada toque y las del vendedor, asunto, a quién pasa el relevo y si la bandeja tiene agente, fechas, si alcanzan los días con ese máximo, cuántas plantillas cobra Meta). Con algo en rojo no deja lanzar. «Guardar borrador» la deja Guardada.

### Probar la campaña antes de lanzarla
En «Revisar y lanzar», a la derecha, hay tres pestañas:
- «Simular la campaña»: escoge un contacto (o «Simular conmigo») y ves cada toque con su texto ya personalizado y cuándo sale (al lanzar, y si no contesta, N días u horas después), qué toques escribe el vendedor con IA y qué pasa según conteste: le interesa (a qué agente o persona pasa, o con quién agenda la cita), no le interesa (sale de la campaña), pide una persona o nunca contesta. Avisa si el contacto no tiene el dato del canal o si un toque de WhatsApp no tiene plantilla (solo saldría dentro de las 24 horas). «Contesta aquí» en un toque abre el chat con el vendedor desde ese mensaje y bajo cada decisión dice qué pasaría. No manda nada.
- «Chatear con el vendedor»: tú eres el contacto y el vendedor te contesta con la oferta de esta campaña.
- «Prueba real»: manda la campaña de verdad solo a hasta 5 correos o WhatsApp de prueba (tú o tu equipo), con un toque cada pocos minutos (3 por omisión) y las esperas del vendedor acortadas (cada hora es un minuto). Llegan los mensajes y se crean la conversación, el relevo, la cita y las notas como con un cliente. Ves en vivo qué salió, qué contestaste, en qué toque va y «Abrir conversación». No aparece en la lista de campañas ni cuenta en los resultados; «Terminar prueba» cancela lo que falte y una prueba nueva termina la anterior. En WhatsApp el primer toque necesita plantilla aprobada.

### Resultados de una campaña con Vendedor IA
- Embudo: inscritos, enviados, entregados, leídos (WhatsApp) o dieron clic (correo), contestaron, les interesó, pasaron al relevo, con cita, cotizaciones y ganadas, con el % sobre lo enviado. Clic en un cuadro para ver esos contactos (y abrir su conversación).
- Ventas de la campaña: lo cotizado y lo ganado de sus contactos desde que empezó.
- Por toque: a cuántos les salió cada toque y cuántos contestaron después de ese (para cambiar o quitar el que no funciona).
- Salidas: no les interesó, no contestaron (ya sin toques), aún con toques por salir, pidieron una persona, se dieron de baja, rebotó el correo, falló el envío y los omitidos con su motivo. Las cotizaciones y ventas cuentan solo de los que contestaron, hasta 30 días después del fin. En curso, el tablero se actualiza solo cada minuto.
- Por tipo: en Invitar, confirmaron contra el cupo y los que no van; en Encuesta, cuántos contestaron, el promedio y las calificaciones bajas con sus casos.
- «Qué dicen los contactos»: «Resumir con IA» arma de 3 a 5 puntos (qué preguntan, objeciones, qué mejorar) y abajo salen los motivos de «no le interesa».
- «Siguiente campaña con…»: arma otra campaña Guardada con los que no leyeron, no contestaron, dieron clic, les interesó o dijeron que no.
- Arriba: Modificar (si está Guardada), Pausar o Reanudar, Duplicar y Actualizar. En la lista de campañas llevan la etiqueta «Vendedor IA» y se filtran con «Con Vendedor IA» / «Clásicas»; Lanzar, Editar y Duplicar de una con Vendedor IA abren su asistente.

### Crear una campaña clásica (Motor 1.0)
1. Entra a Campañas › De agentes IA, pulsa «Agregar campaña» y elige «Campaña clásica (Motor 1.0)».
2. En «1 · ¿Qué?» escribe el «Nombre de la campaña» y elige el «Agente IA». El canal y las plantillas de WhatsApp de cada intento vienen del agente.
3. En «2 · ¿A quién?» elige «Un segmento», «Una etiqueta» o «Los que agreguen mis automatizaciones» (campaña continua).
4. Si es de un evento, en «¿Es de un evento? (opcional)» elige el evento y el estado (por ejemplo, «Asistió»).
5. En «3 · ¿Cuándo?» pon «Desde» y, si quieres, «Hasta». En «Opciones de envío» van la espera, el tope por día y el horario.
6. Revisa la audiencia abajo: «Listos para enviar», «Ya en seguimiento», «No contactables» y «Excluidos». Puedes excluir contactos.
7. Pulsa «Guardar» (no envía nada) o «Guardar y poner en curso».

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
