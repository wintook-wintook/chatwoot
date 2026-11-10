# frozen_string_literal: true

# Asistente (Dali) — funciones de captar en la expo con etiqueta NFC (formato de OpenAI). Lo
# que hacen vive en Assistant::EventTools.
module Assistant::EventToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('nfc_links', 'Enlaces NFC de un evento (expo, feria) para captar acercando el celular: los que hay, cuántos ' \
                      'captó cada uno, los WhatsApp posibles y el mensaje sugerido.',
         { event: D.str('Nombre o parte del nombre del evento'), event_id: D.int('Id del evento') }),
    D.fn('propose_nfc_link', 'Propone crear (o reutilizar) el enlace NFC de un evento para grabarlo en una etiqueta. ' \
                             'Usa nfc_links antes para el event_id y el WhatsApp.',
         { event_id: D.int('Id del evento'), inbox_id: D.int('Id del WhatsApp que recibe (de nfc_links)'),
           seller: D.str('Nombre del vendedor del enlace, si lo dijo'), message: D.str('Mensaje que envía el cliente; vacío = el sugerido') },
         %w[event_id])
  ].freeze
end
