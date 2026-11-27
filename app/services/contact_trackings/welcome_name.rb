# frozen_string_literal: true

# ================================================================================
# [NOMBRE] EN LA BIENVENIDA (20/11/2026, Seminuevos Valera)
# ================================================================================
# «Hola, [NOMBRE] 👋» → «Hola, Juan 👋», con el primer nombre del contacto. Si el contacto
# no trae un nombre que se pueda usar (teléfono, emoji, «WhatsApp User»), [NOMBRE] se quita
# con su coma. No es {{nombre}}: eso es un archivo del agente (AgentAttachments).
# ================================================================================

module ContactTrackings::WelcomeName
  NAME_RE = /\[[ \t]*NOMBRE[ \t]*\]/i
  # Lo que trae un contacto sin nombre de verdad: no se le saluda con eso.
  NOT_A_NAME = %w[whatsapp user usuario cliente contacto unknown desconocido telegram facebook instagram
                  messenger sin nombre null none test prueba].freeze

  module_function

  # [NOMBRE] → el primer nombre del contacto; sin nombre usable se quita con su coma o espacio.
  def personalize(text, contact)
    return text unless text.to_s.match?(NAME_RE)

    nombre = first_name(contact)
    return text.gsub(NAME_RE, nombre) if nombre

    text.split("\n", -1).map { |linea| linea.match?(NAME_RE) ? without_name(linea) : linea }.join("\n")
  end

  # «Hola, [NOMBRE].» → «Hola.» · «[NOMBRE], bienvenido» → «Bienvenido»
  def without_name(linea)
    limpia = linea.gsub(/[ \t]*,?[ \t]*#{NAME_RE.source}/io, '').sub(/\A([ \t]*)[,.;:][ \t]*/, '\\1').gsub(/ {2,}/, ' ')
    limpia.sub(/\A([ \t]*)(\p{Ll})/) { "#{Regexp.last_match(1)}#{Regexp.last_match(2).upcase}" }
  end

  # «juan carlos pérez» → «Juan». nil si no parece un nombre: sin letras, con dígitos o
  # emojis, una sola letra o palabras de relleno («WhatsApp User»).
  def first_name(contact)
    palabra = contact&.name.to_s.squish.split.first.to_s
    return nil unless palabra.match?(/\A\p{L}[\p{L}'’-]{1,24}\z/)
    return nil if NOT_A_NAME.include?(I18n.transliterate(palabra).downcase)

    palabra.downcase.sub(/\A\p{Ll}/, &:upcase)
  end
end
