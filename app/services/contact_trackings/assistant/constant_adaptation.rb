# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — LOS DATOS FIJOS EN «CONFIGURAR»
# ================================================================================
# Un prompt bajado de la Galería trae los [DATOS FIJOS] de la cuenta de su autor
# (EMPRESA = Kontrolya, LIGA_AGENDA = su liga). Son casi siempre lo primero que hay que
# adaptar, así que la pestaña «Configurar» los lista entre los datos del negocio, con su
# valor actual, para cambiarlos sin buscarlos en el texto:
#
#   const:empresa   EMPRESA = Kontrolya   → EMPRESA = Grúas del Sur
#
# Solo se reescribe la declaración (su renglón y los que siguen con sangría): el tipo y
# el «→ guarda en VARIABLE» se conservan, y cada %EMPRESA% del texto sigue citándola.
# Lo usan AdaptationInventory (#items) y AdaptationApplier (#replace). Sin IA.
# ================================================================================

module ContactTrackings::Assistant::ConstantAdaptation
  Constants = ContactTrackings::PromptConstants

  module_function

  # Los ítems de la pestaña, uno por dato fijo.
  def items(text)
    Constants.parse(text).values.map do |c|
      { key: "const:#{c[:name].downcase}", occurrences: [text.scan("%#{c[:name]}%").size, 1].max, line: c[:line],
        options: [], group: :business, kind: 'constant', name: c[:name], status: 'ok', fix: 'text',
        current: c[:value] }
    end
  end

  # El texto con el valor nuevo de ese dato fijo; igual si no está declarado.
  def replace(text, name, value)
    lineas = text.split("\n", -1)
    inicio, fin, decl = declaration_range(text, name)
    return text if inicio.nil?

    (lineas[0...inicio] + declaration_lines(decl, value) + lineas[(fin + 1)..].to_a).join("\n")
  end

  # [primer índice, último índice, MatchData] de la declaración y su continuación.
  def declaration_range(text, name)
    renglones = Constants.section_lines(text)
    donde = renglones.index { |_, linea| linea.match(Constants::DECL_RE)&.[](1)&.casecmp?(name) }
    return [nil, nil, nil] if donde.nil?

    numero, linea = renglones[donde]
    [numero - 1, continuation_end(renglones, donde) - 1, linea.match(Constants::DECL_RE)]
  end

  # El número del último renglón con sangría que sigue a la declaración.
  def continuation_end(renglones, donde)
    fin = renglones[donde][0]
    renglones[(donde + 1)..].each do |numero, linea|
      next if linea.strip.empty?
      break unless linea.match?(Constants::CONTINUATION_RE) && !linea.match?(Constants::DECL_RE)

      fin = numero
    end
    fin
  end

  def declaration_lines(decl, value)
    tipo = decl[2].present? ? " (#{decl[2]})" : ''
    guarda = decl[3].to_s[Constants::SAVES_RE, 1]
    primera, *resto = value.to_s.strip.split("\n")
    ["#{decl[1]}#{tipo} = #{primera.to_s.strip}#{" → guarda en #{guarda}" if guarda}",
     *resto.map { |l| l.strip.present? ? "  #{l.strip}" : '' }]
  end
end
