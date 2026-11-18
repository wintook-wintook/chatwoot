# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — LA RED SIN IA: PARTIR POR BLOQUES SIN PERDER NADA
# ================================================================================
# Dos casos del banco de pruebas (dev.wintook.com, 17/11/2026) que la IA no resolvió ni
# en la segunda vuelta:
#   · una parte que conserva todo pero se pasa del tope («Alta de nueva empresa en
#     Microsip»: 2,745);
#   · condensar una que se pasaba por 67 caracteres y quitarle la mitad («Configuración de
#     cálculo», cuenta 318: 6 de 12 frases perdidas).
# Aquí no se reescribe nada: el texto se corta en límites de bloque (párrafo; si un
# bloque no cabe, por renglón; si un renglón no cabe, por frase) y cada trozo extra se
# llama «<nombre> (continuación)», que conserva el prefijo de grupo del nombre.
# ================================================================================

module CannedResponses::Fix::Rebalance
  module_function

  # parts → [partes nuevas, { índice viejo => índice nuevo del primer trozo }]
  def call(parts, target)
    nuevas = []
    mapa = {}
    parts.each_with_index do |parte, i|
      mapa[i] = nuevas.size
      nuevas.concat(chunks(parte['short_code'], parte['content'], target))
    end
    [unique_names(nuevas), mapa]
  end

  # La IA a veces ya llamó «(continuación)» a una parte: el trozo nuevo no puede repetir
  # el nombre (short_code es único por cuenta).
  def unique_names(parts)
    usados = Set.new
    parts.map do |parte|
      nombre = parte['short_code']
      n = 1
      nombre = "#{parte['short_code']} (#{n += 1})" until usados.add?(nombre.downcase)
      parte.merge('short_code' => nombre)
    end
  end

  def chunks(name, content, target)
    return [{ 'short_code' => name, 'content' => content }] if CannedResponse.agent_text(name, content).size <= target

    trozos = pack(pieces(content, target - name.size - 20), target - name.size - 20)
    trozos.each_with_index.map do |texto, i|
      nombre = if i.zero?
                 name
               else
                 (trozos.size > 2 ? "#{name} (continuación #{i})" : "#{name} (continuación)")
               end
      { 'short_code' => nombre, 'content' => texto }
    end
  end

  # Bloques que caben solos en `budget`, en orden.
  def pieces(content, budget)
    KnowledgeBase::SectionFit.blocks_of(content).flat_map { |b| fit(b, budget, ["\n", /(?<=[.!?;:])\s+/, ' ']) }
  end

  def fit(texto, budget, separadores)
    return [texto] if texto.size <= budget || separadores.empty?

    sep, *resto = separadores
    union = sep.is_a?(String) ? sep : ' '
    pack(texto.split(sep).reject(&:empty?).flat_map { |t| fit(t, budget, resto) }, budget, union)
  end

  # Junta trozos consecutivos mientras quepan.
  def pack(trozos, budget, union = "\n\n")
    trozos.each_with_object([]) do |t, out|
      if out.any? && (out.last.size + union.size + t.size) <= budget
        out[-1] = "#{out.last}#{union}#{t}"
      else
        out << t
      end
    end
  end
end
