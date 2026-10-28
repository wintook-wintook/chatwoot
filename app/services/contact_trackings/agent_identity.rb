# Agentes IA — cómo ve el cliente al agente que le escribe. Los mensajes del agente se
# guardan con `content_attributes.ai_agent` y su nombre (TrackingTemplate#customer_display_name):
# WhatsApp antepone ese nombre (o ninguno), nunca el del usuario con el que se guardan, y la
# conversación los pinta como del agente IA. Ver Message#sender_name y Messages::MessageBuilder.
module ContactTrackings::AgentIdentity
  # Para Messages::MessageBuilder (param :ai_agent) y para los mensajes que se mandan sin
  # guardar (content_attributes del Message.new).
  def self.for(template)
    { name: template&.customer_display_name.to_s.squish.presence }
  end

  def self.content_attributes(template)
    { ai_agent: true, ai_agent_name: self.for(template)[:name] }
  end
end
