# frozen_string_literal: true

# Probador de agentes — la traza de una respuesta, igual para los dos motores, para enseñarla
# bajo el mensaje y dársela al entrenador:
#   1.0 (content_attributes['traza'], ContactTrackings::EngineTrace): ruta, fuente, fragmentos
#       (solo títulos y similitud), camino y uso;
#   2.0 (content_attributes['motor2'], Motor2::Trace): herramientas, fuentes con lo que
#       regresaron y eventos.
module AgentTester::Trace
  module_function

  def normalize(attrs)
    if attrs['motor2'].present?
      { 'engine' => '2' }.merge(attrs['motor2'].to_h)
    elsif attrs['traza'].present?
      { 'engine' => '1' }.merge(attrs['traza'].to_h)
    else
      {}
    end
  end

  # Para el usuario: renglones cortos de lo que hizo.
  def lines(trace)
    trace = trace.to_h
    trace['engine'] == '1' ? lines_v1(trace) : lines_v2(trace)
  end

  def lines_v1(trace)
    out = []
    out << "Ruta: #{trace.dig('ruta', 'nombre') || 'ninguna'}" if trace['ruta']
    out << "Fuente: #{trace.dig('fuente', 'nombre') || trace.dig('fuente', 'modo')}" if trace['fuente']
    Array(trace['fragmentos']).each { |f| out << "Fragmento: #{f['titulo']} (#{f['similitud']})" }
    out << "Contestó: #{trace['camino']}" if trace['camino']
    out
  end

  def lines_v2(trace)
    out = Array(trace['sources']).map { |s| "Buscó en «#{s['name']}»: #{Array(s['found']).size} resultado(s)" }
    out + Array(trace['events']).map { |e| "#{e['kind']}: #{e['text']}" }
  end
end
