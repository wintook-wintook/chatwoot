# frozen_string_literal: true

# Motor 2.0 — formato de OpenAI para las herramientas de las habilidades.
module Motor2::Tools
  STR = { type: 'string' }.freeze

  module_function

  def fn(name, description, properties = {}, required = [])
    { type: 'function', function: { name: name, description: description,
                                    parameters: { type: 'object', properties: properties, required: required } } }
  end

  def name_of(definition) = definition.dig(:function, :name)
end
