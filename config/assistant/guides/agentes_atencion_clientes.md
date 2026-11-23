---
key: agentes_atencion_clientes
title: Agente «Atención a clientes»
areas: [ai_agents]
category: Agentes IA
keywords: [atencion a clientes, clientes, soporte, comercial, administrativo, areas, que atiende, ejemplos si y no, probar la matriz, levantar caso, folio, severidad, visita tecnica, factura, rfc, canalizar, no es cliente, varias cosas a la vez, resuelto, escalar, fuentes relacionadas, servicio por omision, etiquetas, reglas por area, horario por area]
pages: [ready_agents, ai_agents]
sources: [app/javascript/dashboard/views/readyAgents/CustomersAgentModal.vue, app/services/motor2/functions/customers.rb]
reviewed: 2026-11-22
---
## Para qué sirve
El agente que atiende a tus clientes: entiende si es Soporte, Comercial, Administrativo u otra área, contesta con tus fuentes (en Soporte, con la solución exacta y sus ligas), levanta su caso o lo pasa al equipo correcto.

## Dónde está
Agentes IA › Agentes listos: «Editar» en el agente (o crea uno nuevo). Lo común a los tres agentes (crear, imágenes y archivos, Cómo habla tu empresa, pausar, probar) está en [[agentes_listos]].

## Cómo se hace
### Atención a clientes
- Pasos del asistente (pestañas arriba): El agente · Tu empresa · Qué atiende (una pestaña por área: Soporte · Comercial · Administrativo · Otra, con punto verde si está prendida; abajo «Probar la matriz») · Qué sabe · Cómo platica (con tus Indicaciones abajo) · Seguimiento (pestañas: Si deja de contestar · Plazo del equipo y citas) · Cotizaciones (cotiza solo con el área Comercial prendida) · Imágenes y archivos.
- Qué atiende: prende las áreas que atiendes: Soporte, Comercial, Administrativo y, si quieres, «Otra área» con su nombre y lo que atiende. Cada área trae ejemplos de «sí es de esta área» y «no es de esta área» (ya vienen llenos, por ejemplo «No puedo enviar una cotización a pedido» es Soporte y no Comercial); cámbialos o agrega los tuyos. El agente decide por lo que el cliente quiere lograr, no por una palabra suelta. En cada área eliges a quién se lo pasa (persona o equipo); si no eliges, va al de «Cómo platica».
- Soporte: primero busca en tus fuentes y contesta solo con lo que dicen:
  - si encuentra la solución exacta, le da los pasos tal cual vienen (con los nombres exactos de botones y menús), agrega «Fuentes relacionadas» con las ligas reales y cierra con «Para avanzar responde: RESUELTO / ESCALAR»; mientras no le dé esa solución, no lo pasa ni levanta caso;
  - si hay varias soluciones para situaciones distintas (por ejemplo «no puedo enviar el pedido»), le pregunta cuál es la suya (qué le aparece);
  - si solo hay información de otro sistema, le dice que es relacionada, sin adaptarla;
  - si no hay nada, le dice «No encontré documentación específica para darte una respuesta segura» y levanta su caso con el folio (o lo pasa a soporte, si así lo eliges).
  No supone causas («probablemente», «puede deberse») ni promete que lo está revisando. Si contesta ESCALAR, lo pasa o levanta el caso ya; si contesta RESUELTO (o «ya quedó»), se despide.
- Soporte para cualquier giro: sirve igual para software que para quien repara aires acondicionados. «Armar ejemplos para mi negocio» (en «Qué atiende») cambia los ejemplos de sí y no de cada área por unos con el vocabulario de tu negocio. Si tu equipo va a domicilio, elige «Si no se resuelve por aquí, agenda una visita técnica»: pide la dirección y una foto del equipo, ofrece horarios de quien elijas y agenda la visita.
- Reglas de cada área: en cada área (Soporte, Comercial, Administrativo, Otra) puedes escribir sus reglas propias («nunca ofrezcas descuentos») y su horario; fuera de ese horario toma lo que necesita y le dice que el equipo le escribe en cuanto abra.
- Soporte, el sistema: «Si el cliente no dice de qué equipo, producto o servicio habla, asume» toma tus Servicios afectados (Casos › Clasificación). La IA decide de qué módulo habla con esa lista; si no lo dice, usa el que elegiste. El caso sale con ese servicio y su categoría.
- Soporte, prioridad y preguntas: antes de levantar el caso hace una sola pregunta (desde cuándo pasa o a cuántos afecta). La prioridad sale sola: no puede operar → urgente (levanta el caso de inmediato, sin preguntar); funciona con falla → alta; duda de uso → media. No levanta dos casos del mismo tipo: si ya tiene uno abierto, le da ese folio.
- De qué empresa es: el contacto se crea solo (con su número de WhatsApp o su correo). Si escribe desde un correo de empresa, el agente lo liga solo a la organización con ese dominio. Si no se sabe, con «Si no sabemos de qué empresa es → Le pregunta» (así viene) le pregunta una vez, ya que entendió qué necesita, de qué empresa escribe y su correo:
  - si la empresa está en Organizaciones, liga el contacto;
  - si no, lo atiende igual, guarda la empresa como texto y deja una nota para tu equipo (etiqueta #empresa-no-encontrada);
  - si el correo ya es de otro contacto, no lo pisa: deja una nota de posible duplicado (#posible-duplicado) para que los unas con «Unir contactos».
  Antes de levantar un caso siempre pregunta la empresa, salvo que sea urgente. Con la empresa sabida, el agente ve su etapa (cliente o prospecto), los sistemas que usa (los Servicios afectados de sus casos), sus casos abiertos y sus contratos, y no pregunta lo que ya se sabe. Lo que dice el cliente no está comprobado: lo usa para ayudar, nunca para dar datos de la cuenta.
- Etiquetas: cada conversación queda con etiquetas de cómo la catalogó la IA, para que tu equipo lo vea y pueda filtrar. Qué pidió: #soporte-duda, #soporte-falla, #soporte-critico, #informacion, #cotizacion, #demo, #visita, #vendedor, #contratar, #administrativo, #humano. Qué se hizo: #respondida, #info-relacionada, #sin-respuesta, #caso-levantado, #canalizada, #gestion-registrada, #resuelto. En «Probar» salen debajo de cada respuesta.
- Comercial: contesta solo lo que confirman tus fuentes; lo que no, dice que no lo puede confirmar y ofrece un vendedor. Nunca ofrece algo parecido en lugar de lo que pidió (una demo no es una visita). Cotización, contratar o hablar con un vendedor: crea la oportunidad con el vendedor (o se lo pasa); si ya tiene una abierta, se le agrega. Demo o visita: la agenda (si eliges «La agenda» y hay alguien con Google Calendar) o el vendedor la acuerda.
- Administrativo: no busca en tus fuentes ni da saldos o montos (no los ve). Pide lo que falte en una sola pregunta (por ejemplo el RFC correcto) y lo pasa a la persona o equipo, o levanta un caso administrativo si lo eliges.
- Si falta algo para entender qué quiere («quiero una cotización»), hace una sola pregunta y su respuesta completa lo mismo («10 usuarios»). Si pide varias cosas a la vez, las atiende una por una; si lo pasa a una persona, lo que quedó pendiente va en la nota.
- Si pide una persona: primero le pregunta qué necesita, para pasarlo al equipo correcto (si lo vuelve a pedir, lo pasa); o, si lo eliges, lo pasa de inmediato.
- Si quien escribe no es cliente: lo atiende igual (recomendado) o lo pasa a una persona. Una bandeja puede tener un agente de «Atención a prospectos» y uno de «Atención a clientes»: quien ya es cliente (su organización está en etapa Cliente, o tiene una oportunidad ganada o un caso de servicio) va con el de clientes y los demás con el de prospectos.
- Nunca dice «ya levanté tu caso», «ya lo registré» o «ya te agendé» si no lo hizo de verdad: el sistema lo revisa antes de mandar.
- Pruébalo: «Probar la matriz» corre todos tus ejemplos de sí y no y te dice cuáles cayeron en su área (✅) y cuáles no (❌); si uno falla, agrega más ejemplos parecidos. En el chat de prueba ves qué área detectó en cada mensaje y qué hizo; en la prueba no se crean casos reales (sale el folio PRUEBA-1).
