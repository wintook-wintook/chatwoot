# frozen_string_literal: true

# Las variables que declara la sección [VARIABLES] de un Entrenamiento (ver
# ContactTrackings::ConversationVariables): { 'CARRERA' => { name:, options: [...], free: } }
# y sus valores iniciales.
class ContactTrackings::ConversationVariables::Definition
  FREE_VALUES = %w[VALOR TEXTO DATO].freeze
  MAX_VALUE   = 120

  HEADER_RE  = /\A[ \t]*\[[ \t]*VARIABLES?[ \t]*\][ \t]*\z/i
  NAME       = '[A-Za-zÁÉÍÓÚÑáéíóúñ_][A-Za-z0-9ÁÉÍÓÚÑáéíóúñ_]*'
  DECL_RE    = /\A[ \t]*(?:[-*][ \t]*)?(#{NAME})[ \t]*=[ \t]*(.+?)[ \t]*\z/o
  INITIAL_RE = /\A[ \t]*(?:[-*][ \t]*)?inicial(?:es)?[ \t]*:[ \t]*(.+?)[ \t]*\z/i
  PAIR_RE    = /(#{NAME})[ \t]*=[ \t]*([^;\n]+)/o

  attr_reader :variables, :initial

  def self.parse(prompt)
    variables = {}
    initial   = {}
    section_lines(prompt.to_s).each do |linea|
      if (match = linea.match(INITIAL_RE))
        match[1].scan(PAIR_RE).each { |nombre, valor| initial[key(nombre)] = valor.strip }
      elsif (match = linea.match(DECL_RE))
        variables[key(match[1])] = variable(match[1], match[2])
      end
    end
    new(variables, initial)
  end

  def self.variable(nombre, lista)
    options = lista.split('|').map(&:strip).compact_blank
    free    = options.any? { |opcion| FREE_VALUES.include?(key(opcion)) }
    { name: nombre.strip, options: options.reject { |opcion| FREE_VALUES.include?(key(opcion)) }, free: free }
  end

  # Las líneas de la sección [VARIABLES], hasta el siguiente rótulo.
  def self.section_lines(prompt)
    dentro = false
    prompt.split("\n").each_with_object([]) do |linea, acc|
      if linea.match?(HEADER_RE)
        dentro = true
      elsif header?(linea)
        dentro = false
      elsif dentro
        acc << linea
      end
    end
  end

  def self.header?(linea)
    linea.match?(ContactTrackings::Assistant::DraftPieces::SECTION_RE) ||
      linea.match?(ContactTrackings::Assistant::DraftPieces::MARKDOWN_RE)
  end

  def self.key(text)
    ContactTrackings::ConversationVariables.key(text)
  end

  # Un inicial que no es válido (o que falta) arranca en el primer valor declarado.
  def initialize(variables, declared_initial)
    @variables = variables
    @initial   = variables.to_h do |clave, var|
      [clave, coerce(var[:name], declared_initial[clave]) || var[:options].first || '']
    end
  end

  def blank?
    variables.empty?
  end

  def names
    variables.values.pluck(:name)
  end

  def variable(name)
    variables[self.class.key(name)]
  end

  # El valor tal como está declarado (SÍ aunque el modelo escriba «si»), el texto libre
  # si la variable lo admite, o nil si no es válido.
  def coerce(name, raw)
    var = variable(name)
    return nil unless var

    value = raw.to_s.strip.sub(/[.,;]+\z/, '').strip.delete_prefix('"').delete_suffix('"').strip
    return nil if value.blank?

    declared = var[:options].find { |opcion| self.class.key(opcion) == self.class.key(value) }
    return declared if declared
    return value.truncate(MAX_VALUE) if var[:free]

    nil
  end
end
