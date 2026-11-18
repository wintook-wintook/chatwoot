# frozen_string_literal: true

# proyecto@arreglar_predefinidas F2 — cuánto cambió un texto, por palabras: la parte de
# las palabras que no quedaron en la subsecuencia común más larga (0.0 igual, 1.0 todo
# distinto). «Mejorar redacción» y «Resolver» deben cambiar poco; si la IA reescribió de
# más, el candado `changes` lo avisa.
module CannedResponses::Fix::Diff
  module_function

  MAX_WORDS = 1500

  def ratio(before, after)
    a = words(before)
    b = words(after)
    return 0.0 if a.empty? && b.empty?

    1.0 - ((2.0 * lcs(a, b)) / (a.size + b.size))
  end

  # Cuántas palabras entraron o salieron.
  def changed_words(before, after)
    a = words(before)
    b = words(after)
    a.size + b.size - (2 * lcs(a, b))
  end

  def words(texto) = texto.to_s.split(/\s+/).reject(&:empty?).first(MAX_WORDS)

  # Longitud de la subsecuencia común más larga, con dos renglones de memoria.
  def lcs(left, right)
    previo = Array.new(right.size + 1, 0)
    left.each do |x|
      actual = [0]
      right.each_with_index do |y, j|
        actual << (x == y ? previo[j] + 1 : [previo[j + 1], actual[j]].max)
      end
      previo = actual
    end
    previo.last
  end
end
