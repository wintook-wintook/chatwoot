# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F0) — QUÉ LE FALTA A ESTE PROMPT EN ESTA CUENTA
# ================================================================================
# La pestaña «Configurar» del Asistente se arma con esto. Un prompt bajado de la Galería
# (o pegado de otra cuenta) nombra cosas de la cuenta de su autor: sus docs, sus hojas,
# sus archivos. PublishedPrompts::Requirements ya los LISTA; esto los
# CRUZA con la cuenta que lo tiene ahora y dice, de cada uno:
#
#   status   ok | missing
#   fix      cómo se resuelve en la pestaña:
#              text          escribir un valor (variables <PENDIENTE: X>)
#              create_inline crear ahí mismo (AddSourceModal), o elegir
#              select        elegir uno que ya existe en la cuenta
#              upload        subir el archivo a la pestaña Archivos del agente
#              link          se configura en otra pantalla: `link` dice cuál
#   options  lo que hay en la cuenta para elegir en su lugar
#   create   { source_type, name } para AddSourceModal (los mismos tipos que sourceDirective.js)
#   link     { route, params, query } — nombre de ruta del dashboard; el navegador lo
#            resuelve con $router.resolve (el accountId lo pone él)
#
# Las directivas se leen en TODO el texto, no solo en las líneas @ruta: un {{doc:X}}
# escrito en la prosa también tiene que existir (el comprobador no lo mira).
#
# Las etiquetas (#cotizacion en una ruta o en [ETIQUETAS]) NO se piden: no son etiquetas
# de Chatwoot, son marcas que van en el mensaje y que una automatización lee. Que no
# existan en la cuenta no es un faltante (20/10/2026).
#
# Las expresiones son las del motor (KnowledgeBase::Directives, SheetLookup,
# ConsultaDirectiveRenderer, AgentAttachments): no se copian,
# así una directiva que cambie de forma se sigue detectando igual. Sin IA.
#
# `key` es estable ("google_doc:precios", "var:nombre del negocio"): es la llave con la
# que F1 aplica las respuestas y F6 las recuerda.
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

class ContactTrackings::Assistant::AdaptationInventory
  GROUPS = %i[business sources case_types outside].freeze

  # Directivas de búsqueda que nombran una fuente creable en la Base de Conocimiento,
  # con el source_type con que se crea (igual que sourceDirective.js en el navegador).
  NAMED_SOURCES = {
    google_doc: 'google_doc',
    google_sheet: 'google_sheet',
    knowledge_source: 'discourse',
    contpaq_support: 'contpaq_support'
  }.freeze

  # answers: lo aplicado antes; por omisión, lo del agente (un borrador sin agente manda
  # lo de su conversación).
  def initialize(text, account:, template: nil, answers: nil)
    @text = text.to_s
    @account = account
    @template = template
    @answers = (answers || template&.adaptation_answers).to_h
    @items = {}
  end

  def call
    return [] if @text.blank?

    scan_variables
    scan_filled_variables
    scan_named_sources
    scan_sheet_lookups
    scan_erp_queries
    scan_attachments
    scan_case_types
    scan_flags
    scan_inbox
    remember_answers
    @items.values.sort_by { |item| GROUPS.index(item[:group]) }
  end

  private

  attr_reader :text, :account, :template

  # ── Datos del negocio: <PENDIENTE: X>, agrupadas por X ───────────────────────
  def scan_variables
    each_match(ContactTrackings::Assistant::PendingMarkers::RE) do |raw, line|
      label = raw[/:\s*([^>]+)>/, 1].to_s.strip.presence || raw
      add("var:#{label.downcase}", line, group: :business, kind: 'variable', name: label,
                                         status: 'missing', fix: 'text')
    end
  end

  # ── feat/reemplazo_directo_variables: datos ya escritos ───────────────────────
  # Lo reemplazado antes ya no tiene marca: se reconoce por su valor recordado, que siga
  # en la prosa. Sale ✔ con `current` y se cambia escribiendo otro (AdaptationApplier).
  def scan_filled_variables
    @answers.each do |key, value|
      next unless key.to_s.start_with?('var:') && !@items.key?(key)

      veces = PublishedPrompts::Variables.count(text, value.to_s) if value.to_s.strip.present?
      next if veces.to_i.zero?

      @items[key] = { key: key, occurrences: veces, line: line_of(value), options: [], group: :business,
                      kind: 'variable', name: key.to_s.delete_prefix('var:').upcase_first,
                      status: 'ok', fix: 'text', current: value.to_s }
    end
  end

  # ── {{doc:X}} {{hoja:X}} @buscar_foro(X) @soporte_contpaq(X) ────────────────
  def scan_named_sources
    KnowledgeBase::Directives::SEARCH_DIRECTIVES.each do |regex, mode, named|
      next unless named && NAMED_SOURCES.key?(mode)

      each_match(regex) do |raw, line, match|
        name = match[1].to_s.strip
        add("#{mode}:#{name.downcase}", line, **named_source(mode, name, raw))
      end
    end
  end

  def named_source(mode, name, raw)
    source_type = NAMED_SOURCES[mode]
    ready = KnowledgeBase::Directives.ready?({ mode: mode, source_name: name }, account: account, inbox_id: nil)
    {
      group: :sources, kind: mode.to_s, name: name, wrote: raw,
      status: ready ? 'ok' : 'missing', fix: 'create_inline',
      create: { source_type: source_type, name: name },
      options: source_names(source_type),
      reason: google_off?(source_type) ? 'google_disabled' : nil
    }
  end

  # ── {{hoja_buscar: Hoja | …}}: lo que pide es la hoja ────────────────────────
  def scan_sheet_lookups
    each_match(ContactTrackings::SheetLookup::DIRECTIVE_RE) do |raw, line, match|
      sheet = ContactTrackings::SheetLookup.parse(match[1])&.sheet.presence || match[1].to_s.split('|').first.to_s.strip
      ready = KnowledgeBase::Directives.sheet_lookup_source?(account, match[1])
      add("sheet_lookup:#{sheet.downcase}", line,
          group: :sources, kind: 'sheet_lookup', name: sheet, wrote: raw,
          status: ready ? 'ok' : 'missing', fix: 'create_inline',
          create: { source_type: 'google_sheet', name: sheet },
          options: source_names('google_sheet'),
          reason: google_off?('google_sheet') ? 'google_disabled' : nil)
    end
  end

  # ── {{consulta:conexión/nombre}} ─────────────────────────────────────────────
  # Sin conexión no hay nada que elegir: la conexión se crea en Base de Conocimiento.
  # Con conexión, se puede elegir otra consulta de esa misma conexión.
  def scan_erp_queries
    renderer = ExternalDb::ConsultaDirectiveRenderer.new(account: account)
    ExternalDb::ConsultaDirectiveRenderer.parse(text).each do |directive|
      name = [directive.conn, directive.name].compact.join('/')
      connection = renderer.connection_for(directive)
      ready = renderer.resolve(directive).present?
      add("erp_query:#{name.downcase}", line_of(directive.raw),
          group: :sources, kind: 'erp_query', name: name, wrote: directive.raw,
          status: ready ? 'ok' : 'missing', fix: connection ? 'select' : 'link',
          options: connection ? connection.external_db_queries.active.order(:name).pluck(:name) : [],
          link: { route: 'knowledge_sources_list', query: { tab: 'erp' } })
    end
  end

  # ── {{nombre}}: archivo de la pestaña Archivos del agente ────────────────────
  def scan_attachments
    files = template ? template.ai_agent_attachments.pluck(:name).map(&:downcase) : []
    each_match(ContactTrackings::AgentAttachments::DIRECTIVE) do |raw, line, match|
      name = match[1]
      add("attachment:#{name.downcase}", line,
          group: :sources, kind: 'attachment', name: name, wrote: raw,
          status: files.include?(name.downcase) ? 'ok' : 'missing', fix: 'upload')
    end
  end

  # ── @crear_ticket(tipo=X) ────────────────────────────────────────────────────
  # Sin cruzar de línea, como check_ticket_types del comprobador.
  def scan_case_types
    types = CaseType.where(account_id: account.id).order(:name).pluck(:name)
    each_match(/@crear_ticket\(([^)\n]*)\)/i) do |raw, line, match|
      type = match[1][/tipo\s*=\s*([^,)]+)/i, 1]&.strip
      next if type.blank? || ContactTrackings::Assistant::PendingMarkers.pending?(type)

      add("case_type:#{type.downcase}", line,
          group: :case_types, kind: 'case_type', name: type, wrote: raw,
          status: types.any? { |t| t.casecmp?(type) } ? 'ok' : 'missing', fix: 'select', options: types,
          admin_only: true, link: { route: 'gestorTickets_types' })
    end
  end

  # ── Directivas sin nombre que piden algo configurado fuera del Asistente ──────
  def scan_flags
    flag(/@agendar_calendar\b/i, 'calendar', calendar?, { route: 'google_calendar' })
    flag(KnowledgeBase::Directives::CANNED_RE, 'canned_responses', account.canned_responses.exists?,
         { route: 'canned_list' })
    flag(/@discourse\b/i, 'discourse',
         KnowledgeBase::Directives.discourse_hook?(account, template&.inbox_id),
         { route: 'settings_applications_integration', params: { integration_id: 'discourse' } })
    flag(/@buscar_art[ií]culo\b/i, 'article', KnowledgeBase::Directives.items?(account, 'article'),
         { route: 'knowledge_sources_list' })
  end

  def flag(regex, kind, ready, link)
    each_match(regex) do |raw, line|
      add(kind, line, group: :outside, kind: kind, wrote: raw,
                      status: ready ? 'ok' : 'missing', fix: 'link', link: link)
    end
  end

  # El agente agenda con SUS calendarios. Sin agente guardado, lo único comprobable es
  # que la cuenta tenga alguno conectado (igual que check_calendar_directive).
  def calendar?
    return Array(template.calendar_integration_ids).any? || Array(template.booking_calendar_ids).any? if template

    UserCalendarIntegration.exists?(account_id: account.id)
  end

  # ── La bandeja: solo de un agente guardado (un borrador todavía no tiene) ─────
  def scan_inbox
    return if template.nil?

    add('inbox', nil, group: :outside, kind: 'inbox', status: template.inbox_id.present? ? 'ok' : 'missing',
                      fix: 'link', link: { route: 'tracking_templates_list', query: { edit: template.id } })
  end

  # ── F6: lo que se aplicó antes en este agente, para prellenar ────────────────
  # Una versión nueva del autor vuelve a traer las marcas y los nombres de su cuenta:
  # lo que ya se configuró sale escrito, y solo se piden a mano las cosas nuevas.
  def remember_answers
    previas = @answers
    return if previas.blank?

    @items.each_value do |item|
      item[:remembered] = previas[item[:key]] if item[:status] == 'missing' && previas[item[:key]].present?
    end
  end

  # ── Utilidades ───────────────────────────────────────────────────────────────
  # La primera aparición fija la línea; las demás solo suman `occurrences`.
  def add(key, line, **attrs)
    if @items.key?(key)
      @items[key][:occurrences] += 1
      return
    end

    @items[key] = { key: key, occurrences: 1, line: line, options: [], **attrs.compact }
  end

  def each_match(regex)
    text.to_enum(:scan, regex).each do
      match = Regexp.last_match
      yield match[0], line_at(match.begin(0)), match
    end
  end

  def line_at(offset)
    text[0...offset].count("\n") + 1
  end

  def line_of(fragment)
    index = text.downcase.index(fragment.to_s.downcase)
    index && line_at(index)
  end

  def source_names(source_type)
    account.knowledge_sources.active.where(source_type: source_type).order(:name).pluck(:name)
  end

  def google_off?(source_type)
    %w[google_doc google_sheet].include?(source_type) && !account.feature_enabled?('google_calendar')
  end
end
