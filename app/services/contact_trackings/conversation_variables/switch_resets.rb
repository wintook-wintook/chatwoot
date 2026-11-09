# frozen_string_literal: true

# Lo que el Entrenamiento pide cambiar junto con una variable cuando pasa a otro valor, leído
# de su propia regla: la línea con «NOMBRE=la nueva» (o «el nuevo»). En el AGENTE ESCUELA:
# «Si nombra otra carrera: CARRERA=la nueva…, PRECIO_DADO=NO, SIGUIENTE_OFERTA=PRIMERA_BECA».
#
# Lo usa KnowledgeBaseResponseService#follow_switch: si el motor cambia la carrera, también
# reinicia el precio y la beca. Medido el 06/11/2026 (cuenta 1128, conv 154): sin esto, al pasar
# a Trabajo Social el bot dio la segunda beca sin haber dado la primera.
module ContactTrackings::ConversationVariables::SwitchResets
  PAIR_RE = /(?<![A-Z_])([A-Z][A-Z0-9_]*)[ \t]*=[ \t]*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ0-9_]*)(?![[:alnum:]_])/

  module_function

  # {NOMBRE => valor} de las otras variables declaradas en esa línea; {} si no hay regla.
  def for(tracking, nombre)
    definition = ContactTrackings::ConversationVariables.definition_for(tracking)
    linea = rule_line(tracking, nombre)
    return {} if definition.blank? || linea.nil?

    linea.scan(PAIR_RE).each_with_object({}) do |(otro, valor), out|
      var = definition.variable(otro)
      next if var.nil? || ContactTrackings::ConversationVariables.key(otro) == ContactTrackings::ConversationVariables.key(nombre)

      value = definition.coerce(otro, valor)
      out[var[:name]] = value if value
    end
  end

  def rule_line(tracking, nombre)
    regla = /(?<![A-Z_])#{Regexp.escape(nombre)}[ \t]*=[ \t]*(?:la|el)[ \t]+nuev[ao]/i
    tracking.complementary_prompt.to_s.lines.find { |linea| linea.match?(regla) }
  end
end
