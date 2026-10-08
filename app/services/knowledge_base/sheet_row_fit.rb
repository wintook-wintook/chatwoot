# frozen_string_literal: true

# ================================================================================
# Una fila de hoja (modo FAQ) dentro del tope de caracteres, sin perder columnas
# ================================================================================
# Las filas se vectorizan como «columna: valor» por línea y le llegan al modelo con un
# tope por fila (KnowledgeBaseResponseService::MAX_ITEM_CHARS). Antes se cortaba el
# texto al final: todo lo que quedara después del carácter 2000 desaparecía sin aviso.
#
# Medido el 01/10/2026 (cuenta 568, CATALOGO DE CARRERAS): «imagen promocion» es la
# penúltima columna, detrás de un perfil de egreso de ~600 caracteres. En 3 de 10
# carreras la fila pasaba de 2000 y el modelo nunca veía el nombre de la imagen, así que
# no podía mandarla, aunque la regla del Entrenamiento estaba bien.
#
# Ahora se acortan primero los valores LARGOS, todos al mismo largo máximo, el mayor que
# quepa. Los campos cortos (precios, becas, nombres de archivo) llegan siempre enteros.
# Una celda con saltos de línea (un perfil en viñetas) cuenta como UN campo: si no, sus
# viñetas parecen columnas cortas y el recorte se reparte sobre los campos de verdad.
# ================================================================================

module KnowledgeBase::SheetRowFit
  # Por debajo de esto un campo ya no dice nada: si ni así cabe, se corta el final.
  MIN_FIELD = 60
  ELLIPSIS = '…'
  # «columna: valor». Una viñeta o una línea de texto suelta es continuación de la anterior.
  FIELD_START = /\A[^\s•\-*][^:\n]{0,80}:\s/

  module_function

  def call(content, max)
    text = content.to_s
    return text if text.size <= max

    fields = fields_of(text)
    cap = field_cap(fields, max)
    return text.truncate(max) if cap.nil?

    fields.map { |field| field.size > cap ? "#{field[0, cap - 1].rstrip}#{ELLIPSIS}" : field }.join("\n")
  end

  def fields_of(text)
    text.split("\n").each_with_object([]) do |line, fields|
      if fields.empty? || line.match?(FIELD_START)
        fields << line.dup
      else
        fields.last << "\n" << line
      end
    end
  end

  # El largo máximo por campo más alto con el que la fila entera cabe en `max`.
  def field_cap(fields, max)
    return nil if fitted_size(fields, MIN_FIELD) > max

    (MIN_FIELD..fields.map(&:size).max).bsearch { |cap| fitted_size(fields, cap + 1) > max }
  end

  def fitted_size(fields, cap)
    fields.sum { |field| [field.size, cap].min } + fields.size - 1
  end
end
