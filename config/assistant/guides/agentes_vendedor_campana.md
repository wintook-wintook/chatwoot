---
key: agentes_vendedor_campana
title: Agente «Vendedor de campaña»
areas: [ai_agents]
category: Agentes IA
keywords: [vendedor de campana, campanas, campana con vendedor ia, toca la puerta, relevo, le interesa, invitar, invitacion a evento, confirmar asistencia, ofrecer, promocion, reactivar, renovar, encuesta de satisfaccion, oferta de ejemplo, probar]
pages: [ready_agents, ai_agents]
sources: [app/javascript/dashboard/views/readyAgents/CampaignSellerModal.vue, app/services/motor2/functions/campaign_seller.rb]
reviewed: 2026-11-22
---
## Para qué sirve
El agente que atiende las respuestas de tus Campañas con Vendedor IA: despierta el interés con la oferta de la campaña, resuelve las primeras dudas y pasa al interesado a quien sigue. El proceso completo de una campaña por correo está en [[campana_correo_vendedor_ia]].

## Dónde está
Agentes IA › Agentes listos: «Editar» en el agente (o crea uno nuevo). Lo común a los tres agentes (crear, imágenes y archivos, Cómo habla tu empresa, pausar, probar) está en [[agentes_listos]].

## Cómo se hace
### Vendedor de campaña
- No atiende bandejas: lo creas aquí y lo eliges en Campañas › «Agregar campaña» › «Campaña con Vendedor IA (Motor 2.0)». Un mismo vendedor sirve para muchas campañas: cada campaña trae su oferta, su canal y sus mensajes; el vendedor pone cómo vende (su voz, lo que sabe, a quién pasa el relevo, seguimiento, cotizaciones y archivos).
- Pasos del asistente (pestañas arriba): El agente · Tu empresa · Qué sabe · Cómo platica y el relevo (con tus Indicaciones abajo) · Seguimiento · Cotizaciones · Imágenes y archivos. Ya no lleva «Qué ofreces» ni «Canal y toques»: eso va en cada campaña.
- Junto al chat de prueba está «Oferta de ejemplo para probar» (para qué es, qué ofreces, evento o preguntas de encuesta): solo sirve para «Probar» aquí y para llenar de inicio las campañas nuevas. Los vendedores que ya tenías conservan su oferta y su canal, y sus campañas clásicas siguen igual.
- Lo que hace según el tipo de campaña:
  - Ofrecer, Reactivar o Recordar/renovar: despierta el interés con la oferta de la campaña; si le interesa, lo pasa a quien sigue (o le agenda una cita, si la campaña lo pide y hay alguien con Google Calendar).
  - Invitar: con el evento de la campaña (fecha, lugar y liga salen de Eventos). Cuando dice que va (o que no), queda confirmado o cancelado en la lista del evento.
  - Encuesta: hasta 3 preguntas; las hace tal cual, en orden y una por mensaje. Si una calificación queda por debajo de la de la campaña (7 por omisión), levanta un caso con prioridad alta.
- El relevo: si le interesa, lo pasa al agente de la bandeja («Atención a prospectos», o «Atención a clientes» si ya es cliente) en la misma conversación y sin que lo note: el de campaña no contesta y el que sigue contesta ese mismo mensaje, con una nota de contexto («le interesó la campaña X…»). Si no hay agente, o eliges «a una persona», va a la persona o equipo que elijas (si la campaña tiene tablero de entrega, entra ahí con su plazo).
- Siempre: una pregunta por mensaje; de la oferta solo dice lo que pusiste o lo que está en tus fuentes; si dice que no, se despide sin insistir y no hay más toques; «ya no me escriban» lo da de baja.
- Pruébalo: el chat empieza con el mensaje de la campaña (puedes cambiarlo); contesta como tu contacto. En la prueba no se toca nada real.
