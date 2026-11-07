# frozen_string_literal: true

# Buscar en todo (la lupa de la barra de arriba y Dali): una palabra en contactos,
# organizaciones y casos, en todos sus campos de texto, con los permisos de quien
# busca (Access::Grant). Sin acentos ni mayúsculas; desde MIN_CHARS letras.
#
#   GlobalSearch.new(account:, grant:, query: 'compresor').call
#   → { contacts: { count:, items: [...] }, organizations: {...}, cases: {...} }
#   GlobalSearch.new(..., type: 'cases', page: 2).call   → solo ese grupo, otra página
#
# Cada item trae `match: { field:, snippet: }` cuando la palabra no está en el
# nombre o título, para que se vea por qué salió.
class GlobalSearch
  TYPES = %w[contacts organizations cases].freeze
  MIN_CHARS = 3
  PER_GROUP = 5
  PER_PAGE = 20
  SNIPPET = 45

  ACCENTS = %w[áàäâãéèëêíìïîóòöôõúùüûñç aaaaaeeeeiiiiooooouuuunc].freeze

  # Campos por grupo: clave → expresión SQL (texto) y cómo leerlo en Ruby.
  FIELDS = {
    'contacts' => {
      'name' => ["concat_ws(' ', contacts.name, contacts.middle_name, contacts.last_name)",
                 ->(c) { [c.name, c.middle_name, c.last_name].compact_blank.join(' ') }],
      'email' => ['contacts.email', ->(c) { c.email }],
      'phone' => ['contacts.phone_number', ->(c) { c.phone_number }],
      'company' => ["contacts.additional_attributes->>'company_name'", ->(c) { c.additional_attributes&.dig('company_name') }],
      'city' => ["concat_ws(' ', contacts.location, contacts.additional_attributes->>'city')",
                 ->(c) { [c.location, c.additional_attributes&.dig('city')].compact_blank.join(' ') }],
      'identifier' => ['contacts.identifier', ->(c) { c.identifier }],
      'custom' => [:json, 'contacts.custom_attributes', ->(c) { json_text(c.custom_attributes) }]
    },
    'organizations' => {
      'name' => ['organizations.name', ->(o) { o.name }],
      'tax_id' => ['organizations.tax_id', ->(o) { o.tax_id }],
      'website' => ["concat_ws(' ', organizations.website, organizations.email_domain)",
                    ->(o) { [o.website, o.email_domain].compact_blank.join(' ') }],
      'industry' => ['organizations.industry', ->(o) { o.industry }],
      'phone' => ['organizations.phone_number', ->(o) { o.phone_number }],
      'address' => ['organizations.address', ->(o) { o.address }],
      'notes' => ['organizations.notes', ->(o) { o.notes }],
      'custom' => [:json, 'organizations.custom_attributes', ->(o) { json_text(o.custom_attributes) }]
    },
    'cases' => {
      'title' => ["concat_ws(' ', case_tickets.folio, case_tickets.title)", ->(t) { "#{t.folio} #{t.title}" }],
      'description' => ['case_tickets.description', ->(t) { t.description }],
      'work_address' => ['case_tickets.work_address', ->(t) { t.work_address }],
      'closure' => ["concat_ws(' ', case_tickets.closure_cause, case_tickets.closure_solution)",
                    ->(t) { [t.closure_cause, t.closure_solution].compact_blank.join(' ') }],
      'outcome' => ['case_tickets.outcome_note', ->(t) { t.outcome_note }],
      'commit_note' => ['case_tickets.commit_note', ->(t) { t.commit_note }],
      'custom' => [:json, 'case_tickets.custom_attributes', ->(t) { json_text(t.custom_attributes) }]
    }
  }.freeze

  # El campo «principal» de cada grupo: si la palabra está ahí no hace falta pedacito.
  MAIN_FIELD = { 'contacts' => 'name', 'organizations' => 'name', 'cases' => 'title' }.freeze

  def self.normalize(text)
    I18n.transliterate(text.to_s.downcase).squish
  end

  def self.json_text(hash)
    hash.is_a?(Hash) ? hash.values.flatten.compact.map(&:to_s).join(' ') : ''
  end

  def initialize(account:, grant:, query:, type: nil, page: 1)
    @account = account
    @grant = grant
    @query = self.class.normalize(query)
    @type = TYPES.include?(type.to_s) ? type.to_s : nil
    @page = [page.to_i, 1].max
  end

  def call
    return TYPES.index_with { { count: 0, items: [] } }.symbolize_keys if @query.length < MIN_CHARS

    (@type ? [@type] : TYPES).index_with { |type| group(type) }.symbolize_keys
  end

  private

  def group(type)
    scope = matching(type)
    limit = @type ? PER_PAGE : PER_GROUP
    records = order(scope, type).offset((@page - 1) * limit).limit(limit).to_a
    { count: scope.count, items: records.map { |record| item(type, record) } }
  end

  def base(type)
    case type
    when 'contacts' then @grant.allowed?(:clients) ? @grant.contacts(@account.contacts) : Contact.none
    when 'organizations' then organizations
    else @grant.case_tickets(@account.case_tickets).includes(:case_type)
    end
  end

  # Con Clientes en «solo lo suyo»: las que tiene a su cargo y las de los contactos que ve.
  def organizations
    return Organization.none unless @grant.allowed?(:clients)
    return @account.organizations unless @grant.own?(:clients)

    visible = @grant.contacts(@account.contacts).where.not(organization_id: nil).select(:organization_id)
    @account.organizations.where(owner_id: @grant.user_id).or(@account.organizations.where(id: visible))
  end

  def matching(type)
    conditions = FIELDS[type].values.map { |definition| "#{sql_for(definition)} LIKE :q" }
    base(type).where(conditions.join(' OR '), q: "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
  end

  # Primero los que traen la palabra en el nombre o título; luego lo más reciente.
  def order(scope, type)
    main = sql_for(FIELDS[type][MAIN_FIELD[type]])
    pattern = ActiveRecord::Base.connection.quote("%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
    scope.reorder(Arel.sql("(#{main} LIKE #{pattern}) DESC"), updated_at: :desc)
  end

  def sql_for(definition)
    expression = definition.first == :json ? json_sql(definition[1]) : definition.first
    from, to = ACCENTS
    "translate(lower(coalesce(#{expression}, '')), '#{from}', '#{to}')"
  end

  # Solo los valores del JSON (no sus claves).
  def json_sql(column)
    "(SELECT string_agg(value, ' ') FROM jsonb_each_text(CASE WHEN jsonb_typeof(#{column}) = 'object' " \
      "THEN #{column} ELSE '{}'::jsonb END))"
  end

  def item(type, record)
    send("#{type}_item", record).merge(match: match_for(type, record))
  end

  def contacts_item(contact)
    { id: contact.id, name: contact.name, detail: contact.phone_number.presence || contact.email }
  end

  def organizations_item(org)
    { id: org.id, name: org.name, stage: org.stage, detail: org.tax_id }
  end

  def cases_item(ticket)
    { id: ticket.id, folio: ticket.folio, title: ticket.title, status: ticket.status,
      case_class: ticket.case_type&.case_class, type: ticket.case_type&.name }
  end

  # El primer campo (fuera del principal) donde aparece, con el pedacito de texto.
  def match_for(type, record)
    return nil if contains?(FIELDS[type][MAIN_FIELD[type]].last.call(record))

    FIELDS[type].each do |field, definition|
      next if field == MAIN_FIELD[type]

      text = definition.last.call(record).to_s
      return { field: field, snippet: snippet(text) } if contains?(text)
    end
    nil
  end

  def contains?(text)
    self.class.normalize(text).include?(@query)
  end

  def snippet(text)
    flat = text.squish
    index = self.class.normalize(flat).index(@query) || 0
    from = [index - SNIPPET, 0].max
    piece = flat[from, @query.length + (SNIPPET * 2)].to_s
    "#{'…' if from.positive?}#{piece}#{'…' if from + piece.length < flat.length}"
  end
end
