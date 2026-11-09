# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia F1 — DE LO MARCADO EN LA FICHA A LO QUE EL AGENTE PUEDE HACER
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md §5. Cada recurso marcado se vuelve una OFERTA
# («Agendar citas en la agenda de Ana») con la ruta que la cumple. SIN IA.
#
#   { key: 'google_sheet:12', kind: 'sheet', label: '…', topic: 'Servicio, Zona, Precio',
#     route: { name: 'consultar_precios', tag: 'precios', description: 'pregunta por …',
#              line: '@ruta(consultar_precios #precios: pregunta por …): {{hoja_buscar: …}}' },
#     scope: 'Busca en la hoja «Precios» y contesta el dato exacto…' }
#
# Los archivos no son rutas: el modelo escribe {{nombre}} en su respuesta y el motor
# manda el archivo (AgentAttachments). Van como oferta con route: nil.
#
# El formato sale de ContactTrackings::RouteMap::LINE_RE: nombre [a-z0-9_-], etiqueta
# [a-z0-9_] (3+ letras), descripción sin paréntesis, una fuente o «-» y la acción
# después de la flecha.
# ================================================================================

class ContactTrackings::Ficha::Offers
  MAX_NAME = 30
  MAX_DESCRIPTION = 240
  TAG_SKIP = %w[consultar dudas ticket erp].freeze
  MIN_GROUP = ContactTrackings::Assistant::CorpusChecks::MIN_GROUP_SIZE

  # {{consulta:nombre(param=?, …)}}: los parámetros los llena la IA con lo que dijo el cliente.
  # Con el prefijo de su conexión (como EditTemplate#erpPrefix): el erp_type si es el único
  # de la cuenta, si no el nombre sin espacios; sin prefijo usaría la del bot del canal.
  def self.erp_directive(consulta)
    params = Array(consulta.params_schema).filter_map { |p| (p['key'] || p['name'] || p[:key]).to_s.presence }
    nombre = consulta.name.to_s.downcase.gsub(/[^a-z0-9_]+/, '_')
    prefijo = erp_prefix(consulta.external_db_connection)
    nombre = "#{prefijo}/#{nombre}" if prefijo
    return "{{consulta:#{nombre}}}" if params.empty?

    "{{consulta:#{nombre}(#{params.map { |p| "#{p}=?" }.join(', ')})}}"
  end

  def self.erp_prefix(conexion)
    return nil if conexion.nil?

    tipo = conexion.erp_type.to_s
    unico = ExternalDbConnection.where(account_id: conexion.account_id, erp_type: tipo).count == 1
    return tipo if unico && tipo.match?(/\A[a-z0-9_]+\z/)

    por_nombre = conexion.name.to_s.downcase.gsub(/\s+/, '')
    por_nombre.match?(/\A[a-z0-9_]+\z/) ? por_nombre : nil
  end

  # Archivos que todavía no existen (agente nuevo): la pantalla los sube al crear con
  # estos nombres, así el Entrenamiento ya nace con {{nombre}}.
  def self.pending_files(lista)
    Array(lista).filter_map do |archivo|
      nombre = (archivo.respond_to?(:permit) ? archivo.permit(:name)[:name] : archivo.to_h.stringify_keys['name']).to_s
      next unless nombre.match?(/\A[a-zA-Z0-9_-]{1,60}\z/)

      { key: "file_new:#{nombre}", kind: 'file', name: nombre, label: "Mandar «#{nombre}» cuando lo pidan",
        topic: nombre.tr('_-', '  ').squish, route: nil, status: 'ready' }
    end
  end

  STOPWORDS = %w[de del la el los las y o a en para por con].freeze

  # «de equipo de computo» → «equipo de computo»
  def self.clean_topic(texto)
    palabras = texto.to_s.squish.split
    palabras = palabras.drop(1) while palabras.any? && STOPWORDS.include?(palabras.first.downcase)
    palabras.join(' ')
  end

  # cards: ContactTrackings::Ficha::Catalog#call
  # items: [{ 'key' => 'google_sheet:12' }, { 'key' => 'canned_response', 'parts' => ['PATITAS'] }, …]
  # phrases: { 'google_sheet:12' => ['¿cuánto cuesta la plataforma?'] } — frases de cliente
  # que la persona agregó a esa ruta desde la prueba; se suman a su descripción.
  def initialize(cards, items, phrases: {})
    @phrases = phrases.to_h.transform_keys(&:to_s)
    @cards = cards.index_by { |c| c[:key] }
    @items = Array(items).map { |i| i.respond_to?(:to_unsafe_h) ? i.to_unsafe_h : i.to_h }.map(&:stringify_keys)
    @names = []
    @tags = []
  end

  def call
    ofertas = @items.flat_map { |item| offers_for(item) }.compact
    # Una sola ruta de agenda aunque se marquen varias (las agendas van en calendar_integration_ids).
    agenda = ofertas.select { |o| o[:kind] == 'calendar' }
    ofertas -= agenda.drop(1)
    ofertas.each { |o| o[:route] = route_for(o) if o[:route] == :pending }
    ofertas
  end

  private

  def offers_for(item)
    card = @cards[item['key']]
    return [] if card.nil? || card[:status] == 'off'
    return canned_offers(card, item) if card[:kind] == 'canned'

    [base(card).merge(directive: card[:offer][:directive], topic: card[:offer][:topic])]
  end

  def base(card)
    { key: card[:key], kind: card[:kind], name: card[:name], label: card[:offer][:label], connection: card[:connection],
      status: card[:status], warning: card[:warning], route: card[:kind] == 'file' ? nil : :pending }.compact
  end

  # Un grupo marcado = una ruta @buscar_predefinidas(GRUPO). Sin grupos marcados, todas.
  def canned_offers(card, item)
    partes = chosen_parts(card, item)
    return [base(card).merge(directive: '@buscar_predefinidas', topic: card[:offer][:topic])] if partes.empty?

    chicas, grandes = partes.partition { |p| p[:count] < MIN_GROUP }
    grandes.map { |parte| canned_part_offer(card, parte) } + [small_groups_offer(card, chicas)].compact
  end

  def chosen_parts(card, item)
    elegidas = Array(item['parts']).map(&:to_s)
    partes = Array(card[:parts])
    elegidas.any? ? partes.select { |p| elegidas.include?(p[:key]) } : partes
  end

  # Los grupos chicos van juntos, sin acotar: con grupo el umbral sube y casi no encontrarían.
  def small_groups_offer(card, chicas)
    return nil if chicas.empty?

    base(card).merge(key: 'canned_response:*', name: 'generales',
                     label: "Contestar dudas generales con tus respuestas predefinidas (#{chicas.pluck(:label).join(', ')})",
                     directive: '@buscar_predefinidas', topic: chicas.flat_map { |p| p[:topics] }.first(4).join(', '))
  end

  def canned_part_offer(card, parte)
    base(card).merge(key: "canned_response:#{parte[:key]}", name: parte[:label],
                     label: "Contestar dudas de #{parte[:label]} con tus respuestas predefinidas",
                     directive: "@buscar_predefinidas(#{parte[:label]})", topic: parte[:topics].join(', '),
                     warning: parte[:not_ready].positive? ? "#{parte[:not_ready]} sin vectorizar" : nil)
  end

  def route_for(oferta)
    nombre = unique(slug(route_name(oferta)), @names, '_')
    etiqueta = unique(tag(nombre), @tags, '')
    descripcion = clean([description(oferta), *Array(@phrases[oferta[:key].to_s])].join(', '))
    { name: nombre, tag: etiqueta, description: descripcion,
      line: "@ruta(#{nombre} ##{etiqueta}: #{descripcion}): #{target(oferta)}" }
  end

  def route_name(oferta)
    case oferta[:kind]
    when 'calendar' then 'agendar_cita'
    when 'case_type' then "ticket_#{oferta[:name]}"
    when 'canned' then "dudas_#{oferta[:name]}"
    when 'erp' then "erp_#{oferta[:name]}"
    else "consultar_#{oferta[:name]}"
    end
  end

  # Fuente antes de la flecha; agendar y abrir ticket son ACCIONES (después).
  def target(oferta)
    %w[calendar case_type].include?(oferta[:kind]) ? "- -> #{oferta[:directive]}" : oferta[:directive]
  end

  # En palabras del cliente: es lo único que mira el clasificador para elegir la ruta.
  # %{tema}, %{nombre} y %{conexion} se llenan con la oferta.
  DESCRIPTIONS = {
    'calendar' => 'quiere agendar, cambiar o confirmar una cita',
    'case_type' => 'necesita %<nombre>s y hay que levantar su solicitud',
    'forum' => 'tiene un problema o duda técnica que se responde en el foro %<nombre_original>s',
    'contpaq' => 'tiene un problema o duda técnica: %<tema>s',
    'discourse' => 'tiene un problema o duda técnica: %<tema>s',
    'erp' => 'quiere consultar %<tema>s en %<conexion>s',
    'doc' => 'pregunta sobre %<tema>s',
    'articles' => 'pregunta sobre %<tema>s'
  }.freeze

  def description(oferta)
    tema = self.class.clean_topic(oferta[:topic].to_s.downcase).presence || oferta[:name].to_s.downcase
    plantilla = DESCRIPTIONS.fetch(oferta[:kind], 'pregunta por %<tema>s')
    format(plantilla, tema: tema, nombre: oferta[:name].to_s.downcase, nombre_original: oferta[:name],
                      conexion: oferta[:connection]).squish.delete_suffix(' en')
  end

  def clean(texto)
    texto.to_s.tr('()', '  ').gsub(/[\r\n]+/, ' ').squish.truncate(MAX_DESCRIPTION, omission: '')
  end

  def slug(texto)
    s = I18n.transliterate(texto.to_s).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').first(MAX_NAME)
    s.presence || 'ruta'
  end

  # La etiqueta: la última palabra con sentido del nombre (consultar_precios → precios).
  def tag(nombre)
    palabra = nombre.split('_').reject { |p| p.length < 3 || TAG_SKIP.include?(p) }.first
    (palabra || nombre.delete('-')).gsub(/[^a-z0-9_]/, '').first(20).ljust(3, 'x')
  end

  def unique(base, usados, sep)
    candidato = base
    n = 2
    while usados.include?(candidato)
      candidato = "#{base}#{sep}#{n}"
      n += 1
    end
    usados << candidato
    candidato
  end
end
