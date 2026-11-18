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

  # Nombre de cada hallazgo de la auditoría de predefinidas en los renglones.
  AUDIT_KINDS = { 'duplicate' => 'duplicada', 'overlap' => 'se solapa', 'contradiction' => 'contradicción',
                  'writing' => 'redacción' }.freeze

  # Para el usuario: renglones cortos de lo que hizo. Con `account`, cada fragmento de
  # una predefinida lleva lo que la auditoría tiene abierto de ella y si pasa del tope
  # de caracteres (proyecto@auditoria_predefinidas).
  def lines(trace, account: nil)
    trace = trace.to_h
    trace['engine'] == '1' ? lines_v1(trace, account) : lines_v2(trace)
  end

  def lines_v1(trace, account = nil)
    out = []
    out << "Ruta: #{trace.dig('ruta', 'nombre') || 'ninguna'}" if trace['ruta']
    out << "Fuente: #{trace.dig('fuente', 'nombre') || trace.dig('fuente', 'modo')}" if trace['fuente']
    avisos = canned_warnings(trace, account)
    Array(trace['fragmentos']).each do |f|
      out << ["Fragmento: #{f['titulo']} (#{f['similitud']})", avisos[f['titulo']]].compact.join(' ')
    end
    out.concat(selection_lines(trace))
    out << "Contestó: #{trace['camino']}" if trace['camino']
    out
  end

  # proyecto@predefinidas_que_contestan: qué escogió la IA entre las candidatas y por qué,
  # si no escogió ninguna, y los datos que se quitaron por no venir de las fuentes.
  def selection_lines(trace)
    chosen_lines(trace['seleccion'].to_h) + removed_lines(trace['datos_quitados'].to_h)
  end

  def chosen_lines(sel)
    return [] if sel.blank?

    sujeto = " · sujeto: #{Array(sel['sujeto']).join(', ')}" if sel['sujeto'].present?
    out = ["Selección: #{Array(sel['escogidas']).size} de #{sel['candidatas']} candidatas#{sujeto}"]
    Array(sel['escogidas']).each do |e|
      out << "Escogió [#{e['tipo']}] #{e['titulo']}#{" — #{e['por_que']}" if e['por_que'].present?}"
    end
    out << "Ninguna contesta#{": falta #{sel['falta']}" if sel['falta'].present?}" if sel['ninguna']
    out
  end

  def removed_lines(quitados)
    return [] if quitados.blank?

    ["Datos que no estaban en las fuentes: #{Array(quitados['inventados']).join(', ')}" \
     "#{' (se quitaron)' if Array(quitados['quedaron']).any?}"]
  end

  def lines_v2(trace)
    out = Array(trace['sources']).map { |s| "Buscó en «#{s['name']}»: #{Array(s['found']).size} resultado(s)" }
    out + Array(trace['events']).map { |e| "#{e['kind']}: #{e['text']}" }
  end

  # { título => '⚠ Auditoría: …' } de los fragmentos que son predefinidas con algo pendiente.
  def canned_warnings(trace, account)
    predefinidas = canned_fragments(trace, account)
    return {} if predefinidas.empty?

    tipos = open_kinds(account, predefinidas.map(&:id))
    predefinidas.each_with_object({}) do |r, acc|
      partes = warning_parts(r, tipos[r.id])
      acc[r.short_code] = "⚠ Auditoría: #{partes.join(', ')}" if partes.any?
    end
  end

  # Las predefinidas que salieron como fragmentos (solo si la fuente fue de predefinidas).
  def canned_fragments(trace, account)
    return [] unless account && trace.dig('fuente', 'modo') == 'canned_response'

    titulos = Array(trace['fragmentos']).filter_map { |f| f['titulo'].presence }
    account.canned_responses.where(short_code: titulos).to_a
  end

  # { id => [kind, …] } de los hallazgos abiertos, contando las dos del par.
  def open_kinds(account, ids)
    account.canned_response_findings.unresolved.involving(ids)
           .pluck(:canned_response_id, :other_canned_response_id, :kind)
           .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(a, b, kind), acc|
      [a, b].compact.each { |id| acc[id] << kind }
    end
  end

  def warning_parts(response, kinds)
    partes = Array(kinds).uniq.map { |k| AUDIT_KINDS[k] }
    largo = response.agent_chars
    partes << "#{largo} caracteres, pasa del tope" if largo > KnowledgeBaseResponseService::MAX_ITEM_CHARS
    partes
  end
end
