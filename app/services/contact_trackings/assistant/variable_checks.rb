# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F1: LAS VARIABLES, BIEN ESCRITAS
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §3. El motor guarda por
# conversación las variables que declara la sección [VARIABLES]
# (ContactTrackings::ConversationVariables). Si se escriben mal, no truena nada: el
# agente sigue contestando y adivina los valores leyendo el historial, que se recorta.
# Estos avisos dicen qué no va a guardar el motor:
#
#   V1 se usa y no está declarada     «Marca BECA=SÍ» y [VARIABLES] no tiene BECA
#   V2 está declarada y nadie la usa  INTERES en [VARIABLES] y en ningún otro lado
#   V3 un valor que no está en su     «Marca LIGA_ENTREGADA=ENVIADA» y la lista es NO | SÍ
#      lista                          (el motor lo descarta al guardar)
#   V4 el valor inicial no vale       «Inicial: INTERES=NINGUNO» (arranca en el primero)
#   V5 declarada FUERA de [VARIABLES] «* CIERRE_ENVIADO = NO | SI» dentro de otra sección:
#                                     tiene la forma correcta y el motor no la guarda.
#                                     Medido en un agente real (DCI V8.12, 03/11/2026):
#                                     sus 6 variables estaban así.
#
# Ámbar todos: el agente funciona, pero sin memoria de eso. Cada aviso lleva su línea
# (el editor la pinta y el árbol cuelga el punto de Variables, por su código).
# ================================================================================

module ContactTrackings::Assistant::VariableChecks
  Definition = ContactTrackings::ConversationVariables::Definition
  Stray = ContactTrackings::Assistant::StrayVariables
  STRAY_RE = Stray::STRAY_RE
  # «CARRERA=Psicología», «Marca LIGA_ENTREGADA=SÍ»: un uso, en cualquier parte del renglón.
  USE_RE = /(?<![\p{L}\d_])(#{Stray::UPPER_NAME})[ \t]*=[ \t]*([\p{L}\d_]+)/o
  CODES = %i[variable_undeclared variable_unused variable_value_unknown
             variable_initial_invalid variables_outside_section].freeze

  module_function

  def check(text, findings:)
    lineas = text.to_s.split("\n", -1)
    dentro = Stray.section_line_numbers(lineas)
    definicion = Definition.parse(text)

    outside_section(text, findings)
    return if definicion.blank?

    # [DATOS FIJOS] («EMPRESA = Kontrolya») no son usos de variables (feat/ficha_agente_ia).
    usos = uses(lineas, dentro + ContactTrackings::PromptConstants.section_lines(text).map(&:first))
    undeclared(usos, definicion, findings)
    unused(lineas, dentro, definicion, findings)
    unknown_values(usos, definicion, findings)
    invalid_initials(lineas, dentro, definicion, findings)
  end

  # V5
  def outside_section(text, findings)
    Stray.lines(text).each do |stray|
      findings.add(:degrading, :variables_outside_section,
                   t('variables_outside_section', line: stray[:line], name: stray[:names].join(', ')),
                   line: stray[:line], wrote: stray[:wrote])
    end
  end

  # { 'CARRERA' => [{ name:, value:, line:, wrote: }, …] } fuera de [VARIABLES]. Las
  # declaraciones sueltas (V5) no cuentan como uso: ya tienen su aviso.
  def uses(lineas, dentro)
    lineas.each_with_index.with_object(Hash.new { |h, k| h[k] = [] }) do |(linea, indice), acc|
      numero = indice + 1
      next if dentro.include?(numero) || linea.match?(STRAY_RE) || linea.match?(Definition::HEADER_RE)

      linea.scan(USE_RE).each do |nombre, valor|
        acc[key(nombre)] << { name: nombre, value: valor, line: numero, wrote: linea.strip }
      end
    end
  end

  # V1 — uno por nombre, en la primera línea donde aparece.
  def undeclared(usos, definicion, findings)
    usos.each do |clave, lista|
      next if definicion.variables.key?(clave)

      primero = lista.first
      findings.add(:degrading, :variable_undeclared,
                   t('variable_undeclared', line: primero[:line], name: primero[:name],
                                            declared: definicion.names.join(', ')),
                   line: primero[:line], wrote: primero[:wrote])
    end
  end

  # V2 — el nombre no aparece en ningún renglón fuera de [VARIABLES].
  def unused(lineas, dentro, definicion, findings)
    afuera = lineas.each_with_index.reject { |_, indice| dentro.include?(indice + 1) }.map(&:first).join("\n")
    definicion.variables.each_value do |var|
      next if afuera.match?(/(?<![\p{L}\d_])#{Regexp.escape(var[:name])}(?![\p{L}\d_])/i)

      numero = declaration_line(lineas, dentro, var[:name])
      findings.add(:degrading, :variable_unused, t('variable_unused', line: numero, name: var[:name]),
                   line: numero, wrote: numero && lineas[numero - 1].strip)
    end
  end

  # V3 — uno por (variable, valor). Las de texto libre aceptan cualquier valor.
  def unknown_values(usos, definicion, findings)
    usos.each do |clave, lista|
      var = definicion.variables[clave]
      next if var.nil? || var[:free]

      lista.uniq { |uso| key(uso[:value]) }.each do |uso|
        next if definicion.coerce(var[:name], uso[:value])

        findings.add(:degrading, :variable_value_unknown,
                     t('variable_value_unknown', line: uso[:line], name: var[:name], value: uso[:value],
                                                 options: var[:options].join(' | ')),
                     line: uso[:line], wrote: uso[:wrote])
      end
    end
  end

  # V4 — un inicial de una variable que no existe, o que no está en su lista.
  def invalid_initials(lineas, dentro, definicion, findings)
    dentro.sort.each do |numero|
      match = lineas[numero - 1].match(Definition::INITIAL_RE)
      next unless match

      match[1].scan(Definition::PAIR_RE).each do |nombre, valor|
        initial_finding(definicion, [nombre, valor], { line: numero, wrote: lineas[numero - 1].strip }, findings)
      end
    end
  end

  # `par` = [nombre, valor] tal como están en «Inicial:»; `donde` = { line:, wrote: }.
  def initial_finding(definicion, par, donde, findings)
    nombre, valor = par
    var = definicion.variable(nombre)
    return if var && definicion.coerce(nombre, valor)

    findings.add(:degrading, :variable_initial_invalid,
                 t(var ? 'variable_initial_invalid' : 'variable_initial_unknown',
                   line: donde[:line], name: nombre.strip, value: valor.strip, first: var&.dig(:options, 0).to_s),
                 **donde)
  end

  def declaration_line(lineas, dentro, nombre)
    dentro.sort.find do |numero|
      (match = lineas[numero - 1].match(Definition::DECL_RE)) && key(match[1]) == key(nombre)
    end
  end

  def key(text)
    ContactTrackings::ConversationVariables.key(text)
  end

  def t(key, **args)
    I18n.t("tracking_assistant.findings.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
