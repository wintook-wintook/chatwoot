---
key: agentes_vendedor_campana
title: Agente «Vendedor de campaña»
areas: [ai_agents]
category: Agentes IA
keywords: [objeciones, objeciones de la oferta, relevo de la campana, vendedor de campana, campanas, campana con vendedor ia, toca la puerta, relevo, le interesa, invitar, invitacion a evento, confirmar asistencia, ofrecer, promocion, reactivar, renovar, encuesta de satisfaccion, oferta de ejemplo, probar]
pages: [ready_agents, ai_agents]
sources: [app/javascript/dashboard/views/readyAgents/CampaignSellerModal.vue, app/services/motor2/functions/campaign_seller.rb]
reviewed: 2026-11-23
---
## Para qué sirve
El agente que atiende las respuestas de tus Campañas con Vendedor IA: despierta el interés con la oferta de la campaña, resuelve las primeras dudas y pasa al interesado a quien sigue. El proceso completo de una campaña por correo está en [[campana_correo_vendedor_ia]].

## Dónde está
Agentes IA › Agentes listos: «Editar» en el agente (o crea uno nuevo). Lo común a los tres agentes (crear, imágenes y archivos, Cómo habla tu empresa, pausar, probar) está en [[agentes_listos]].

## Cómo se hace
### Vendedor de campaña
- No atiende bandejas: lo creas aquí y lo eliges en Campañas › «Agregar campaña» › «Campaña con Vendedor IA (Motor 2.0)». Un mismo vendedor sirve para muchas campañas: cada campaña trae su oferta, su canal y sus mensajes; el vendedor pone cómo vende (su voz, lo que sabe, el relevo por omisión, las objeciones generales, seguimiento, cotizaciones y archivos). Cada campaña puede cambiar a quién pasa el interesado y agregar las objeciones de su oferta.
- Pasos del asistente (pestañas arriba): El agente · Tu empresa · Qué sabe · Cómo platica y el relevo (con tus Indicaciones abajo) · Seguimiento · Cotizaciones · Imágenes y archivos. Ya no lleva «Qué ofreces» ni «Canal y toques»: eso va en cada campaña.
- El vendedor solo se configura: ya no trae oferta de ejemplo ni chat de prueba. Se prueba en la campaña, con su oferta de verdad: en «Revisar y lanzar», «Simular la campaña», «Chatear con el vendedor» o «Prueba real» (ver [[campanas_eventos]]).
- En «El agente» va la firma de sus correos. En «Cómo platica» eliges con quién agenda citas (los calendarios), que usan las campañas con meta «Agendar cita». Las plantillas de WhatsApp para el seguimiento pasadas las 24 h y el aviso de cita salen de todas tus bandejas de WhatsApp; la revisión de cada campaña avisa si una no está aprobada en la bandeja de esa campaña. Los archivos se pueden ligar a cualquiera de los 6 toques.
- Lo que hace según el tipo de campaña:
  - Ofrecer, Reactivar o Recordar/renovar: despierta el interés con la oferta de la campaña; si le interesa, lo pasa a quien sigue (o le agenda una cita, si la campaña lo pide y hay alguien con Google Calendar).
  - Invitar: con el evento de la campaña (fecha, lugar y liga salen de Eventos). Cuando dice que va (o que no), queda confirmado o cancelado en la lista del evento.
  - Encuesta: hasta 3 preguntas; las hace tal cual, en orden y una por mensaje. Si una calificación queda por debajo de la de la campaña (7 por omisión), levanta un caso con prioridad alta.
- El relevo: si le interesa, lo pasa al agente de la bandeja («Atención a prospectos», o «Atención a clientes» si ya es cliente) en la misma conversación y sin que lo note: el de campaña no contesta y el que sigue contesta ese mismo mensaje, con una nota de contexto («le interesó la campaña X…»). Si no hay agente, o eliges «a una persona», va a la persona o equipo que elijas (si la campaña tiene tablero de entrega, entra ahí con su plazo). Esto es el valor por omisión: en la campaña, paso «Oferta», «Si le interesa (o pide una persona), pasa a» puede dejar «Lo que diga el vendedor», mandarlo al agente de la bandeja o a una persona o equipo de esa campaña.
- Objeciones: en el vendedor van las generales (sirven para todas las campañas: «ya tengo proveedor», «¿quiénes son?»); las de una oferta («está caro» en esa promo) van en la campaña. Si se repite la misma objeción, gana la de la campaña.
- Siempre: una pregunta por mensaje; de la oferta solo dice lo que pusiste o lo que está en tus fuentes; si dice que no, se despide sin insistir y no hay más toques; «ya no me escriban» lo da de baja.
- «Ahora no»: si dice que ahorita no, que le escriban en otra fecha o llega una respuesta de fuera de la oficina, no lo cierra: se le vuelve a escribir una sola vez en esa fecha (30 días si no dice), en horario hábil.
