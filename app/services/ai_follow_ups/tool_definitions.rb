# frozen_string_literal: true

# Seguimiento IA — las herramientas que el modelo puede usar (formato OpenAI «tools»).
module AiFollowUps::ToolDefinitions
  def self.fn(name, description, properties = {}, required = [])
    { type: 'function',
      function: { name: name, description: description,
                  parameters: { type: 'object', properties: properties, required: required } } }
  end

  def self.str(description) = { type: 'string', description: description }

  ALL = [
    fn('buscar_respuesta_predefinida',
       'Busca en las respuestas predefinidas de la empresa (lo que el equipo ya contesta siempre igual). Úsala ' \
       'primero cuando el cliente pregunte algo. Si trae instrucciones_internas, síguelas para redactar tu ' \
       'respuesta pero NUNCA las copies ni las menciones al cliente.',
       { pregunta: str('Lo que preguntó el cliente, en palabras claras') }, %w[pregunta]),
    fn('programar_siguiente_contacto',
       'Fija cuándo volver a escribirle al cliente si no responde (p. ej. pidió «háblame el jueves»).',
       { cuando: str('Fecha y hora local YYYY-MM-DDTHH:MM'), motivo: str('Por qué en esa fecha') }, %w[cuando]),
    fn('marcar_cumplido', 'El objetivo del seguimiento ya se cumplió. Termina el seguimiento y avisa a la persona.',
       { resumen: str('Qué se logró, en una o dos frases') }, %w[resumen]),
    fn('cerrar_sin_exito', 'El cliente no quiere o el objetivo ya no es posible. Termina el seguimiento y avisa.',
       { motivo: str('Por qué, con lo que dijo el cliente') }, %w[motivo]),
    fn('pasar_a_humano',
       'Pasa la conversación a una persona: el cliente lo pide, está molesto, pide algo que no puedes resolver ' \
       'o no encuentras la información. Después de llamarla, solo despídete diciendo que una persona lo atenderá.',
       { motivo: str('Qué necesita el cliente') }, %w[motivo])
  ].freeze

  # Ventana de WhatsApp cerrada: solo plantillas (y fijar cuándo volver a intentar o cerrar).
  TEMPLATE = [
    fn('enviar_plantilla',
       'Manda al cliente una plantilla aprobada de WhatsApp (única forma de escribirle con la ventana cerrada). ' \
       'Una por turno.',
       { nombre: str('Nombre exacto de la plantilla, de la lista'), idioma: str('Idioma de la plantilla, de la lista'),
         variables: { type: 'object', additionalProperties: { type: 'string' },
                      description: 'Valor de cada variable sin llaves, p. ej. {"1": "Mario", "2": "1520"} o {"nombre": "Mario"}' },
         motivo: str('Por qué esta plantilla, en una frase') }, %w[nombre motivo]),
    fn('ninguna_plantilla', 'Ninguna plantilla sirve para el objetivo. El seguimiento se detiene y avisa a la persona.',
       { motivo: str('Por qué ninguna sirve') }, %w[motivo]),
    ALL.find { |t| t.dig(:function, :name) == 'programar_siguiente_contacto' },
    ALL.find { |t| t.dig(:function, :name) == 'cerrar_sin_exito' }
  ].freeze
end
