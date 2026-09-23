# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — CÓMO LE HABLA EL BOT AL CLIENTE
# ================================================================================
# Una sola regla, para todo lo que redacta una respuesta al cliente (conversacional,
# base de conocimiento, foro, ERP, cobranza). Pedido del usuario el 24/09/2026: un
# agente contestó «Ya tenés una cita… Si querés… ¿Qué preferís?». Salía de mensajes
# fijos escritos con voseo y de instrucciones al modelo escritas con voseo, que el
# modelo imita. El producto es para México: tú, salvo que el agente pida usted.
# ================================================================================

module ContactTrackings::CustomerTone
  RULE = 'TRATO AL CLIENTE: háblale de tú, en español de México, salvo que tus instrucciones digan ' \
         'que es de usted. Nunca uses voseo (vos, tenés, querés, podés, decime).'
end
