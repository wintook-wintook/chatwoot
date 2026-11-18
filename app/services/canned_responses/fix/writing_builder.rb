# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — «MEJORAR REDACCIÓN»
# ================================================================================
# Corrige SOLO lo que señaló la auditoría (CannedResponseFinding kind writing:
# ortografía, incompleta, confusa, numeración, tono) y faltas de ortografía evidentes. No
# reescribe: el candado `changes` avisa si cambió más de Checks::MAX_CHANGE del texto, y
# eso cuenta como problema para la segunda vuelta («vuelve a partir del original»).
# El nombre se puede corregir (ortografía) pero no pierde su prefijo de grupo.
# Sin vectores: el texto casi no cambia, la búsqueda no se mueve.
# ================================================================================

class CannedResponses::Fix::WritingBuilder < CannedResponses::Fix::AiBuilder
  SYSTEM = <<~PROMPT
    Corriges la redacción de una respuesta predefinida que un agente de IA usa para contestar a clientes.
    Corrige SOLO los problemas de la lista y faltas de ortografía evidentes. Todo lo demás queda IGUAL:
    las mismas palabras, el mismo orden, los mismos saltos de línea, listas, negritas, ligas, emojis y
    variables {{…}}. No resumas, no agregues información, no cambies el estilo.
    - incompleta: complétala solo si el dato está en el mismo texto; si no, deja la frase y no inventes.
    - tono: usa la forma (tú o usted) que más se usa en el texto.
    - numeracion: numera en orden sin cambiar el contenido de cada punto.
    Los datos (montos, fechas, teléfonos, ligas, claves, cantidades) se copian literalmente.
    Corrige también el nombre solo si tiene una falta de ortografía.
    Contesta SOLO este JSON:
    {"short_code":"nombre","content":"texto corregido","changes":[{"before":"…","after":"…"}]}
  PROMPT

  private

  def system = SYSTEM

  def embeddings? = false

  def response = @context.sources.first

  def issues = Array(@context.input['issues'])

  def user
    lista = issues.map { |i| "- #{i['type']}: «#{i['quote']}»#{" → #{i['suggestion']}" if i['suggestion'].present?}" }.join("\n")
    "#{response_block(response)}\n\n## Problemas a corregir\n#{lista.presence || '(revisa ortografía)'}\n\n" \
      "## Datos que no pueden cambiar\n#{hard_data_list}"
  end

  def parse(out)
    return nil unless out.is_a?(Hash) && text(out['content']).present?

    nombre = text(out['short_code']).presence || response.short_code
    { 'action' => 'rewrite', 'parts' => [{ 'short_code' => nombre.first(255), 'content' => text(out['content']) }],
      'questions' => [], 'issues' => issues,
      'changes' => Array(out['changes']).select { |c| c.is_a?(Hash) }.first(20) }
  end

  def problems(revisada)
    out = super
    if revisada.dig('changes', 'ok') == false
      cambio = Array(revisada.dig('changes', 'parts')).compact.pluck('ratio').max.to_f
      out << "Cambiaste #{(cambio * 100).round}% del texto. Vuelve a partir del original y cambia SOLO lo señalado."
    end
    out
  end
end
