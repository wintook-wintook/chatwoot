# frozen_string_literal: true

# Asistente (Dali) — llamar por WhatsApp (formato de OpenAI). Lo que hace vive en
# Assistant::CallTools y Assistant::CallRunner.
module Assistant::CallToolDefinitions
  D = Assistant::ToolDefinitions

  ALL = [
    D.fn('propose_whatsapp_call', 'Propone llamarle a un cliente por WhatsApp (voz). Al confirmar, la llamada sale del navegador ' \
                                  'del usuario y él habla; si el cliente no ha dado permiso, se le pide solo. Requiere confirmación. ' \
                                  'Da uno: conversation_id, contact_id o case_id.',
         { conversation_id: D.int('Número de la conversación de WhatsApp'), contact_id: D.int('Id del contacto'),
           case_id: D.int('Id del caso (se llama a su cliente)') })
  ].freeze
end
