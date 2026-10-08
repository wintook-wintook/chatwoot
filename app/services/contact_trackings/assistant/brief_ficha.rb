# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA FICHA DEL ENCARGO (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Lo que el Asistente necesita saber de un encargo para escribir el Entrenamiento,
# con una forma FIJA que sirve para cualquier agente: vende, agenda, cobra, da
# soporte, coordina. Nada de la forma supone un objetivo (ver §2.1 del plan).
#
# Tres cosas viven acá, porque las tres dependen de la misma forma:
#   · la forma, tal como se le pide al modelo (SHAPE);
#   · limpiar lo que el modelo devuelve: tipos, largos, vacíos, valores fuera de lista;
#   · los ids de cada punto, que dicen de qué trozo salió (el "origen" que ve la persona
#     y que usa la cobertura de la F4).
#
# QUÉ ES UN PUNTO: cada elemento de una lista (una regla, un tema, una prohibición) y
# los campos sueltos (identidad, objetivo, modo). Todos llevan `ids`.
# ================================================================================

module ContactTrackings::Assistant::BriefFicha
  # Campos que son UN valor, no una lista.
  SINGLE = %w[identidad objetivo modo].freeze
  # Listas de texto suelto.
  TEXT_LISTS = %w[reglas prohibiciones tono datos_a_pedir fuera dudas].freeze
  # Listas de objetos, con sus campos.
  OBJECT_LISTS = {
    'temas' => %w[nombre frases_cliente que_hace fuente si_no_resuelve etiqueta],
    'herramientas' => %w[tipo para],
    'conocimiento' => %w[tema resumen],
    'contradicciones' => %w[sobre a b]
  }.freeze
  LISTS = (TEXT_LISTS + OBJECT_LISTS.keys).freeze
  CATEGORIES = (SINGLE + LISTS).freeze

  MODES = %w[responde deriva].freeze
  # Lo que un agente puede necesitar hacer o consultar. La lista y su cruce con la
  # cuenta viven en BriefTools, la única tabla contra el motor.
  TOOLS = ContactTrackings::Assistant::BriefTools::TYPES

  # Un punto más largo que esto no es un punto: es un párrafo copiado.
  MAX_ITEM_CHARS = 400
  MAX_PHRASES = 6

  # La forma que se le muestra al modelo, con lo que va en cada campo.
  SHAPE = <<~JSON.freeze
    {
      "identidad": "quién es el agente, a nombre de quién habla y para quién trabaja, o null",
      "objetivo": "qué tiene que lograr en una conversación, o null",
      "modo": "responde (contesta y escala si no resuelve) | deriva (siempre pasa el caso, no contesta) | null",
      "temas": [{"nombre": "lo que el cliente viene a pedir",
                 "frases_cliente": ["cómo lo escribe el cliente, si el texto lo dice"],
                 "que_hace": "qué hace el agente con ese tema",
                 "fuente": "de dónde saca la respuesta, o null",
                 "si_no_resuelve": "qué pasa si no puede (caso, agenda, persona…), o null",
                 "etiqueta": "la etiqueta con la que cierra, si el texto la dice, o null"}],
      "herramientas": [{"tipo": "#{TOOLS.join(' | ')}", "para": "para qué la usa"}],
      "reglas": ["lo que vale en toda la conversación"],
      "prohibiciones": ["lo que nunca hace"],
      "tono": ["cómo escribe: registro, largo, emojis, preguntas por mensaje…"],
      "datos_a_pedir": ["qué tiene que averiguar del cliente"],
      "conocimiento": [{"tema": "…", "resumen": "información larga y consultable: catálogo, precios, tarifas, glosario"}],
      "fuera": ["lo que es para quien administra o para otra área, no para el agente"],
      "contradicciones": [{"sobre": "…", "a": "lo que dice una parte", "b": "lo que dice otra"}],
      "dudas": ["lo que el texto deja abierto y el agente necesitaría saber"]
    }
  JSON

  module_function

  # Lo que devolvió el modelo al leer UN trozo, limpio y con ids "<trozo>.<n>".
  # Devuelve [ficha, { id => [índices de trozo] }].
  def from_reading(raw, chunk_index)
    contador = 0
    origen = {}
    ficha = clean(raw) do
      id = "#{chunk_index}.#{contador += 1}"
      origen[id] = [chunk_index]
      [id]
    end
    [ficha, origen]
  end

  # Limpia una ficha. Cada punto recibe los ids que devuelva el bloque (lo llama una vez
  # por punto, con el `ids` que haya traído el modelo).
  def clean(raw, &)
    datos = raw.is_a?(Hash) ? raw.stringify_keys : {}
    ficha = {}
    SINGLE.each do |campo|
      punto = single(campo, datos[campo], &)
      ficha[campo] = punto if punto
    end
    TEXT_LISTS.each { |campo| ficha[campo] = text_list(datos[campo], &) }
    OBJECT_LISTS.each { |campo, llaves| ficha[campo] = object_list(campo, datos[campo], llaves, &) }
    ficha
  end

  def single(campo, valor)
    valor = valor.first if valor.is_a?(Array) # al juntar, el modelo a veces lo deja en lista
    texto, ids = unwrap(valor)
    texto = texto.to_s.squish.downcase if campo == 'modo'
    return nil if texto.blank? || (campo == 'modo' && MODES.exclude?(texto))

    { 'texto' => short(texto), 'ids' => yield(ids) }
  end

  def text_list(valores)
    Array(valores).filter_map do |valor|
      texto, ids = unwrap(valor)
      next if texto.blank?

      { 'texto' => short(texto), 'ids' => yield(ids) }
    end
  end

  def object_list(campo, valores, llaves)
    Array(valores).filter_map do |valor|
      next unless valor.is_a?(Hash)

      punto = llaves.index_with { |llave| field(campo, llave, valor[llave]) }.compact
      next if punto.values_at(*llaves.first(1)).all?(&:blank?)
      next if campo == 'herramientas' && punto['tipo'].nil?

      punto.merge('ids' => yield(valor['ids']))
    end
  end

  def field(campo, llave, valor)
    return Array(valor).filter_map { |f| short(f).presence }.uniq.first(MAX_PHRASES) if llave == 'frases_cliente'

    texto = short(valor)
    return nil if texto.blank? || texto.casecmp?('null')

    campo == 'herramientas' && llave == 'tipo' ? tool(texto) : texto
  end

  def tool(texto) = TOOLS.include?(texto.downcase) ? texto.downcase : 'otra'

  # Un punto puede venir como texto o, en la fusión, como { "texto", "ids" }.
  def unwrap(valor) = valor.is_a?(Hash) ? [valor['texto'] || valor[:texto], valor['ids'] || valor[:ids]] : [valor, nil]

  def short(valor)
    valor.is_a?(String) || valor.is_a?(Numeric) ? valor.to_s.squish.truncate(MAX_ITEM_CHARS) : ''
  end

  # Cada punto de la ficha, con su categoría: [categoría, punto].
  def points(ficha)
    CATEGORIES.flat_map { |campo| Array.wrap(ficha[campo]).map { |punto| [campo, punto] } }
  end

  def size(ficha) = ficha.to_json.length
end
