# frozen_string_literal: true

# Ajustes › Demostraciones › Importar — crea en la cuenta lo que trae un kit de demo (DemoKits::Exporter):
#   catálogo (categorías, unidades, productos: por clave o, sin clave, por nombre; si ya existe se actualiza),
#   bandejas (las de chat de la página se crean; las de otros canales se cambian por una existente que se elija),
#   agentes listos (con el mismo asistente: Motor2::Functions::Form) con las personas que se eligieron para cada lugar.
# Lo que crea queda en un DemoImport, para limpiar o quitar la demo después (DemoKits::Cleaner).
#
#   DemoKits::Importer.new(account, data, user:, people: { 'p1' => 2 }, inboxes: { 'i1' => 'new' | 42183 }).call → DemoImport
class DemoKits::Importer
  Error = Class.new(StandardError)
  NO_CANNED = Motor2::Search::NO_CANNED

  def initialize(account, data, user:, **options)
    @account = account
    @data = data.to_h.deep_stringify_keys
    @user = user
    @people = options[:people].to_h.transform_keys(&:to_s).transform_values { |v| v.to_s.presence&.to_i }
    @inbox_choice = options[:inboxes].to_h.transform_keys(&:to_s)
    @source = options[:source]
    @created = Hash.new { |h, k| h[k] = [] }
  end

  def call
    raise Error, 'El archivo no es un kit de demo de Kontrolya.' unless @data['kit'] == 'kontrolya-demo'

    ActiveRecord::Base.transaction do
      import_catalog
      @inbox_ids = import_inboxes
      Array(@data['agents']).each { |agent| import_agent(agent) }
      DemoImport.create!(account: @account, name: @data['name'].to_s.first(200).presence || 'Demo', user: @user, source: @source,
                         created_ids: @created)
    end
  end

  private

  def import_catalog
    CatalogParameters.ensure!(@account)
    before = @account.catalog_categories.ids
    Array(@data.dig('catalog', 'items')).each { |row| import_item(row) }
    Array(@data.dig('catalog', 'categories')).each { |c| CatalogParameters.category_for(@account, [c['parent'], c['name']].compact.join(' › ')) }
    @created['catalog_category_ids'] = @account.catalog_categories.ids - before
  end

  def import_item(row)
    item = (row['sku'].present? && @account.catalog_items.find_by(sku: row['sku'])) ||
           @account.catalog_items.find_by(name: row['name']) || @account.catalog_items.new
    new_item = item.new_record?
    item.update!(item_attrs(row))
    @created['catalog_item_ids'] << item.id if new_item
  end

  def item_attrs(row)
    { sku: row['sku'], name: row['name'], kind: CatalogItem.kind_from(row['kind']) || 'service', price: row['price'].to_d,
      currency: row['currency'].presence || 'MXN', description: row['description'], active: row.fetch('active', true),
      price_includes_tax: row['price_includes_tax'] == true, duration_minutes: row['duration_minutes'],
      catalog_category_id: CatalogParameters.category_for(@account, row['category'])&.id,
      catalog_unit_id: CatalogParameters.unit_for(@account, row['unit'])&.id, tax_rate_id: tax_rate_id(row['tax_percent']) }
  end

  # La de ese porcentaje en la cuenta (si es la de por omisión, se deja vacía para que siga a la cuenta).
  def tax_rate_id(percent)
    return nil if percent.nil?

    rate = @account.tax_rates.transfer.where(percent: percent.to_d).order(is_default: :desc).first
    rate&.is_default? ? nil : rate&.id
  end

  # { 'i1' => inbox_id }: la que eligió o, si es de chat de la página (o eligió «nueva»), se crea.
  def import_inboxes
    Array(@data['inboxes']).to_h do |row|
      choice = @inbox_choice[row['ref']].to_s
      existing = choice.match?(/\A\d+\z/) && @account.inboxes.find_by(id: choice)
      [row['ref'], (existing || create_inbox(row))&.id]
    end
  end

  def create_inbox(row)
    raise Error, "Elige una bandeja para «#{row['name']}» (#{row['channel']} no se puede crear aquí)." unless row['channel'] == 'web_widget'

    inbox = @account.inboxes.create!(name: row['name'], channel: web_channel(row), timezone: row['timezone'].presence || 'America/Mexico_City',
                                     working_hours_enabled: row['working_hours_enabled'] == true)
    copy_hours(inbox, row['working_hours'])
    [@user].compact.each { |u| InboxMember.find_or_create_by!(inbox: inbox, user: u) }
    @created['inbox_ids'] << inbox.id
    inbox
  end

  def web_channel(row)
    Channel::WebWidget.create!(account: @account, website_url: row['website_url'].presence || 'https://demo.kontrolya.com',
                               widget_color: row['widget_color'].presence || '#1f93ff',
                               welcome_title: row['welcome_title'], welcome_tagline: row['welcome_tagline'])
  end

  def copy_hours(inbox, rows)
    Array(rows).each do |row|
      hours = inbox.working_hours.find_by(day_of_week: row['day_of_week'])
      hours&.update!(row.slice('closed_all_day', 'open_all_day', 'open_hour', 'open_minutes', 'close_hour', 'close_minutes'))
    end
  end

  # Si ya hay uno con ese nombre y función (la demo se importó antes), se actualiza en lugar de crear otro.
  def import_agent(row)
    existing = @account.tracking_templates.find_by(name: row['name'], agent_function: row['kind'], archived_at: nil)
    template = Motor2::Functions::Form.new(@account, agent_params(row), user: @user, template: existing).save
    keep_no_canned(template, row)
    @created['tracking_template_ids'] << template.id unless existing
  end

  # Lo del asistente, con «p1» → la persona que eligió para ese lugar (sin elegir, se quita) y sus bandejas.
  def agent_params(row)
    params = { 'kind' => row['kind'], 'name' => row['name'], 'display_name' => row['display_name'], 'enabled' => row['enabled'],
               'settings' => DemoKits::People.map(row['settings'].to_h) { |ref| @people[ref.to_s] },
               'sources' => Array(row['sources']) - [NO_CANNED] }
    params['inbox_ids'] = Array(row['inboxes']).filter_map { |ref| @inbox_ids[ref] } if row['inboxes'].present?
    params['channel'] = { 'inbox_id' => @inbox_ids[row['channel_inbox']] } if row['channel_inbox']
    params
  end

  # «Sin predefinidas de la cuenta» no sale en la pantalla (Motor2::Search::NO_CANNED): se conserva del kit.
  def keep_no_canned(template, row)
    return unless Array(row['sources']).include?(NO_CANNED)

    template.update_columns(motor2: template.motor2.merge('sources' => Array(template.motor2['sources']) | [NO_CANNED])) # rubocop:disable Rails/SkipsModelValidations
  end
end
