# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — «CONTIENE LA PALABRA»: columna~? (21/11/2026, Seminuevos Valera)
# ================================================================================
# Con COLOR=? el cliente tiene que nombrar el valor completo: «gris» trae GRIS pero no
# GRIS PLATA ni GRIS OBS, y «café» no trae CAFÉ ARENA. Es a propósito para nombres largos
# (Universidad: «social» de «servicio social» no es «Trabajo Social», ver ShortNames), así
# que «=» no cambia. Con «~» la columna es una FAMILIA de valores:
#
#   {{hoja_buscar: INVENTARIO | COLOR~? | MARCA, TIPO, COLOR}}
#     «¿tienes algo gris?» → GRIS, GRIS PLATA, GRIS OBS    «café» → CAFÉ ARENA
#
# · ~? : las palabras del mensaje del cliente (el más reciente que traiga alguna) que salen
#        en alguna celda de la columna. Solo del cliente: las del agente son los colores que
#        él ya listó, no lo que se pide.
# · ~gris,azul : valores fijos, igual.
# Una celda cumple si tiene alguna de esas palabras completa (sin acentos ni mayúsculas).
# Palabras de 3+ letras que no sean de relleno (de, en, la, con…).
# ================================================================================
module ContactTrackings::SheetLookup::Contains
  OP = '~'
  FILLER = %w[con del las los para por que una uno unos unas sin mas muy].freeze

  private

  def contains_values(column, rows)
    vocabulario = rows.flat_map { |row| words(cell(row, column)) }.to_set
    return in_vocabulary(@text, vocabulario) if @text

    @conversation ? contains_in_messages(vocabulario) : []
  end

  # Del mensaje del cliente más reciente que traiga alguna palabra de la columna.
  def contains_in_messages(vocabulario)
    recent_messages.select(&:incoming?).each do |msg|
      found = in_vocabulary(msg.content, vocabulario)
      next if found.empty?

      @mentioned_in = [@mentioned_in, msg.id].compact.max
      return found
    end
    []
  end

  # El texto con los valores de los sinónimos que nombra (ver SheetSynonyms). Lo usan «~?» y,
  # en SheetLookup#mentions?, «=?».
  def with_synonyms(text)
    return text if @synonyms.blank?

    (@expanded ||= {})[text] ||= ContactTrackings::SheetSynonyms.expand(text, @synonyms)
  end

  def in_vocabulary(text, vocabulario)
    words(with_synonyms(text)).select { |w| vocabulario.include?(w) }.uniq
  end

  def contains_word?(wanted, value)
    celda = words(value)
    wanted.any? { |w| celda.include?(ContactTrackings::SheetNumbers.fold(w)) }
  end

  def words(text)
    ContactTrackings::SheetNumbers.fold(text).scan(/[[:alnum:]]+/).reject { |w| w.size < 3 || FILLER.include?(w) }
  end
end
