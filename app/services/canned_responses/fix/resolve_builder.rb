# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — «RESOLVER» UNA CONTRADICCIÓN
# ================================================================================
# Con lo que eligió la persona (Fix::Resolution): en cada predefinida de origen —las dos
# del hallazgo y las que se corrigen de paso porque también tienen el dato equivocado—
# se cambia el dato equivocado por el correcto y nada más. Los nombres no cambian.
# Candados: `resolved` (el equivocado ya no está en ninguna, el correcto sí), `data`
# (todo lo demás sigue) y `changes` (no se reescribió de más).
# ================================================================================

class CannedResponses::Fix::ResolveBuilder < CannedResponses::Fix::AiBuilder
  SYSTEM = <<~PROMPT
    Corriges respuestas predefinidas que se contradicen. Para cada contradicción te digo cuál es el dato
    CORRECTO. En cada respuesta que reciba:
    - Reemplaza el dato equivocado por el correcto y ajusta solo la frase necesaria para que se lea bien.
    - Si una respuesta no tiene el dato equivocado, devuélvela igual.
    - Todo lo demás queda IGUAL: mismas palabras, orden, formato, ligas, emojis y variables {{…}}.
    - Copia literalmente los datos de la lista de datos que no pueden cambiar.
    Contesta SOLO este JSON, con todas las respuestas que recibiste:
    {"reason":"una línea","responses":[{"id":123,"content":"contenido corregido"}]}
  PROMPT

  private

  def system = SYSTEM

  def embeddings? = false

  def user
    correcciones = @context.resolution.instructions.map do |i|
      "- #{i['topic']}: A dice «#{i['quote_a']}»; B dice «#{i['quote_b']}». Lo correcto: «#{i['correct']}»"
    end.join("\n")
    respuestas = @context.sources.map { |r| "### id #{r.id}\n#{response_block(r)}" }.join("\n\n")
    "## Correcciones\n#{correcciones}\n\n## Respuestas\n#{respuestas}\n\n## Datos que no pueden cambiar\n#{hard_data_list}"
  end

  def parse(out)
    return nil unless out.is_a?(Hash)

    por_id = Array(out['responses']).select { |r| r.is_a?(Hash) }.to_h { |r| [r['id'].to_i, text(r['content'])] }
    return nil if por_id.values.all?(&:blank?)

    partes = @context.sources.map do |r|
      { 'short_code' => r.short_code, 'content' => por_id[r.id].presence || r.content }
    end
    { 'action' => 'resolve', 'reason' => text(out['reason']), 'parts' => partes, 'questions' => [],
      'instructions' => @context.resolution.instructions }
  end

  def problems(revisada)
    out = super
    Array(revisada.dig('changes', 'parts')).each_with_index do |cambio, i|
      next unless cambio && cambio['ratio'] > CannedResponses::Fix::Checks::MAX_CHANGE &&
                  cambio['words'] > CannedResponses::Fix::Checks::MIN_CHANGED_WORDS

      out << "En la respuesta #{i + 1} cambiaste #{(cambio['ratio'] * 100).round}% del texto: cambia solo el dato."
    end
    out
  end
end
