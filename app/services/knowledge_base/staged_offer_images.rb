# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — LA OFERTA ENTREGADA LLEVA SU IMAGEN
# ================================================================================
# Ver KnowledgeBase::StagedOffers. La ficha trae cada oferta con su imagen en el renglón
# siguiente («- Primera beca: …» + «{{tsbeca1mat}}»). Medido el 13/11/2026 (dev conv 278,
# gpt-4o-mini): dio la primera y la segunda beca completas sin escribir ninguna imagen.
#
# Si la respuesta entrega una oferta —trae algo que SOLO esa oferta tiene en la ficha: su
# cupón «l0601202611», un porcentaje o un monto que no está en las otras— y no trae su
# {{imagen}}, se agrega al final. Así no depende de que el modelo se acuerde.
# ================================================================================

module KnowledgeBase::StagedOfferImages
  IMAGE_RE = /\{\{\s*([\w-]+)\s*\}\}/
  NUMBER_RE = /[a-z]*\d[\d.,]*\d%?|[a-z]*\d%?/i

  module_function

  # context: la información que vio el modelo (ya sin las ofertas que no tocan).
  def call(reply, context, definition)
    rotulos = KnowledgeBase::StagedOffers.staged_labels(definition)
    return reply if reply.blank? || rotulos.empty?

    faltan = missing(reply, offer_blocks(context.to_s, rotulos))
    return reply if faltan.empty?

    Rails.logger.info "[KBase] 🖼️ Oferta entregada sin su imagen → se agrega #{faltan.join(', ')}"
    "#{reply.rstrip}\n#{faltan.map { |nombre| "{{#{nombre}}}" }.join("\n")}"
  end

  def missing(reply, bloques)
    bloques.flat_map do |bloque|
      next [] unless delivered?(reply, bloque, bloques - [bloque])

      bloque[:images].reject { |nombre| reply.match?(/\{\{\s*#{Regexp.escape(nombre)}\s*\}\}/i) }
    end.uniq
  end

  # [{ text:, images: [] }] por cada renglón de oferta y lo que le sigue.
  def offer_blocks(context, rotulos)
    bloques = []
    actual = nil
    context.each_line do |line|
      if rotulos.include?(KnowledgeBase::StagedOffers.line_label(line).to_s)
        actual = { text: +'', images: [] }
        bloques << actual
      elsif actual && KnowledgeBase::StagedOffers.starts_new_block?(line)
        actual = nil
      end
      next if actual.nil?

      actual[:text] << line
      actual[:images] |= line.scan(IMAGE_RE).flatten
    end
    bloques
  end

  def delivered?(reply, bloque, otros)
    return false if bloque[:images].empty?

    propios = numbers(bloque[:text]) - otros.flat_map { |o| numbers(o[:text]).to_a }
    propios.intersect?(numbers(reply))
  end

  # «$ 1,990.00» → «1,990.00»; «38%», «l0601202611». Sin las {{imágenes}}.
  def numbers(texto)
    texto.gsub(IMAGE_RE, ' ').gsub(/\$\s*/, '').scan(NUMBER_RE).to_set(&:downcase)
  end
end
