# frozen_string_literal: true

# ================================================================================
# @knowledge_sources — TROCEAR EL TEXTO EN CHUNKS
# ================================================================================
# Servicio: Wordpress::Chunker
# Descripción: Parte el texto limpio de una entrada en los trozos que se vectorizan.
#
# LOS MISMOS NÚMEROS QUE GOOGLE DOCS:
#   4.000 caracteres con 400 de solape. No se inventan otros a propósito: un corpus
#   con chunks de tamaños distintos según la fuente da resultados de similitud que
#   no se pueden comparar entre sí, y el motor los mezcla en la misma búsqueda.
#
# POR QUÉ CORTA POR PÁRRAFO Y NO POR CARÁCTER:
#   Cortar en el carácter 4.000 parte una frase al medio, y las dos mitades quedan
#   como embeddings de algo que nadie escribió. Se corta en el último salto de
#   párrafo antes del límite; solo si un párrafo solo ya excede el tamaño se corta
#   duro, porque ahí no hay alternativa.
#
# EL SOLAPE:
#   Los últimos 400 caracteres de un chunk abren el siguiente. Sirve para que una
#   idea que cae justo en el corte siga siendo encontrable desde los dos lados.
# ================================================================================

class Wordpress::Chunker
  CHUNK_SIZE = 4000
  CHUNK_OVERLAP = 400
  # Un trozo más corto que esto no se guarda: un pie de página o una firma suelta
  # no responden ninguna pregunta y solo ensucian los resultados.
  MIN_CHUNK = 40

  def self.call(text) = new(text).call

  def initialize(text)
    @text = text.to_s.strip
  end

  def call
    return [] if @text.length < MIN_CHUNK
    return [@text] if @text.length <= CHUNK_SIZE

    chunks = []
    cursor = 0

    while cursor < @text.length
      corte = break_point(cursor)
      chunks << @text[cursor...corte].strip
      break if corte >= @text.length

      cursor = [corte - CHUNK_OVERLAP, cursor + 1].max
    end

    chunks.select { |chunk| chunk.length >= MIN_CHUNK }
  end

  private

  # El final del chunk que empieza en `cursor`: el último salto de párrafo dentro
  # del tamaño, o el corte duro si no hay ninguno.
  def break_point(cursor)
    limite = cursor + CHUNK_SIZE
    return @text.length if limite >= @text.length

    # Se busca hacia atrás desde el límite, pero no antes de la mitad del chunk:
    # respetar un párrafo no puede costar chunks de 200 caracteres.
    piso = cursor + (CHUNK_SIZE / 2)
    corte = @text.rindex("\n", limite)

    corte && corte > piso ? corte : limite
  end
end
