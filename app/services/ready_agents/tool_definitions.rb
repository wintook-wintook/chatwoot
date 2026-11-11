# frozen_string_literal: true

# Agentes listos — las herramientas que el modelo puede usar (formato de OpenAI).
module ReadyAgents::ToolDefinitions
  def self.fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                    parameters: { type: 'object', properties: properties, required: required } } }
  end

  STR = { type: 'string' }.freeze

  ALL = [
    fn('buscar_respuesta_predefinida', 'Busca en las respuestas predefinidas de la empresa lo que el cliente pregunta.',
       { pregunta: STR }, %w[pregunta]),
    fn('buscar_en_catalogo', 'Busca productos o servicios del catálogo de la empresa, con su precio.',
       { consulta: STR }, %w[consulta]),
    fn('guardar_respuesta', 'Guarda lo que el prospecto contestó a una de las preguntas para calificarlo.',
       { pregunta: STR, respuesta: STR }, %w[pregunta respuesta]),
    fn('actualizar_contacto', 'Guarda el nombre, correo, empresa o ciudad que el prospecto dijo.',
       { nombre: STR, correo: STR, empresa: STR, ciudad: STR }),
    fn('prospecto_calificado', 'El prospecto cumple lo de «calificado»: se pasa al siguiente paso. Después escribe solo ' \
                               'la despedida con el siguiente paso.', { resumen: STR }, %w[resumen]),
    fn('descartar', 'No es prospecto (cumple lo de «descartar» o no le interesa). Después escribe solo la despedida.',
       { motivo: STR }, %w[motivo]),
    fn('pasar_a_humano', 'Pide una persona, se molesta, ya es cliente o pide algo que no puedes resolver.',
       { motivo: STR }, %w[motivo])
  ].freeze

  DECISIONS = { 'prospecto_calificado' => 'resumen', 'descartar' => 'motivo', 'pasar_a_humano' => 'motivo' }.freeze
end
