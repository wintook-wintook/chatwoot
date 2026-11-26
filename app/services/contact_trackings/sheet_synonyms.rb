# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — SINÓNIMOS DECLARADOS POR AGENTE (25/11/2026)
# ================================================================================
# La hoja dice «PICK UP» y el cliente escribe «picop», «pik up», «troca» o «pickups»; dice
# «SUV» y escriben «suvs». Antes solo empataban las variantes de espacios y guiones
# («pickup», «pick-up»). Cada agente declara las suyas en su prompt:
#
#   [SINÓNIMOS]
#   PICK UP = picop, pik up, troca, camioneta de carga
#   SUV = camioneta suv
#
# Si el cliente dice un sinónimo (o el valor o un sinónimo en plural: «pickups», «suvs»), para
# {{hoja_buscar}} con «=?» o «~?» cuenta como si hubiera dicho el valor de la izquierda.
#
# Solo cambia algo en los agentes que tienen la sección; los plurales también se toleran
# SOLO en lo declarado: en general «unos» no es «Uno» ni «derechos» es la carrera «Derecho».
# No se toleran faltas de ortografía sueltas: con valores cortos («Rio», «Uno», «Note»)
# confunden unos con otros. Si una falta es común, se declara como sinónimo.
# ================================================================================
module ContactTrackings::SheetSynonyms
  SECTION_RE = /^[ \t]*\[[ \t]*SIN[OÓ]NIMOS[ \t]*\][ \t]*\n(.*?)(?=^[ \t]*\[[^\]\n]+\]|\z)/mi
  LINE_RE = /\A[ \t]*-?[ \t]*([^=\n]+?)[ \t]*=[ \t]*(.+?)[ \t]*\z/

  module_function

  # { 'PICK UP' => ['picop', 'pik up', …] } de la sección [SINÓNIMOS] del prompt; {} sin ella.
  def parse(prompt)
    body = prompt.to_s[SECTION_RE, 1]
    return {} if body.blank?

    body.lines.each_with_object({}) do |linea, mapa|
      valor, lista = linea.strip.match(LINE_RE)&.captures
      next if valor.blank?

      mapa[valor] = (mapa[valor].to_a + lista.split(',').map(&:strip).compact_blank).uniq
    end
  end

  # El texto con el valor agregado al final por cada sinónimo (o plural declarado) que nombra:
  # «¿tienen picop?» → «¿tienen picop? PICK UP».
  def expand(text, synonyms)
    return text.to_s if synonyms.blank?

    extra = synonyms.filter_map do |valor, lista|
      valor if [valor, *lista].any? { |termino| names?(text, termino) }
    end
    extra.empty? ? text.to_s : "#{text} #{extra.join(' ')}"
  end

  # Como SheetNumbers.names?, pero acepta el término en plural («pickups», «suvs», «sedanes»).
  def names?(text, termino)
    parts = ContactTrackings::SheetNumbers.fold(termino).scan(/[[:alnum:]]+/)
    return false if parts.empty?

    cuerpo = parts.map { |p| Regexp.escape(p) }.join('[\s\-_.]*')
    ContactTrackings::SheetNumbers.fold(text).match?(/(?<![[:alnum:]])#{cuerpo}(?:e?s)?(?![[:alnum:]])/)
  end
end
