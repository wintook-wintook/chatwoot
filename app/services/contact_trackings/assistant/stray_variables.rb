# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F1: VARIABLES ESCRITAS FUERA DE [VARIABLES]
# ================================================================================
# La forma «NOMBRE = A | B» es la correcta, pero el motor solo la guarda dentro de la
# sección [VARIABLES] (ConversationVariables::Definition). Medido el 03/11/2026: un
# agente real (DCI V8.12) tenía sus 6 variables dentro de «[3. NÚCLEO DCI…]», y el
# #10148 de dev seis en un solo renglón separadas por «;». Lo usa VariableChecks (V5)
# y lo replica agentVariables.js para «Pasarlas a Variables».
# ================================================================================

module ContactTrackings::Assistant::StrayVariables
  Definition = ContactTrackings::ConversationVariables::Definition
  # Un nombre de variable: en MAYÚSCULAS y de 3 o más (como se escriben en los agentes).
  # «Si CARRERA=VACÍO» lo es; «utm=abc» o «a=b» de una liga, no.
  UPPER_NAME = '[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]{2,}'
  # «* CIERRE_ENVIADO = NO | SI»: una declaración, con al menos una barra.
  STRAY_RE = /\A[ \t]*(?:[-*•][ \t]*)?(#{UPPER_NAME})[ \t]*=[ \t]*([^|\n]*\|.*?)[ \t]*\z/o
  # Cada declaración de un renglón: «CARRERA=VACÍO|valor; LIGA=NO|SÍ.» trae dos.
  STRAY_PART_RE = /(?<![\p{L}\d_])(#{UPPER_NAME})[ \t]*=[ \t]*[^;|\n]*\|/o

  module_function

  # Los renglones (desde 1) que están dentro de [VARIABLES], sin el rótulo.
  def section_line_numbers(lineas)
    dentro = false
    lineas.each_with_index.with_object(Set.new) do |(linea, indice), numeros|
      if linea.match?(Definition::HEADER_RE)
        dentro = true
      elsif Definition.header?(linea)
        dentro = false
      elsif dentro
        numeros << (indice + 1)
      end
    end
  end

  # Los renglones que declaran una variable fuera de [VARIABLES] (los usa también la
  # pantalla, para «Pasarlas a Variables»).
  def lines(text)
    lineas = text.to_s.split("\n", -1)
    dentro = section_line_numbers(lineas)
    lineas.each_with_index.filter_map do |linea, indice|
      numero = indice + 1
      next if dentro.include?(numero) || !linea.match?(STRAY_RE)

      { line: numero, names: linea.scan(STRAY_PART_RE).flatten.uniq, wrote: linea.strip }
    end
  end
end
