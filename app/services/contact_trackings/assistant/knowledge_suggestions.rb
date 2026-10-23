# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONOCIMIENTO SUGERIDO: LAS RESPUESTAS PREDEFINIDAS
# ================================================================================
# Decisión C de docs/importar_prompt_md_plan.md, retomada el 24/09/2026 a partir del
# manual de estructura de Kontrolya: el prompt es comportamiento; precios, horarios,
# direcciones y requisitos viven en la fuente. Si están en el Entrenamiento o en el
# Contexto, cambiar un precio es editar el agente, y el agente carga con datos que
# se quedan viejos.
#
# Propone las respuestas predefinidas que el agente necesita, para revisarlas y
# crearlas desde el modal de las instrucciones. De dos lados:
#
#   conocimiento   lo que la ficha ya separó como datos del negocio (horario,
#                  dirección, teléfono…). Sin IA: la ficha ya los trae con tema y
#                  resumen.
#   faltantes      lo que las rutas prometen buscar en las predefinidas y nadie cargó
#                  (el precio de las vacunas, los requisitos de una cirugía). Una
#                  llamada a gpt-4o; lo que no se sabe queda <PENDIENTE: …> para que
#                  la persona lo llene.
#
# LO INVENTADO SE MARCA, SIN IA: medido el 24/09 con la veterinaria, gpt-4o escribió
# «ayuno de 8 horas» y «avisa con 24 horas» aunque el pedido lo prohíbe. Todo número
# de una respuesta que no está en las instrucciones la deja en «unverified»: se ve, se
# revisa, y no sale marcada para crear.
#
# EL GRUPO: todas llevan el mismo prefijo en el título («PATITAS HORARIO») y la ruta
# busca con @buscar_predefinidas(PATITAS). Sin eso buscaría en TODAS las de la cuenta:
# la veterinaria de prueba de la cuenta 2 habría contestado el horario de Kontrolya
# («HORARIO DE OFICINA», lunes a viernes de 9 a 6).
#
# No crea nada: propone. Crear es otro paso (AssistantBriefsController#knowledge_create).
# ================================================================================

class ContactTrackings::Assistant::KnowledgeSuggestions
  MODEL = 'gpt-4o'
  MAX_AI_ITEMS = 8
  MAX_CONTENT = 1000
  GROUP_RE = /\A[A-ZÁÉÍÓÚÑ0-9]{3,20}\z/
  FILENAME_NOISE = %w[instrucciones iniciales agente].freeze

  def initialize(brief, account:)
    @brief = brief
    @account = account
    @ficha = brief.digest.to_h['ficha'] || {}
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account)
  end

  # { group:, items: [{ key, title, short_code, content, status, origin }] }
  #   status: ready · missing (tiene <PENDIENTE:>) · unverified (trae números que las
  #           instrucciones no dicen; `unverified` los lista) · existing (ya hay una)
  def call
    sugerido = ai_suggestions
    grupo = group_from(sugerido)
    propias = from_knowledge + Array(sugerido&.dig('respuestas'))
    { group: grupo, items: dedupe(propias).map { |item| decorate(item, grupo) } }
  end

  def self.group_prefixed(group, title)
    "#{group} #{title.to_s.strip.upcase}".squish
  end

  private

  def from_knowledge
    Array(@ficha['conocimiento']).filter_map do |c|
      next if c['tema'].blank? || c['resumen'].blank?

      { 'titulo' => c['tema'], 'contenido' => c['resumen'], 'origen' => 'conocimiento' }
    end
  end

  # La misma respuesta propuesta dos veces (la ficha ya traía «Horario» y el modelo lo
  # vuelve a proponer): gana la de la ficha, que es lo que la persona escribió.
  def dedupe(items)
    items.uniq { |item| item['titulo'].to_s.strip.downcase }
  end

  def decorate(item, grupo)
    titulo = item['titulo'].to_s.strip.truncate(60)
    codigo = self.class.group_prefixed(grupo, titulo)
    contenido = item['contenido'].to_s.strip.truncate(MAX_CONTENT)
    existente = @account.canned_responses.where('LOWER(short_code) = LOWER(?)', codigo).first
    dudosos = invented_numbers(contenido)
    { key: codigo.parameterize, title: titulo.upcase, short_code: codigo, content: existente&.content || contenido,
      status: status_for(existente, contenido, dudosos), origin: item['origen'] || 'faltante', unverified: dudosos }
  end

  def status_for(existente, contenido, dudosos)
    return 'existing' if existente
    return 'missing' if ContactTrackings::Assistant::PendingMarkers.pending?(contenido)
    return 'unverified' if dudosos.any?

    'ready'
  end

  # Los números de la respuesta que no aparecen en lo que escribió la persona.
  def invented_numbers(contenido)
    sin_marcas = contenido.gsub(ContactTrackings::Assistant::PendingMarkers::RE, '')
    sin_marcas.scan(/\d+(?:[.,:]\d+)?/).uniq.reject { |n| source_text.include?(n) }
  end

  def source_text
    @source_text ||= @ficha.to_json + @brief.content.to_s
  end

  # El nombre corto del negocio, en mayúsculas y sin espacios. Del modelo si lo dio;
  # si no, la primera palabra con mayúscula del nombre del archivo.
  def group_from(sugerido)
    propuesto = I18n.transliterate(sugerido&.dig('grupo').to_s).upcase.gsub(/[^A-Z0-9]/, '')
    return propuesto if propuesto.match?(GROUP_RE)

    palabra = @brief.filename.to_s.sub(/\.\w+\z/, '').split(/[_\-\s]+/)
                    .reject { |p| p.size < 4 || FILENAME_NOISE.include?(p.downcase) }.last
    I18n.transliterate(palabra.to_s).upcase.gsub(/[^A-Z0-9]/, '').presence || 'AGENTE'
  end

  def ai_suggestions
    return nil if @chat.api_key.blank?

    reply = @chat.call([{ role: 'system', content: prompt }], max_tokens: 2500, model: MODEL)
    return nil unless reply.is_a?(Hash)

    reply.merge('respuestas' => Array(reply['respuestas']).first(MAX_AI_ITEMS).select { |r| r.is_a?(Hash) })
  end

  def prompt
    <<~PROMPT
      Preparas las RESPUESTAS PREDEFINIDAS de un agente de atención por chat: fichas cortas que el agente consulta
      (@buscar_predefinidas) para contestar datos del negocio. Así el Entrenamiento del agente guarda solo
      comportamiento, y un precio o un horario se cambia en un solo lugar.

      QUIÉN ES Y QUÉ HACE: #{point(@ficha['identidad'])} · #{point(@ficha['objetivo'])}

      LO QUE LA GENTE VIENE A PEDIR (y de dónde sale la respuesta):
      #{topics}

      REGLAS DEL AGENTE:
      #{Array(@ficha['reglas']).map { |r| "- #{r['texto']}" }.join("\n").presence || '- (ninguna)'}

      DATOS QUE YA SE CONOCEN (ya van como respuesta; no los repitas):
      #{from_knowledge.map { |k| "- #{k['titulo']}: #{k['contenido']}" }.join("\n").presence || '- (ninguno)'}

      Propón las respuestas predefinidas QUE FALTAN para que las rutas que consultan predefinidas puedan contestar:
      precios, requisitos, preparación, servicios, políticas. Máximo #{MAX_AI_ITEMS}.
        titulo      2 a 4 palabras, sin el nombre del negocio (ej. "PRECIO VACUNAS")
        contenido   escrito para el cliente, de tú, en 1 a 3 frases. SOLO con datos que aparecen arriba. Cada dato
                    que no está arriba va como <PENDIENTE: qué dato>: un precio, una cantidad de horas o días, un
                    requisito, una política. Nunca lo rellenes con frases vagas («varía según el tipo»,
                    «contáctanos para más detalles»): eso es un <PENDIENTE: …>.
      Y "grupo": el nombre corto del negocio, UNA palabra en mayúsculas (ej. "PATITAS").
      Si no falta ninguna, "respuestas": [].

      Responde SOLO un JSON: {"grupo": "...", "respuestas": [{"titulo": "...", "contenido": "..."}]}
    PROMPT
  end

  def topics
    Array(@ficha['temas']).map do |t|
      "- #{t['nombre']}: #{t['que_hace']} · fuente: #{t['fuente'].presence || 'ninguna'}"
    end.join("\n").presence || '- (ninguno)'
  end

  def point(valor)
    valor.is_a?(Hash) ? valor['texto'].to_s : valor.to_s
  end
end
