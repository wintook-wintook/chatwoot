# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F2: LOS DATOS FIJOS, BIEN ESCRITOS
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §4.2. El motor sustituye cada
# %NOMBRE% por su valor de [DATOS FIJOS] (ContactTrackings::PromptConstants). Lo que
# no puede sustituir llega tal cual al modelo:
#
#   C1 %ALGO% sin declarar                 rojo: el agente lee «%ALGO%» literal
#   C2 declarado y nunca citado            ámbar
#   C3 pregunta que guarda en una variable ámbar: la regla se escribe, pero el motor
#      que no está en [VARIABLES]          no la guarda
#   C4 nombre que el motor no lee          rojo: «Mi empresa = …» (espacios, minúsculas)
#      o repetido                          o dos EMPRESA (vale la primera)
#   C5 dos con el mismo contenido          ámbar: medido en un agente real, la «liga
#                                          directa» y la «de registro» eran la misma URL
#
# Cada uno lleva su línea; encienden el punto del nodo «Datos fijos».
# ================================================================================

module ContactTrackings::Assistant::ConstantChecks
  Constants = ContactTrackings::PromptConstants
  # «Mi empresa = Kontrolya», «empresa = …»: quiso ser un dato fijo y el nombre no sirve.
  LOOKS_LIKE_RE = /\A[ \t]*(?:[-*•][ \t]*)?([^=\n\[\]]{1,40}?)[ \t]*(?:\([^)\n]*\))?[ \t]*=[ \t]*\S/
  CODES = %i[constant_undeclared constant_unused constant_saves_unknown constant_bad_name
             constant_duplicate constant_same_value].freeze

  module_function

  def check(text, findings:)
    texto = text.to_s
    return unless Constants.section?(texto) || texto.match?(Constants::REF_RE)

    lineas = texto.split("\n", -1)
    constantes = Constants.parse(texto)
    undeclared(lineas, constantes, findings)
    bad_names(texto, findings)
    duplicates(texto, findings)
    return if constantes.empty?

    unused(lineas, constantes, findings)
    saves_unknown(texto, constantes, findings)
    same_value(constantes, findings)
  end

  # C1 — uno por nombre, en la primera línea donde se cita.
  def undeclared(lineas, constantes, findings)
    vistos = Set.new
    lineas.each_with_index do |linea, indice|
      linea.scan(Constants::REF_RE).flatten.each do |nombre|
        next if constantes.key?(nombre) || vistos.include?(nombre)

        vistos << nombre
        findings.add(:blocking, :constant_undeclared,
                     t('constant_undeclared', line: indice + 1, name: nombre,
                                              declared: constantes.keys.join(', ').presence || '—'),
                     line: indice + 1, wrote: linea.strip)
      end
    end
  end

  # C4 — renglones de la sección que quisieron ser un dato fijo.
  def bad_names(texto, findings)
    Constants.section_lines(texto).each do |numero, linea|
      next if linea.match?(Constants::DECL_RE) || linea.match?(Constants::CONTINUATION_RE)

      nombre = linea[LOOKS_LIKE_RE, 1]
      next if nombre.nil?

      findings.add(:blocking, :constant_bad_name,
                   t('constant_bad_name', line: numero, name: nombre.strip, suggestion: suggestion(nombre)),
                   line: numero, wrote: linea.strip)
    end
  end

  def duplicates(texto, findings)
    primeros = {}
    Constants.section_lines(texto).each do |numero, linea|
      next if linea.match?(Constants::CONTINUATION_RE)

      nombre = linea[Constants::DECL_RE, 1]
      next if nombre.nil?

      if primeros.key?(nombre)
        findings.add(:blocking, :constant_duplicate,
                     t('constant_duplicate', line: numero, name: nombre, first: primeros[nombre]),
                     line: numero, wrote: linea.strip)
      else
        primeros[nombre] = numero
      end
    end
  end

  # C2 — nadie lo cita con %NOMBRE% (ni otro dato fijo).
  def unused(lineas, constantes, findings)
    citados = lineas.join("\n").scan(Constants::REF_RE).flatten.to_set
    constantes.each_value do |c|
      next if citados.include?(c[:name])

      findings.add(:degrading, :constant_unused, t('constant_unused', line: c[:line], name: c[:name]),
                   line: c[:line], wrote: lineas[c[:line] - 1].strip)
    end
  end

  # C3
  def saves_unknown(texto, constantes, findings)
    variables = ContactTrackings::ConversationVariables::Definition.parse(texto)
    constantes.each_value do |c|
      next if c[:saves_to].blank? || variables.variable(c[:saves_to])

      findings.add(:degrading, :constant_saves_unknown,
                   t('constant_saves_unknown', line: c[:line], name: c[:name], variable: c[:saves_to]),
                   line: c[:line], wrote: "→ guarda en #{c[:saves_to]}")
    end
  end

  # C5 — uno por grupo, en la línea del segundo.
  def same_value(constantes, findings)
    constantes.values.reject { |c| c[:value].blank? }
              .group_by { |c| c[:value].strip.downcase }.each_value do |grupo|
      next if grupo.size < 2

      findings.add(:degrading, :constant_same_value,
                   t('constant_same_value', line: grupo[1][:line], names: grupo.pluck(:name).join(', ')),
                   line: grupo[1][:line])
    end
  end

  # «Mi empresa» → MI_EMPRESA.
  def suggestion(nombre)
    I18n.transliterate(nombre.strip).upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A[_\d]+|_+\z/, '')
  end

  def t(key, **args)
    I18n.t("tracking_assistant.findings.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
