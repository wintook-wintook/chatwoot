# frozen_string_literal: true

# ================================================================================
# feat/plantillas_variables_chatwoot F9.1 — LAS VARIABLES DE UNA PLANTILLA
# ================================================================================
# Una plantilla usa números ({{1}}) o nombres ({{edad}}), nunca los dos: el formato es de toda
# la plantilla. Lo que esté entre llaves cuenta como variable; lo que no sea número ni nombre
# válido (minúsculas, números y _, empezando con letra) es un error. La réplica en el navegador
# está en dashboard/helper/whatsappTemplateValidator.js.
# ================================================================================
module Whatsapp::TemplateVariables
  TOKEN = /\{\{\s*([^{}]*?)\s*\}\}/
  NUMBER = /\A\d+\z/
  NAME = /\A[a-z][a-z0-9_]*\z/

  module_function

  # Todas, con repetidas y en orden de aparición.
  def tokens(text)
    text.to_s.scan(TOKEN).flatten
  end

  # Las distintas, por orden de aparición: los ejemplos de una plantilla con nombres van así.
  def names(text)
    tokens(text).uniq.grep(NAME)
  end

  def numbers(text)
    tokens(text).grep(NUMBER).map(&:to_i)
  end

  # Lo que Meta rechaza en un cuerpo: números con huecos, y una variable en la orilla (basta
  # un punto después para que pase).
  def body_errors(text)
    limpio = text.to_s.strip
    errores = sequence_errors(numbers(limpio))
    errores << 'Mensaje: no puede empezar con una variable' if limpio.match?(/\A#{TOKEN}/o)
    errores << 'Mensaje: no puede terminar con una variable (agrega un punto o texto después)' if limpio.match?(/#{TOKEN}\z/o)
    errores
  end

  # {{1}} {{3}} → falta {{2}}.
  def sequence_errors(nums)
    return [] if nums.empty?

    distintos = nums.uniq.sort
    return ['Mensaje: la primera variable debe ser {{1}}'] if distintos.first != 1

    falta = ((1..distintos.max).to_a - distintos).first
    falta ? ["Mensaje: falta la variable {{#{falta}}}"] : []
  end

  # Los errores de formato de los textos de una plantilla (encabezado y cuerpo juntos).
  def format_errors(*texts)
    todas = texts.flat_map { |text| tokens(text) }
    invalida = todas.find { |v| !v.match?(NUMBER) && !v.match?(NAME) }
    errores = []
    errores << "Variables: {{#{invalida}}} no es válida (usa minúsculas, números y _, empezando con letra)" if invalida
    errores << 'Variables: no mezcles números con nombres (usa solo {{1}} o solo {{nombre}})' if mixed?(todas)
    errores
  end

  def mixed?(todas)
    todas.grep(NUMBER).any? && todas.grep(NAME).any?
  end

  # F9.2 — ¿La plantilla de message_templates va con nombres? Lo dice Meta; si su lista no lo
  # trae, se ve en el texto. Un error aquí la manda como numerada y Meta la rechaza.
  def named_template?(template)
    formato = template.to_h['parameter_format']
    return formato == 'NAMED' if formato.present?

    Array(template.to_h['components']).any? { |component| names(component['text']).any? }
  end
end
