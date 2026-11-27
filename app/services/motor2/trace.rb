# frozen_string_literal: true

# Motor 2.0 — qué hizo el agente en un turno: herramientas, fuentes consultadas (con lo que
# regresaron), datos guardados y revisiones del código. Se guarda en la respuesta
# (content_attributes['motor2']) y es lo que muestra el probador y lo que lee el entrenador
# para decidir si un error es de las instrucciones, de la fuente o del motor.
class Motor2::Trace
  MAX_SNIPPET = 400

  attr_reader :tools, :sources, :events

  def initialize
    @tools = []
    @sources = []
    @events = []
  end

  def tool(name, args, result)
    @tools << { 'name' => name, 'args' => args, 'ok' => !result.to_h.key?(:error), 'error' => result.to_h[:error] }.compact
  end

  # Lo que regresó una fuente: el entrenador lo enseña tal cual («En Precios dice…»).
  def source(name:, kind:, query:, found:)
    @sources << { 'name' => name, 'kind' => kind, 'query' => query.to_s.first(200),
                  'found' => Array(found).first(3).map { |f| f.to_s.first(MAX_SNIPPET) } }
  end

  def event(kind, text)
    @events << { 'kind' => kind.to_s, 'text' => text.to_s.first(300) }
  end

  def to_h
    { 'tools' => @tools, 'sources' => @sources, 'events' => @events }
  end
end
