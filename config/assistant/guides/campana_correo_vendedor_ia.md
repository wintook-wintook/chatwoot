---
key: campana_correo_vendedor_ia
title: Campaña por correo con Vendedor IA, de la lista a la venta
areas: [campaigns]
category: Campañas
keywords: [ficha de campana, si ya dio clic, encuesta por correo, botones de calificacion, etiqueta del contacto, calentar el dominio, spf, dkim, dmarc, rebotes, campana pausada, prospectos de listas, importo, importar contactos, contactos en cuarentena, cuarentena de contactos, campana por correo, campana de correo, lista fria, lista de correos, subir lista, importar lista, csv, cuarentena, prospectos de lista, de la lista a la venta, proceso completo, flujo de la campana, vendedor ia, vendedor de campana, relevo, atencion a prospectos, calificar, cotizar, oportunidad, seguimiento de cotizacion, cierre, ganada, perdida, limpieza automatica, lista de exclusion, darse de baja, rebote, tope diario, prueba a/b, que hace el humano, automatico]
pages: [campaigns, ready_agents, contacts, quotes, opportunities, catalog, inboxes]
sources: [app/javascript/dashboard/views/campaigns2/*.vue, app/services/prospect_lists/import.rb, app/jobs/prospect_lists/cleanup_job.rb, app/services/tracking_campaigns/motor2_*.rb, app/services/motor2/relay.rb, app/services/motor2/skills/quote.rb, app/jobs/motor2/quote_follow_up_job.rb]
reviewed: 2026-11-26
---
## Para qué sirve
Una campaña por correo con Vendedor IA lleva a un contacto desde una lista fría hasta una venta ganada. Los agentes hacen casi todo; una persona de tu equipo entra solo en algunos momentos: preparar, lanzar, atender a quien pide hablar con alguien, revisar la cotización y cerrar.
- Automático: lo hace Kontrolya o un agente de IA, sin que nadie intervenga.
- Persona: lo hace alguien de tu equipo; Kontrolya le avisa y le deja todo listo.

El flujo de un vistazo:
1. Subir la lista (persona): se limpia y los nuevos quedan en cuarentena.
2. Revisar, probar y lanzar (persona): tope diario y prueba a tu correo.
3. Envíos y toques (automático): el primer correo y, si no contesta, sus toques (uno cada N días) hasta que conteste. Si nunca contesta, se borra solo a los 30 días de terminar la campaña.
4. Contesta o da clic (automático): sale de la cuarentena y ya es contacto.
5. Vendedor de campaña (automático): resuelve 2 o 3 dudas con la oferta. Sale del flujo si no le interesa, si pide «ya no me escriban» o si pide una persona.
6. Relevo a Atención a prospectos (automático): en la misma conversación, con una nota de contexto.
7. Califica, recomienda y cotiza (automático): oportunidad con responsable, o cita.
8. El vendedor revisa y manda la cotización (persona): tiene un plazo; si no atiende, se escala.
9. Seguimiento de la cotización (automático): a los N días le pregunta si la revisó.
10. Cierre (persona): ganada o perdida; si se gana, la organización pasa a cliente.

## Dónde está
- La campaña: Campañas › De agentes IA › «Agregar campaña» › «Campaña con Vendedor IA (Motor 2.0)» (marcada Beta).
- Los agentes: Agentes IA › Agentes listos (Vendedor de campaña y Atención a prospectos).
- Los resultados: abre la campaña en la lista de Campañas (se filtran con «Con Vendedor IA»).

## Cómo se hace
### Antes de empezar (una sola vez)
1. Crea un «Vendedor de campaña» en Agentes listos: su voz, lo que sabe, cuántas dudas contesta y a quién pasa a los interesados.
2. Pon a «Atención a prospectos» a atender la misma bandeja de correo: es quien recibe a los interesados. Sin él, van directo a una persona o equipo.
3. Ten el Catálogo con precios (para recomendar y cotizar) y elige cómo cotiza Atención a prospectos: en borrador para el vendedor o directo al cliente.
4. Usa una bandeja de correo, de preferencia con un dominio aparte para listas frías, para no dañar el correo principal de tu empresa.

### 1. Subir la lista: limpieza y cuarentena
1. En la campaña, paso «Audiencia», elige «Subir una lista de correos» y la bandeja de correo.
2. Sube el CSV con encabezados: correo o email (obligatorio); nombre, empresa y teléfono opcionales. Hasta 5,000 renglones; acepta separación con coma o con punto y coma.
3. Kontrolya quita, y te dice cuántos y por qué: sin correo o mal escrito, repetidos, correos de rol (info@, ventas@, contacto@…), los que antes se dieron de baja o rebotaron y los de dominios que no reciben correo.
4. Si el correo ya es de un contacto tuyo, usa ese y no lo duplica.
5. Los nuevos quedan en cuarentena: no aparecen en Contactos ni en búsquedas hasta que contesten o den clic.
6. Sus conversaciones tampoco llenan tu bandeja: nacen pospuestas y sin asignar, y vuelven a «Abiertas» solas cuando el contacto contesta. Para verlos, en Contactos usa el botón «Prospectos de listas».
7. Cuando contesta o da clic, si la lista traía su empresa, se liga a esa organización (la que ya tengas con ese nombre o una nueva, como prospecto).

Las listas son solo para correo. En WhatsApp no se ofrece: escribirle a quien no te conoce hace que te bloqueen, y Meta puede bajar o suspender tu número.

### 2. Revisar y lanzar
- En «Revisar y lanzar» Kontrolya revisa la oferta, el vendedor, el asunto, a quién se pasan los interesados y las fechas. Con algo en rojo no deja lanzar.
- Revisa el dominio de tu bandeja de correo: SPF, DKIM y DMARC (los piden Gmail y Yahoo). Con lista fría, sin SPF o con un correo gratis (gmail.com, hotmail.com…) no deja lanzar.
- «Calentar el dominio» (paso Cuándo; al subir una lista se prende solo): el primer día salen 50, luego 100, 200… hasta tu máximo por día. Si rebota más del 5 % de lo enviado (desde 20 envíos), la campaña se pausa sola para que revises la lista y el dominio.
- Con lista pide un máximo de envíos por día: de inicio pone 50 y avisa si pasas de 200.
- Antes de lanzar, en «Revisar y lanzar»: «Simular la campaña» enseña todos los correos ya personalizados para un contacto y qué pasa según conteste; «Prueba real» manda la campaña completa a tu correo con un toque cada pocos minutos (no cuenta en resultados); «Chatear con el vendedor» y «Enviarme una prueba» siguen igual. Ver [[campanas_eventos]].

### 3. Envíos y toques (automático)
- Cada contacto recibe su primer correo en el horario de atención, sin pasar el tope del día.
- No se le escribe a quien otra campaña contactó hace poco, a quien se dio de baja ni a quien tiene un correo inválido.
- El primer correo lleva todo (en correo casi nadie contesta «mándame info»): el que escribiste (con {{contacto}}, {{empresa}}, {{oferta}}; en Reactivar, {{ultima_compra}}; en Recordar, {{que_vence}}, {{vence}} y {{monto}}: el editor del correo pone los botones de las que tiene ese tipo, la vista previa las llena de ejemplo y el asunto también las acepta) o, si lo dejaste vacío, uno que la IA escribe con lo esencial de «La ficha» y la liga principal como botón. Para escribirlo tú sin empezar de cero, «✨ Redactar con Dali» (en «Mensajes › Correos», en cada correo) lo arma con lo que tiene la campaña: asunto, asunto B y los bloques con el botón a la liga; lo revisas y lo cambias. Lleva el asunto A o B, la firma, la liga para darse de baja y ligas que cuentan los clics.
- Si no contesta, sale el siguiente cada N días. Cada toque cambia según lo que hizo: a quien ya dio clic y no confirmó le sale su versión «si ya dio clic» (o la IA le pregunta si pudo hacerlo); a los demás, otro ángulo más corto. En cuanto contesta o lo logra, ya no salen más.
- Encuesta por correo: la primera pregunta va con botones de su rango (del 0 al 10 o del 1 al 5); el botón abre una página donde confirma y contesta las demás (abrir la liga no guarda nada). Una calificación baja (cada pregunta tiene la suya) levanta el caso que pusiste en «Si califica bajo», como en WhatsApp.
- Recordar por correo: cada contacto recibe sus correos en los días antes de que venza SU contrato (por omisión 7, 1 y el día), no «cada N días».
- Para detenerla para siempre: «Terminar campaña» (lista o Resultados): ya no sale nada nuevo, la IA sigue contestando a quien ya platica y los Resultados se quedan.

### 4. El contacto contesta (automático)
Al contestar o dar clic sale de la cuarentena y ya es un contacto normal. La campaña contesta sola con «La ficha» (lo que no esté ahí ni en tus fuentes, dice que no lo tiene) y las respuestas de «Respuestas y resultados»; si se queda callado a media plática, le vuelve a escribir.
- Lo logró (según el objetivo: le interesa y pasa a Atención a prospectos, agenda, confirma, o escribe la palabra clave): queda con su etiqueta.
- «No puedo esta vez»: le pregunta una vez si le escribimos la próxima; si dice que sí o que no, queda con su etiqueta (por ejemplo avisar-promociones o no-ofrecer).
- «No me manden nada»: lo respeta ya, con la etiqueta «no…»; no entra a las siguientes campañas de ese tipo. «Darme de baja» o «stop» lo da de baja de todo.
- Pide una liga o no le llegó el correo: le manda la liga exacta que toca.
- Pide hablar con una persona: se lo pasa a alguien de tu equipo y deja de contestar.

### 5. Relevo a Atención a prospectos (automático)
El interesado pasa a Atención a prospectos en la misma conversación, sin que el cliente lo note. El agente que sigue recibe una nota con el contexto («le interesó la campaña X por…») y contesta ese mismo mensaje. Si así lo configuraste, en lugar del relevo le agenda la cita directo en Google Calendar o lo pasa a una persona o equipo.

### 6. Atención a prospectos califica y cotiza (automático)
1. Hace tus preguntas sin repetir lo que el contacto ya dijo y marca la temperatura (caliente, tibio o frío).
2. Recomienda productos del Catálogo con su foto.
3. Si pide cotización, antes le pide los datos obligatorios (por ejemplo, correo o empresa) y la arma con los precios del Catálogo; pedirla lo marca como caliente.
4. Abre la oportunidad con su responsable, sin duplicarla.
5. Si quiere una cita, la agenda, le manda un recordatorio antes y, si no llega, le escribe para reagendar.

### 7. El vendedor cierra
1. Automático: el vendedor recibe un aviso con @mención y la conversación queda asignada a él. Tiene un plazo para atenderlo; si no le escribe a tiempo, se le avisa y luego se escala a los administradores.
2. Persona: si la cotización quedó en borrador, la revisa y la manda; si era directa, ya le llegó al cliente.
3. Automático: a los N días se le pregunta al cliente si pudo revisarla, con la plantilla propia de cotizaciones. No pregunta si ya escribió o si la cotización ya se ganó, perdió o canceló.
4. Persona: negocia, hace la llamada o la cita y mueve la oportunidad en su tablero.
5. Persona: marca la cotización ganada o perdida, con su motivo.
6. Automático: si se gana, la organización pasa a cliente y la venta cuenta en el presupuesto de ventas.

### 8. Resultados y limpieza (automático)
- Embudo: enviados, entregados, clics, contestaron, les interesó, pasaron al vendedor o cita, cotizaciones y ganadas, con el % sobre lo enviado y los montos.
- Salidas: no les interesó (con el motivo), no contestaron, pidieron una persona, se dieron de baja y no se pudo enviar.
- La lista: cuántos venían, cuántos se descartaron y por qué, cuántos ya son contactos y cuántos siguen en cuarentena.
- «Resumir con IA»: qué preguntan los contactos, sus objeciones y qué mejorar.
- «Siguiente campaña con…» (persona): arma otra campaña con los que no contestaron, los que dieron clic o los que les interesó.
- Limpieza: pasados los días que elegiste (30 si no cambias nada) desde que termina la campaña, se borran solos los que nunca contestaron. Los que se dieron de baja o rebotaron quedan en una lista de exclusión para no volver a cargarlos.

### Dónde entra tu equipo
- Preparar (administrador): configura los agentes, el Catálogo y la bandeja de correo.
- Lanzar (quien hace la campaña): sube la lista, prueba, revisa y lanza.
- Pide una persona (vendedor o equipo): atiende la conversación.
- Cotización en borrador (vendedor): la revisa y la manda.
- Cita o negociación (vendedor): llama, se reúne, ajusta el precio.
- Cierre (vendedor): marca la cotización ganada o perdida.
- Mejora (quien hace la campaña): lee el tablero y arma la siguiente campaña.

## Dudas frecuentes
- ¿Por qué no veo en Contactos a los de mi lista? Están en cuarentena hasta que contestan o dan clic; los ves con el botón «Prospectos de listas» en Contactos o en el tablero de la campaña.
- ¿Por qué se pausó mi campaña sola? Rebotó más del 5 % de los correos: revisa la lista (correos viejos o inventados) y el dominio, y reanúdala.
- ¿Puedo subir una lista para WhatsApp? No: solo para correo, para cuidar tu número.
- ¿Qué pasa con los que nunca contestan? Se borran solos a los días que elegiste después de que termina la campaña.
- ¿Se crea la organización (empresa) del contacto? Sí, si la lista traía la columna empresa: al contestar se liga a la organización con ese nombre o se crea como prospecto.
- ¿Con cuántos empiezo? Con una campaña chica, 50 contactos y un tope de 50 al día, para verla andar de punta a punta.

## Quién puede
Crear y lanzar campañas: quien tenga el área Campañas. Configurar los agentes listos: administradores. Atender conversaciones y cotizaciones: el vendedor asignado o su equipo.
