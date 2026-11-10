# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia F1 — LO QUE LA CUENTA LE PUEDE DAR A UN AGENTE
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md §4–§5. Una TARJETA por recurso que se puede marcar
# en la ficha: qué tiene, si está listo y qué podría hacer el agente con él. SIN IA:
# todo sale de la base (reusa SourceProfiles, el mismo «qué tiene» que ve el chat).
#
#   { key: 'google_sheet:12', kind: 'sheet', name: 'Precios',
#     summary: 'Servicio · Zona · Precio (48 filas)', examples: [...],
#     status: 'ready' | 'warn' | 'off', warning: '…', fix: 'knowledge_sources',
#     offer: { label: 'Contestar datos exactos de «Precios»…', directive: '{{hoja_buscar: …}}',
#              topic: 'Servicio, Zona o Precio' },
#     parts: [{ key: 'PATITAS', label: 'PATITAS', count: 14, not_ready: 2 }] }   # solo predefinidas
#
# `key` es estable (tipo:id) para que la ficha guardada no se rompa si renombran algo.
# ================================================================================

class ContactTrackings::Ficha::Catalog
  KINDS = %w[sheet doc articles canned forum contpaq discourse erp calendar case_type file].freeze
  MAX_TOPICS = 4

  def initialize(account, inbox: nil, template: nil)
    @account = account
    @inbox = inbox
    @template = template
  end

  def call
    [*sheets, *docs, *articles, *canned, *external, *discourse, *erp, *calendars, *case_types, *files]
  end

  def find(key) = call.find { |card| card[:key] == key.to_s }

  def openai? = @openai ||= @account.hooks.exists?(app_id: 'openai', status: 'enabled')

  private

  def profiles = @profiles ||= ContactTrackings::Assistant::SourceProfiles.new(@account, inbox: @inbox).call

  def profile(tipo, nombre) = profiles.find { |p| p[:tipo] == tipo && p[:nombre] == nombre }

  def active = @active ||= @account.knowledge_sources.active.order(:name).to_a

  def of_type(tipo) = active.select { |s| s.source_type == tipo }

  def card(attrs)
    { status: 'ready', warning: nil, fix: nil, examples: [], parts: nil }.merge(attrs)
  end

  # Las búsquedas por parecido necesitan OpenAI para vectorizar la pregunta del cliente.
  def needs_openai(attrs)
    return attrs if openai?

    attrs.merge(status: 'warn', warning: 'falta activar OpenAI: no podrá buscar aquí', fix: 'integrations')
  end

  # ── hojas ────────────────────────────────────────────────────────────────────
  def sheets
    of_type('google_sheet').map do |hoja|
      base = sheet_card(hoja)
      next card(base) if hoja.google_sheet_rows.exists?

      card(base.merge(status: 'warn', warning: 'la hoja no tiene filas sincronizadas', fix: 'knowledge_sources'))
    end
  end

  def sheet_card(hoja)
    perfil = profile('hoja', hoja.name) || {}
    columnas = hoja.google_sheet_rows.order(:row_index).first&.data&.keys || []
    { key: "google_sheet:#{hoja.id}", kind: 'sheet', id: hoja.id, name: hoja.name,
      summary: perfil[:que_tiene], examples: Array(perfil[:ejemplo]),
      offer: { label: "Contestar datos exactos de la hoja «#{hoja.name}»",
               directive: perfil[:como_se_usa] || "{{hoja:#{hoja.name}}}",
               topic: columnas.first(MAX_TOPICS).join(', ') } }
  end

  # ── documentos ───────────────────────────────────────────────────────────────
  def docs
    of_type('google_doc').map do |doc|
      perfil = profile('documento', doc.name) || {}
      titulos = doc.knowledge_items.order(:id).limit(MAX_TOPICS).pluck(:title).compact_blank.uniq
      base = { key: "google_doc:#{doc.id}", kind: 'doc', id: doc.id, name: doc.name, summary: perfil[:que_tiene], examples: titulos,
               offer: { label: "Contestar con lo que dice «#{doc.name}»", directive: "{{doc:#{doc.name}}}",
                        topic: titulos.join(', ').presence || doc.name } }
      next card(base.merge(status: 'warn', warning: 'el documento no tiene contenido sincronizado', fix: 'knowledge_sources')) if titulos.empty?

      card(needs_openai(base))
    end
  end

  # ── artículos ────────────────────────────────────────────────────────────────
  def articles
    perfil = profiles.find { |p| p[:tipo] == 'articulos' }
    return [] if perfil.nil?

    base = { key: 'article', kind: 'articles', name: perfil[:nombre], summary: perfil[:que_tiene],
             examples: Array(perfil[:ejemplo]).first(MAX_TOPICS),
             offer: { label: 'Contestar con tus artículos de ayuda', directive: '@buscar_articulo',
                      topic: Array(perfil[:ejemplo]).first(MAX_TOPICS).join(', ') } }
    return [card(base.merge(status: 'warn', warning: 'no hay artículos publicados', fix: 'help_center'))] if base[:examples].empty?

    [card(needs_openai(base))]
  end

  # ── respuestas predefinidas (por grupo) ──────────────────────────────────────
  # El grupo es lo que va en @buscar_predefinidas(GRUPO): la categoría si existe, si no
  # el principio del nombre (ContactTrackings::Ficha::CannedGroups).
  def canned
    return [] if of_type('canned_response').empty? && @account.canned_responses.none?

    grupos = ContactTrackings::Ficha::CannedGroups.new(@account).call
    total = @account.canned_responses.count
    sin_vector = grupos.sum { |g| g[:not_ready] }
    base = { key: 'canned_response', kind: 'canned', name: 'Respuestas predefinidas',
             summary: "#{total} respuestas en #{grupos.size} grupos",
             parts: grupos.map { |g| g.slice(:key, :label, :count, :not_ready, :topics, :source) },
             offer: { label: 'Contestar dudas frecuentes con tus respuestas predefinidas',
                      directive: '@buscar_predefinidas', topic: grupos.first(MAX_TOPICS).pluck(:label).join(', ') } }
    base = base.merge(status: 'warn', warning: "#{sin_vector} sin vectorizar: el agente no las encontraría", fix: 'canned') if sin_vector.positive?
    [card(needs_openai(base))]
  end

  # ── foro y CONTPAQi (en vivo) ────────────────────────────────────────────────
  def external
    (of_type('discourse') + of_type('contpaq_support')).map do |fuente|
      foro = fuente.source_type == 'discourse'
      directiva = foro ? "@buscar_foro(#{fuente.name})" : "@soporte_contpaq(#{fuente.name})"
      card(key: "#{fuente.source_type}:#{fuente.id}", kind: foro ? 'forum' : 'contpaq', id: fuente.id, name: fuente.name,
           summary: 'se consulta en vivo',
           offer: { label: foro ? "Buscar soluciones en el foro «#{fuente.name}»" : 'Resolver dudas de soporte de CONTPAQi',
                    directive: directiva, topic: foro ? 'dudas que ya se respondieron en el foro' : 'dudas de CONTPAQi' })
    end
  end

  # ── Discourse del canal (integración) ────────────────────────────────────────
  def discourse
    hooks = @account.hooks.where(app_id: 'discourse', status: 'enabled')
    hooks = hooks.where(inbox_id: @inbox.id) if @inbox
    return [] unless hooks.exists?

    [card(key: 'discourse_integration', kind: 'discourse', name: 'Discourse del canal', summary: 'se consulta en vivo',
          offer: { label: 'Buscar en el Discourse del canal', directive: '@discourse', topic: 'dudas del foro del canal' })]
  end

  # ── ERP ──────────────────────────────────────────────────────────────────────
  def erp
    return [] unless @account.feature_enabled?('erp_connection')

    ExternalDbQuery.where(account_id: @account.id).active.ai_enabled.includes(:external_db_connection).order(:name)
                   .map { |consulta| card(erp_card(consulta)) }
  end

  def erp_card(consulta)
    que = consulta.description.presence || consulta.name
    conexion = consulta.external_db_connection&.name
    { key: "erp_query:#{consulta.id}", kind: 'erp', id: consulta.id, name: consulta.name, connection: conexion,
      summary: [que, conexion].compact.join(' · '),
      offer: { label: "Consultar en el ERP: #{que}", directive: ContactTrackings::Ficha::Offers.erp_directive(consulta), topic: que } }
  end

  # ── agenda ───────────────────────────────────────────────────────────────────
  def calendars
    UserCalendarIntegration.where(account_id: @account.id).includes(:user).map do |integracion|
      nombre = integracion.user&.available_name.presence || integracion.google_email
      base = { key: "calendar:#{integracion.id}", kind: 'calendar', id: integracion.id, name: "Agenda de #{nombre}",
               summary: integracion.google_email,
               offer: { label: "Agendar citas en la agenda de #{nombre}", directive: '@agendar_calendar',
                        topic: 'agendar, cambiar o confirmar una cita' } }
      next card(base) unless integracion.token_expired? && integracion.refresh_token.blank?

      card(base.merge(status: 'warn', warning: 'la conexión con Google venció: hay que volver a conectarla', fix: 'calendar'))
    end
  end

  # ── tipos de ticket ──────────────────────────────────────────────────────────
  def case_types
    profiles.select { |p| p[:tipo] == 'tipo_de_caso' }.map do |perfil|
      tipo = CaseType.find_by(account_id: @account.id, name: perfil[:nombre])
      card(key: "case_type:#{tipo&.id}", kind: 'case_type', id: tipo&.id, name: perfil[:nombre], summary: perfil[:que_tiene],
           offer: { label: "Abrir un ticket «#{perfil[:nombre]}» con los datos que pide",
                    directive: perfil[:como_se_usa], topic: "pedir #{perfil[:nombre].downcase}" })
    end
  end

  # ── archivos del agente ──────────────────────────────────────────────────────
  def files
    return [] if @template.nil?

    @template.ai_agent_attachments.order(:name).map do |archivo|
      card(key: "file:#{archivo.id}", kind: 'file', id: archivo.id, name: archivo.name,
           rule: @template.file_rules[archivo.name],
           summary: archivo.file.attached? ? archivo.file.filename.to_s : 'sin archivo',
           offer: { label: "Mandar «#{archivo.name}» cuando lo pidan", directive: "{{#{archivo.name}}}",
                    topic: archivo.name.tr('_-', '  ') })
    end
  end
end
