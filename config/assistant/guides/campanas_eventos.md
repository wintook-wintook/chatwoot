---
key: campanas_eventos
title: Campañas y eventos
areas: [campaigns]
keywords: [campana, campanas, campana de agente ia, nueva campana, agregar campana, poner en curso, pausar campana, asignar agente ia, asignacion masiva, segmento, etiqueta, evento, eventos, invitados, confirmo, asistio, check-in, importar csv, pagina web, sms, dashboard de campanas, prospectos, entregar, nfc, etiqueta nfc, acercar el celular, expo, feria, stand, gafete, captar, wa.me]
pages: [campaigns, events, contacts, trackings]
---
## Para qué sirve
- Una campaña de agente IA pone a un Agente IA a escribirle a un grupo de contactos y sigue cómo responde cada uno.
- Eventos lleva la lista de una feria, curso o demostración: quién está invitado, quién confirmó y quién asistió, para hacerles campañas después.

## Dónde está
- Campañas › De agentes IA: la lista de campañas con su avance.
- Campañas › Página web y Campañas › SMS: mensajes en el chat del sitio web o por SMS.
- Campañas › Dashboard (es el mismo que Informes › Dashboard de campañas): cifras de todos los seguimientos.
- Campañas › Eventos.

## Cómo se hace
### Crear una campaña de agente IA
1. Entra a Campañas › De agentes IA y pulsa «Agregar campaña».
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

### Crear un evento y llevar su lista
1. Campañas › Eventos › «Nuevo evento»: nombre, tipo, inicia, termina, lugar, cupo y responsable. «Guardar».
2. Abre el evento. Con «Agregar como» eliges el estado y agregas con «Agregar contacto» o «Agregar un segmento».
3. También puedes bajar la «Plantilla CSV» y usar «Importar».
4. El día del evento pulsa «Asistió» en cada contacto, o cambia su estado en la lista.
5. Al terminar, «Cerrar evento»: los que confirmaron y no llegaron quedan como «No asistió».

### Captar en la expo «acercando el celular» (NFC)
1. Abre el evento y baja a «Acercar el celular (NFC)»; pulsa «Nuevo enlace».
2. Elige el WhatsApp que recibe, el vendedor (opcional: los prospectos de ese enlace se le asignan a él) y el mensaje que el cliente va a enviar. Se le agrega solo un código «Ref …» para reconocerlo. Pulsa «Crear enlace».
3. Graba el enlace en una etiqueta NFC (sticker o tarjeta NTAG213/215): en Chrome de Android pulsa «Grabar en etiqueta» y acerca la etiqueta a la parte de atrás del teléfono; en iPhone usa «Copiar enlace» y grábalo con una app como NFC Tools.
4. Pégala en el mostrador («Acerca tu celular») o en el gafete de cada vendedor (un enlace por vendedor).
5. El cliente acerca su celular, se le abre WhatsApp con el mensaje listo y lo envía. Queda en el evento como «Asistió», su conversación con la etiqueta del evento (evento-…) y, si el enlace es de un vendedor y nadie la atiende, asignada a él. Como él escribió primero, le puedes contestar libremente.
6. En cada enlace ves cuántos se captaron. «Probar» abre el enlace para revisarlo; «Borrar» lo quita (las etiquetas que ya lo tengan dejan de ligar al evento).

## Dudas frecuentes
- ¿Cuándo empieza a enviar? Al pulsar «Guardar y poner en curso» o, si solo la guardaste, «Poner en curso» en la lista. Una campaña «Guardada» se puede cambiar con «Modificar»; ya en curso, no.
- ¿Puedo detenerla? Sí, «Pausar campaña» y luego «Reanudar campaña». El agente sigue contestando a quien ya respondió.
- ¿Cuántos contactos caben? Una campaña por segmento, etiqueta o filtro admite hasta 1,000 contactos; si te pasas, ajusta el filtro o excluye contactos.
- ¿Una campaña puede tomar a los que asistieron? Sí: en «¿Es de un evento?» elige el evento y «Asistió». Si es continua, entra cada contacto en cuanto lo marcan.
- Página web y SMS necesitan una bandeja de sitio web o de SMS ya creada.
- ¿El asistente puede lanzar una campaña? No, eso se hace desde Campañas.

- ¿Qué teléfonos leen la etiqueta NFC? iPhone XS o más nuevo (la lee solo) y Android con NFC encendido. Si alguno no la lee, el mismo enlace sirve como QR.
- ¿Puedo pasar mi número al cliente acercando los celulares? No: los teléfonos no comparten contactos así con la plataforma. Por eso es al revés: el cliente te escribe y así quedan su número y su permiso.
- Solo cuenta el primer mensaje de la conversación: si el cliente ya te había escrito antes, no se vuelve a ligar.

## Quién puede
Depende del área Campañas del rol. El Administrador y los roles con Campañas en «Todo» crean campañas y eventos. Con «Ve todo (sin cambiar)» (el Supervisor, por omisión) solo se mira. Vendedor, Técnico / Soporte y Consulta no entran por omisión. Página web y SMS son solo del Administrador.
