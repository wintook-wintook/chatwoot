---
key: seguimiento_ia
title: Delegar seguimiento (Seguimiento IA)
areas: [conversations, sales, service, clients]
keywords: [seguimiento, contacto sin conversacion, crear conversacion, bandeja, seguimiento ia, delegar, delegar seguimiento, insistir, intentos, pausar seguimiento, reanudar seguimiento, cancelar seguimiento, objetivo, que el agente le escriba, ventana 24 horas, plantilla whatsapp, nota ia, respuestas predefinidas, vista anterior, pide una persona, sin respuesta, dale seguimiento]
pages: [conversation, case, contact, trackings, canned_responses]
---
## Para qué sirve
Seguimiento IA es un agente que le escribe al cliente por ti hasta lograr un objetivo concreto, por ejemplo «que confirme la cotización 1520 o saber por qué no». Insiste las veces que le digas, contesta las dudas del cliente y te avisa cómo terminó.

## Dónde está
El botón «Delegar seguimiento» está en tres lugares:
- En la conversación, en el panel del contacto de la derecha.
- En el caso, en la pestaña Conversación (junto a «Programar mensaje»). Si el caso no tiene conversación, primero te pide ligar una.
- En la ficha del contacto. Ahí eliges en cuál de sus conversaciones trabaja el agente. Si todavía no tiene ninguna, eliges la bandeja (WhatsApp, SMS o correo) y al pulsar «Delegar» se abre la conversación ahí, asignada a ti.
El botón se pone verde cuando hay un seguimiento trabajando. Para usarlo, la empresa debe tener activa la integración de OpenAI en Ajustes › Integraciones.

## Cómo se hace
### Delegar un seguimiento
1. Pulsa «Delegar seguimiento».
2. Si quieres, en «Usar plantilla» elige una plantilla de seguimiento: llena los campos y los puedes ajustar. Si la cuenta aún no tiene, salen ejemplos para empezar (Cobranza amable, Seguimiento de cotización, Confirmar cita, Reactivar cliente).
3. En «¿Qué quieres lograr?» escribe el objetivo (es obligatorio).
4. En «Indicaciones para el agente» (opcional) dile el tono, qué ofrecer y qué no decir, como a un compañero.
5. En «Cuándo empezar» elige «Ahora» o «En una fecha».
6. En «Insistir hasta … veces sin respuesta · Cada …» pon cuántas veces (de 1 a 10) y cada cuántos minutos, horas o días.
7. En «Al terminar» elige «Avisarme» o «Avisarme y asignarme la conversación».
8. Si es WhatsApp, elige la plantilla para reabrir la ventana de 24 horas o deja «Que el agente elija la más conveniente».
9. Pulsa «Delegar».
También puedes pedírselo a Dali, por ejemplo «dale seguimiento a Mario para que mande la orden de compra»; te muestra una tarjeta y lo crea cuando confirmas.

### Plantillas de seguimiento
1. En la ventana, después de llenar los campos, pulsa «Guardar como plantilla», ponle un nombre (por ejemplo «Cobranza amable 3 intentos») y «Guardar». Se guarda lo que quieres lograr, las indicaciones, los intentos, cada cuánto, qué hacer al terminar y la plantilla de WhatsApp; no la conversación ni la fecha.
2. Las plantillas son de toda la cuenta: cualquiera que delegue las usa. Quien la creó o un administrador puede actualizarla («Actualizar «nombre»» sale si la cargaste y le cambiaste algo) o borrarla (icono de basura junto a «Usar plantilla»).
3. Dali también las usa: «delega a Mario con Cobranza amable», o si lo que pides se parece a una, la usa y te lo dice en la tarjeta. Si ninguna encaja, arma el seguimiento con lo que dijiste y te ofrece guardarlo como plantilla.

### Cambiar un seguimiento que ya corre
1. Pulsa «Delegar seguimiento» otra vez: la ventana abre con lo del seguimiento que corre y un aviso de en qué intento va.
2. Cambia lo que necesites y pulsa «Reemplazar seguimiento»: se cancela el anterior y arranca este. Por omisión arranca cuando tocaba el siguiente intento, para no escribirle dos veces seguidas; puedes elegir «Ahora».
3. Con Dali: «al seguimiento de Mario ponle 5 intentos»; la tarjeta avisa que lo reemplaza.

### Ver cómo va, pausar, reanudar o cancelar
1. Debajo del botón aparece un renglón con el estado, los intentos (por ejemplo 1/3), el próximo contacto y la última plantilla usada. Pasa el mouse para ver el objetivo y el resultado.
2. Usa «Pausar», «Reanudar» o «Cancelar» en ese mismo renglón. Al cancelar, el agente deja de escribirle al cliente.
Estados posibles: trabajando, en pausa, cumplido, cerrado sin éxito, pide una persona, sin respuesta, no pudo escribir y cancelado.

## Dudas frecuentes
- ¿Qué sabe el agente? Solo dos cosas: las respuestas predefinidas de la empresa (Catálogos › Respuestas Predefinidas) y la nota IA del contacto. El formulario te muestra esa nota y un enlace para editarla en la ficha. La nota IA es la nota del contacto marcada con «Marcar como nota para IA»; cada contacto tiene solo una. Si la empresa no tiene respuestas predefinidas, lo que no esté en la nota IA se lo pasa a una persona.
- ¿Y si la ventana de WhatsApp de 24 horas está cerrada? El agente manda una plantilla aprobada de esa bandeja y llena sus datos; cuenta como un intento. Solo sirven plantillas aprobadas sin archivo en el encabezado ni datos en los botones. Si no hay ninguna, se detiene con el estado «no pudo escribir».
- ¿Y si el contacto no tiene conversaciones? Desde su ficha elige «Bandeja por la que le escribe»: salen WhatsApp y SMS si tiene teléfono y correo si tiene correo. La conversación se crea solo al delegar (si cancelas, no se crea nada). En WhatsApp el primer mensaje siempre es una plantilla aprobada. Si no tiene teléfono ni correo, primero agrégalos.
- ¿Cómo me entero del resultado? Al terminar te deja una nota privada en la conversación con tu mención y, si hay caso, una nota en su actividad. Si el cliente pide una persona, te asigna la conversación.
- Si yo le escribo al cliente, el agente se pausa solo. Puedes reanudarlo después.
- Una conversación solo puede tener un seguimiento vivo a la vez, sea de Seguimiento IA o de un agente de siempre. Pausa o cancela el otro primero.
- «Vista anterior»: en el formulario, este enlace abre la ventana de siempre, «Gestión de Seguimientos», para usar uno de los agentes de Agentes IA › Agentes. Esa ventana necesita además el Bot de Seguimientos activo en la bandeja.
- Agentes IA › Seguimientos lista los seguimientos de los agentes de siempre. Los de Seguimiento IA se ven en la conversación, el caso y la ficha del contacto.

## Quién puede
Cualquier usuario puede delegar en las conversaciones y casos que su rol le deja ver (todo o solo lo suyo). Agentes IA › Seguimientos lo ven quienes tienen el área Agentes IA (por omisión Administrador y Supervisor).
