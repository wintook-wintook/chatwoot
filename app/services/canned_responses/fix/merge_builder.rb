# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — «UNIR EN UNA» (duplicadas o que se solapan)
# ================================================================================
# La IA junta las dos con TODO lo que tenga cualquiera de las dos, sin repetir. Se queda
# la que Fix::Context#target elige (categoría, prefijo de grupo, antigüedad): la primera
# parte lleva su nombre y su id; la otra predefinida se elimina al aplicar.
# Si junta pasa del tope, la IA puede entregar varias partes por tema; lo que siga
# pasando lo parte Fix::Rebalance por bloques, como en «pasa del tope».
# Candados: los datos y las frases de las dos (unión), y la búsqueda con preguntas de
# las dos.
# ================================================================================

class CannedResponses::Fix::MergeBuilder < CannedResponses::Fix::AiBuilder
  SYSTEM = <<~PROMPT
    Unes dos respuestas predefinidas que tratan lo mismo en UNA sola. Un agente de IA busca la más
    parecida a la pregunta del cliente y recibe de cada una «nombre: contenido» hasta 2,000 caracteres.
    - Conserva TODA la información de las dos, sin repetirla. Si dicen lo mismo con otras palabras,
      quédate con la versión más clara y completa.
    - Copia literalmente cada dato de la lista de datos obligatorios.
    - Conserva el formato útil (listas, negritas, ligas, emojis, variables {{…}}) y el idioma.
    - Si las dos empiezan con preguntas de cliente de ejemplo (sirven para la búsqueda), conserva
      las de las dos sin repetir.
    - La primera parte se llama exactamente «{{name}}». Si todo junto pasa de 1,600 caracteres
      («nombre: contenido»), divide en partes por tema; las demás se llaman «{{name}} — <temas>».
    - No inventes, no agregues saludos.
    Preguntas de prueba: 2 por parte, como las escribiría un cliente; "part" es el índice de la parte.
    Contesta SOLO este JSON:
    {"reason":"una línea","parts":[{"short_code":"…","content":"…"}],"questions":[{"text":"…","part":0}]}
  PROMPT

  private

  def system = SYSTEM.gsub('{{name}}', @context.target.short_code)

  def user
    otra = @context.other
    "#{response_block(@context.target, 'Respuesta que se conserva')}\n\n#{response_block(otra, 'Respuesta que se une')}\n\n" \
      "## Datos obligatorios\n#{hard_data_list}"
  end

  def parse(out)
    return nil unless out.is_a?(Hash)

    partes = Array(out['parts']).filter_map do |p|
      next unless p.is_a?(Hash) && text(p['content']).present?

      { 'short_code' => text(p['short_code']).first(255), 'content' => text(p['content']) }
    end
    return nil if partes.empty?

    partes[0]['short_code'] = @context.target.short_code
    preguntas = Array(out['questions']).filter_map do |q|
      next unless q.is_a?(Hash) && text(q['text']).present? && q['part'].to_i.between?(0, partes.size - 1)

      { 'text' => text(q['text']), 'part' => q['part'].to_i }
    end
    { 'action' => 'merge', 'reason' => text(out['reason']), 'parts' => partes, 'questions' => preguntas.first(10),
      'target_id' => @context.target.id, 'removed_id' => @context.other&.id, 'lost_groups' => @context.lost_groups }
  end

  # Lo que siga pasando de TARGET_CHARS se parte por bloques, sin reescribir.
  def finish(propuesta, revisada)
    objetivo = CannedResponses::Fix::Proposer::TARGET_CHARS
    return super if revisada.dig('size', 'parts').all? { |p| p['chars'] <= objetivo }

    partes, mapa = CannedResponses::Fix::Rebalance.call(propuesta['parts'], objetivo)
    preguntas = propuesta['questions'].map { |q| q.merge('part' => mapa[q['part']]) }
    nueva = propuesta.merge('parts' => partes, 'questions' => preguntas, 'fallback' => 'rebalanced')
    super(nueva, check(nueva))
  end
end
