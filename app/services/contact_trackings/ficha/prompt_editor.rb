# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — APLICAR UN CAMBIO DE LA FICHA AL PROMPT (con el OK de la persona)
# ================================================================================
# add(oferta):     agrega su @ruta (antes de @ruta_por_defecto), su línea en
#                  [ALCANCE POR RAMA] y su etiqueta en [ETIQUETAS]; un archivo va a [ARCHIVOS].
# remove(ruta):    quita la @ruta y sus líneas en [ALCANCE POR RAMA] y [ETIQUETAS]; si era
#                  la ruta por defecto, la pasa a la primera que quede.
# Las secciones que no existen se crean al final. El resto del texto no se toca.
# ================================================================================

class ContactTrackings::Ficha::PromptEditor
  LINE_RE = ContactTrackings::RouteMap::LINE_RE
  DEFAULT_RE = ContactTrackings::RouteMap::DEFAULT_RE
  SECTION_RE = ContactTrackings::Assistant::DraftPieces::SECTION_RE

  def initialize(text, name: nil)
    @lines = text.to_s.split("\n", -1)
    @name = name
  end

  def text = @lines.join("\n").gsub(/\n{3,}/, "\n\n").strip

  def add(oferta)
    return add_file(oferta) if oferta[:kind] == 'file'

    ruta = oferta[:route]
    ruta = unique_route(ruta) if route_names.include?(ruta[:name])
    insert_route(ruta[:line])
    append_to_section('ALCANCE POR RAMA', "#{ruta[:name]}: #{scope_for(oferta)}")
    append_to_section('ETIQUETAS', "##{ruta[:tag]} = cuando el cliente #{ruta[:description]}.")
    self
  end

  # Suma una frase de cliente a la descripción de una ruta (lo que mira el clasificador).
  def add_phrase(nombre, frase)
    texto = frase.to_s.tr('()', '  ').squish
    return self if texto.blank?

    @lines.map! do |linea|
      m = linea.match(LINE_RE)
      next linea unless m && m[1].casecmp?(nombre)
      next linea if m[3].to_s.downcase.include?(texto.downcase)

      sangria = linea[/\A[ \t]*/]
      etiqueta = m[2] ? " ##{m[2]}" : ''
      descripcion = [m[3].to_s.strip.presence, texto].compact.join(', ')
      "#{sangria}@ruta(#{m[1]}#{etiqueta}: #{descripcion}): #{m[4]}"
    end
    self
  end

  # Lo que la persona aceptó en Recursos, de una vez:
  #   add     llaves de oferta (rutas nuevas) o 'welcome_file:nombre' (archivo con la bienvenida)
  #   remove  nombres de ruta    phrases { ruta => [frases] }    offers { llave => oferta }
  WELCOME_FILE = 'welcome_file:'

  def apply(add: [], remove: [], phrases: {}, offers: {})
    add.each do |key|
      next add_welcome_file(key.delete_prefix(WELCOME_FILE)) if key.start_with?(WELCOME_FILE)

      add(offers[key]) if offers[key]
    end
    remove.each { |ruta| remove(ruta) }
    phrases.each { |ruta, frases| Array(frases).each { |f| add_phrase(ruta.to_s, f) } }
    self
  end

  # Agrega {{archivo}} a la sección [MENSAJE DE BIENVENIDA] (la crea si no existe).
  def add_welcome_file(nombre)
    return self if ContactTrackings::WelcomeMessage.text(text).to_s.include?("{{#{nombre}}}")

    append_to_section('MENSAJE DE BIENVENIDA', "{{#{nombre}}}")
    self
  end

  def remove(nombre)
    etiqueta = nil
    @lines.reject! do |linea|
      m = linea.match(LINE_RE)
      next false unless m && m[1].casecmp?(nombre)

      etiqueta = m[2]
      true
    end
    drop_from_section('ALCANCE POR RAMA') { |l| l.split(':', 2).first.to_s.strip.casecmp?(nombre) }
    drop_from_section('ETIQUETAS') { |l| etiqueta.present? && l.strip.match?(/\A##{Regexp.escape(etiqueta)}\s*=/i) }
    fix_default(nombre)
    self
  end

  private

  def generator = @generator ||= ContactTrackings::Ficha::Generator.new(account: nil, name: @name, offers: [])

  def scope_for(oferta) = generator.send(:scope_for, oferta)

  def route_names = @lines.filter_map { |l| l.match(LINE_RE)&.[](1) }

  def unique_route(ruta)
    n = 2
    n += 1 while route_names.include?("#{ruta[:name]}_#{n}")
    nombre = "#{ruta[:name]}_#{n}"
    ruta.merge(name: nombre, line: ruta[:line].sub("@ruta(#{ruta[:name]} ", "@ruta(#{nombre} "))
  end

  # Antes de @ruta_por_defecto, o después de la última @ruta, o al principio.
  def insert_route(linea)
    indice = @lines.index { |l| l.match?(DEFAULT_RE) }
    indice ||= @lines.rindex { |l| l.match?(LINE_RE) }&.+(1)
    @lines.insert(indice || 0, linea)
    @lines.insert(1, '') if indice.nil? && @lines.size > 1 && @lines[1].present?
  end

  def section_range(titulo)
    inicio = @lines.index { |l| (m = l.match(SECTION_RE)) && m[1].strip.casecmp?(titulo) }
    return nil if inicio.nil?

    fin = ((inicio + 1)...@lines.size).find { |i| @lines[i].match?(SECTION_RE) } || @lines.size
    [inicio, fin]
  end

  def append_to_section(titulo, linea)
    rango = section_range(titulo)
    if rango.nil?
      @lines.push('', "[#{titulo}]", linea)
      return
    end
    # Después de la última línea con texto de la sección.
    ultima = (rango[0]...rango[1]).reverse_each.find { |i| @lines[i].present? }
    @lines.insert(ultima + 1, linea)
  end

  def drop_from_section(titulo)
    rango = section_range(titulo)
    return if rango.nil?

    cuerpo = @lines[(rango[0] + 1)...rango[1]].reject { |l| l.present? && yield(l) }
    @lines[(rango[0] + 1)...rango[1]] = cuerpo
  end

  def fix_default(nombre)
    indice = @lines.index { |l| (m = l.match(DEFAULT_RE)) && m[1].casecmp?(nombre) }
    return if indice.nil?

    otra = route_names.first
    otra ? @lines[indice] = "@ruta_por_defecto: #{otra}" : @lines.delete_at(indice)
  end

  def add_file(oferta)
    return self if @lines.any? { |l| l.include?("{{#{oferta[:name]}}}") }

    append_to_section('ARCHIVOS', "Si el cliente pide #{oferta[:topic]}, escribo {{#{oferta[:name]}}} en mi respuesta para mandarle el archivo.")
    self
  end
end
