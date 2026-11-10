# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LO QUE EL AGENTE RECUERDA Y VA CAMBIANDO (VARIABLES)
# ================================================================================
# Pedido del usuario (10/11/2026): «las variables van cambiando su valor en la
# conversación; lo más usual es que salgan de lo que se encontró en una hoja (una columna
# se asocia a una variable), y también hay variables que cambian por condiciones… muy
# sencillo de definir». Dos clases, las dos en lo que el motor ya entiende
# (ContactTrackings::ConversationVariables):
#
#   De la hoja (casilla «Recordar lo que eligió el cliente» en el modal de la hoja):
#     [VARIABLES]  CARRERA = VACÍO | valor        ← mismo nombre que la columna: el motor
#                  Inicial: CARRERA=VACÍO            la usa en {{hoja_buscar: … | Carrera=? …}}
#     [CUÁNDO CAMBIAN LAS VARIABLES]
#     - CARRERA guarda lo que el cliente eligió de «Carrera» en la hoja «Precios»; si
#       nombra otro, marca CARRERA=el nuevo.
#
#   Por condición (sección «Variables» de Recursos):
#     [VARIABLES]  LIGA_ENTREGADA = NO | SÍ        Inicial: LIGA_ENTREGADA=NO
#     [CUÁNDO CAMBIAN LAS VARIABLES]
#     - Marca LIGA_ENTREGADA=SÍ cuando le mande la liga para agendar.
#
# Cada variable lleva su regla escrita fuera de [VARIABLES]: así el modelo sabe cuándo
# cambiarla y el comprobador no la marca «sin usar» (V2). Las variables de las preguntas
# las escribe Ficha::Questions y aquí no se tocan; las que ya existían escritas a mano se
# leen como «por condición» y sus reglas de otras secciones se quedan donde están.
# ================================================================================

class ContactTrackings::Ficha::Memory
  include ContactTrackings::Ficha::SectionLines

  SECTION = 'VARIABLES'
  RULES = 'CUÁNDO CAMBIAN LAS VARIABLES'
  EMPTY = 'VACÍO'
  FREE = 'valor'
  ANY = '*'
  MAX = 10
  MAX_VALUES = 10
  MAX_VALUE = 40
  MAX_WHEN = 200
  NAME_RE = /\A[A-Z_][A-Z0-9_]*\z/
  VAR = '([A-Za-zÁÉÍÓÚÑáéíóúñ_][A-Za-z0-9ÁÉÍÓÚÑáéíóúñ_]*)'
  RULE_RE = /\A\s*-\s*Marca\s+#{VAR}\s*=\s*(.+?)\s+cuando\s+(.+?)\.?\s*\z/io
  FREE_RULE_RE = /\A\s*-\s*Guarda en\s+#{VAR}\s+lo que diga el cliente cuando\s+(.+?)\.?\s*\z/io
  SHEET_RE = /\A\s*-\s*#{VAR} guarda lo que el cliente eligió de «(.+?)» en la hoja «(.+?)»/o
  DEFINITION = ContactTrackings::ConversationVariables::Definition

  def self.key(texto) = ContactTrackings::ConversationVariables.key(texto)

  # El nombre de la variable de una columna (el motor las une por nombre), o nil si la
  # columna no da un nombre válido («Precio $»).
  def self.sheet_var(columna)
    nombre = key(columna)
    nombre.match?(NAME_RE) ? nombre : nil
  end

  def self.var_name(nombre, indice)
    limpio = I18n.transliterate(nombre.to_s).upcase.gsub(/[^A-Z0-9_]+/, '_').gsub(/\A[_0-9]+|_+\z/, '')
    limpio.presence || "VARIABLE_#{indice + 1}"
  end

  # [{ 'name', 'values' => [], 'free' => bool, 'initial', 'rules' => [{ 'to', 'when' }] }] limpias.
  def self.clean(lista)
    limpias = Array(lista).first(MAX).each_with_index.filter_map { |variable, indice| clean_one(variable, indice) }
    limpias.uniq { |v| v['name'] }
  end

  def self.clean_one(variable, indice)
    h = plain(variable)
    libre = ActiveModel::Type::Boolean.new.cast(h['free']) || false
    valores = clean_values(h['values'])
    valores = [EMPTY] if libre && valores.empty?
    return nil if valores.empty?

    { 'name' => var_name(h['name'], indice), 'values' => valores, 'free' => libre,
      'initial' => initial_for(h['initial'], valores), 'rules' => clean_rules(h['rules'], valores, libre) }
  end

  def self.plain(hash) = (hash.respond_to?(:to_unsafe_h) ? hash.to_unsafe_h : hash.to_h).stringify_keys

  def self.clean_values(valores)
    Array(valores).map { |v| v.to_s.tr('|;=%', ' ').squish.first(MAX_VALUE) }.compact_blank
                  .reject { |v| DEFINITION::FREE_VALUES.include?(key(v)) }.uniq { |v| key(v) }.first(MAX_VALUES)
  end

  def self.initial_for(pedido, valores)
    valores.find { |v| key(v) == key(pedido.to_s) } || valores.first
  end

  def self.clean_rules(reglas, valores, libre)
    Array(reglas).filter_map do |regla|
      r = plain(regla)
      cuando = r['when'].to_s.squish.delete_suffix('.').first(MAX_WHEN)
      destino = rule_target(r['to'].to_s, valores, libre)
      destino && cuando.present? ? { 'to' => destino, 'when' => cuando } : nil
    end
  end

  def self.rule_target(destino, valores, libre)
    return ANY if destino == ANY && libre

    valores.find { |v| key(v) == key(destino) }
  end

  def initialize(text)
    @lines = text.to_s.split("\n", -1)
  end

  # { variables: [por condición…], sheets: [{ 'name', 'column', 'sheet' }] }
  def read
    definicion = DEFINITION.parse(text)
    hojas = sheet_rules
    propias = question_vars + hojas.map { |h| self.class.key(h['name']) }
    variables = definicion.variables.except(*propias).map do |clave, var|
      { 'name' => var[:name], 'values' => var[:options], 'free' => var[:free],
        'initial' => definicion.initial[clave].to_s, 'rules' => rules_for(var[:name]) }
    end
    { variables: variables, sheets: hojas }
  end

  # variables: las de Recursos › Variables (ya limpias); hojas: [{ 'name', 'column', 'sheet' }].
  def write(variables, hojas)
    viejas = read
    nombres = (viejas[:variables] + viejas[:sheets] + variables + hojas).map { |v| self.class.key(v['name']) }.uniq
    quitar(nombres)
    declarar(variables, hojas)
    self
  end

  private

  def question_vars
    ContactTrackings::PromptConstants.parse(text).values.filter_map { |c| c[:saves_to] && self.class.key(c[:saves_to]) }
  end

  def sheet_rules
    section_body(RULES).filter_map do |linea|
      m = linea.match(SHEET_RE)
      m && { 'name' => m[1], 'column' => m[2], 'sheet' => m[3] }
    end
  end

  def rules_for(nombre)
    section_body(RULES).filter_map do |linea|
      if (m = linea.match(RULE_RE)) && self.class.key(m[1]) == self.class.key(nombre)
        { 'to' => m[2].strip, 'when' => m[3].strip }
      elsif (m = linea.match(FREE_RULE_RE)) && self.class.key(m[1]) == self.class.key(nombre)
        { 'to' => ANY, 'when' => m[2].strip }
      end
    end
  end

  def quitar(nombres)
    drop_lines(SECTION) { |l| (m = l.match(DEFINITION::DECL_RE)) && nombres.include?(self.class.key(m[1])) }
    iniciales = initial_pairs.reject { |nombre, _| nombres.include?(self.class.key(nombre)) }
    write_initial(iniciales)
    drop_section(RULES)
    drop_if_empty(SECTION)
  end

  def declarar(variables, hojas)
    return if variables.empty? && hojas.empty?

    append_lines(SECTION, variables.map { |v| declaration(v) } + hojas.map { |h| sheet_declaration(h) })
    write_initial(initial_pairs + initial_for(variables, hojas))
    append_lines(RULES, hojas.map { |h| sheet_rule(h) } + variables.flat_map { |v| rule_lines(v) })
  end

  def initial_for(variables, hojas)
    variables.map { |v| [v['name'], v['initial']] } + hojas.map { |h| [h['name'], EMPTY] }
  end

  def sheet_declaration(hoja) = "#{hoja['name']} = #{EMPTY} | #{FREE}"

  def declaration(variable)
    valores = variable['values'] + (variable['free'] ? [FREE] : [])
    "#{variable['name']} = #{valores.join(' | ')}"
  end

  def sheet_rule(hoja)
    "- #{hoja['name']} guarda lo que el cliente eligió de «#{hoja['column']}» en la hoja «#{hoja['sheet']}»; " \
      "si nombra otro, marca #{hoja['name']}=el nuevo."
  end

  def rule_lines(variable)
    variable['rules'].map do |regla|
      if regla['to'] == ANY
        "- Guarda en #{variable['name']} lo que diga el cliente cuando #{regla['when']}."
      else
        "- Marca #{variable['name']}=#{regla['to']} cuando #{regla['when']}."
      end
    end
  end

  def initial_index
    rango = section_range(SECTION)
    rango && ((rango[0] + 1)...rango[1]).find { |i| @lines[i].match?(DEFINITION::INITIAL_RE) }
  end

  def initial_pairs
    indice = initial_index
    return [] if indice.nil?

    @lines[indice].match(DEFINITION::INITIAL_RE)[1].scan(DEFINITION::PAIR_RE).map { |n, v| [n, v.strip.delete_suffix('.')] }
  end

  # Un solo renglón «Inicial: A=x; B=y». Sin pares, se quita.
  def write_initial(pares)
    indice = initial_index
    linea = pares.any? ? "Inicial: #{pares.uniq(&:first).map { |n, v| "#{n}=#{v}" }.join('; ')}" : nil
    if indice
      linea ? @lines[indice] = linea : @lines.delete_at(indice)
    elsif linea
      append_lines(SECTION, [linea])
    end
  end
end
