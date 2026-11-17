# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — «NO TENGO ESE DATO»: EL MOTOR DICE EL HECHO, EL PROMPT LA NARRATIVA
# ================================================================================
# 16/11/2026 (cuenta 1128, conv 300): el motor le dictaba al modelo cómo decirlo («aclara que
# no tienes el procedimiento exacto… ofrece pasarlo con un asesor») y esa frase le ganaba al
# Entrenamiento. Ahora el motor solo:
#   · dice el hecho que sí conoce (qué encontró, o que no encontró nada),
#   · prohíbe inventar o completar (eso no es narrativa, es fidelidad),
#   · y manda a la sección [SIN INFORMACIÓN] del Entrenamiento, que es donde cada agente
#     decide qué se le dice al cliente (WhatsApp, asesor, pedir un correo…).
# Juzgar si lo encontrado contesta la pregunta es del modelo: el motor no lo adivina.
# Sin esa sección (agentes viejos) queda una indicación neutral; sin Entrenamiento, la de
# siempre.
# ================================================================================

module ContactTrackings::MissingAnswer
  SECTION = 'SIN INFORMACIÓN'
  SECTION_RE = /^\s*\[\s*SIN\s+INFORMACI[OÓ]N\s*\]/i

  NO_INVENT = 'Si la información no contesta lo que preguntaron, no lo expliques, no lo inventes ni lo completes ' \
              'con lo que sepas: una respuesta honesta que no resuelve es mejor que una inventada.'
  WITH_SECTION = "Para decirle al cliente que no tienes ese dato, sigue la sección [#{SECTION}] de tus " \
                 'instrucciones, con sus palabras.'.freeze
  WITHOUT_SECTION = 'Para decirle al cliente que no tienes ese dato, hazlo en una frase breve y sigue lo que tus ' \
                    'instrucciones indiquen para ese caso.'
  DEFAULT = 'Si la fuente no cubre exactamente lo que preguntaron, dilo de frente: explica brevemente qué sí cubre ' \
            'la documentación, aclara que no tienes el procedimiento exacto para su caso y ofrece pasarlo con un ' \
            'asesor. Una respuesta honesta que no resuelve es mejor que una inventada que parece resolver.'

  NOTHING_FOUND = 'No encontré nada en tus fuentes para este mensaje.'

  module_function

  # Regla para el turno. prompt: el Entrenamiento del agente (nil/vacío = sin Entrenamiento).
  def rule(prompt)
    return DEFAULT if prompt.to_s.strip.empty?

    "#{NO_INVENT} #{section?(prompt) ? WITH_SECTION : WITHOUT_SECTION}"
  end

  def section?(prompt)
    prompt.to_s.match?(SECTION_RE)
  end
end
