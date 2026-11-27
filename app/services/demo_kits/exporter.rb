# frozen_string_literal: true

# Ajustes › Demostraciones › Exportar — arma el kit de demo (JSON) con los agentes listos que se eligieron y lo que usan:
#   - sus bandejas (canal, horario, zona; las de chat de la página se vuelven a crear al importar);
#   - las personas que atienden o reciben lo que pasa el agente, como «lugares» (p1, p2…): al importar se elige quién
#     de la cuenta va en cada uno (no viajan usuarios, tokens de Google ni equipos);
#   - el catálogo de las categorías elegidas (con impuesto, «el precio ya incluye el impuesto», unidad y duración).
# No lleva conversaciones, contactos, tokens ni respuestas predefinidas de la cuenta. Ids que no existen en otra
# cuenta (equipos, tipos de caso, eventos, fuentes de conocimiento) se quitan: el agente usa los de por omisión.
#
#   DemoKits::Exporter.new(account, template_ids: [35602], category_ids: [7], name: 'Estética Bella Luz').call → Hash
class DemoKits::Exporter
  VERSION = 1
  PORTABLE_SOURCES = %w[catalog canned_response -canned_response article].freeze

  def initialize(account, template_ids:, category_ids: [], name: nil)
    @account = account
    @templates = account.tracking_templates.where(id: template_ids, archived_at: nil).where.not(agent_function: nil).order(:id).to_a
    @category_ids = Array(category_ids).map(&:to_i)
    @name = name.to_s.squish.presence || @templates.map(&:name).to_sentence.presence || 'Demo'
    @people = {}
    @inboxes = {}
  end

  def call
    agents = @templates.map { |t| agent(t) }
    { 'kit' => 'kontrolya-demo', 'version' => VERSION, 'name' => @name.first(200), 'exported_at' => Time.current.iso8601,
      'people' => @people.values, 'inboxes' => @inboxes.values, 'catalog' => catalog, 'agents' => agents }
  end

  private

  def agent(template)
    data = template.motor2.to_h
    settings = portable(data['answers'].to_h).merge(data.slice('welcome', 'instructions', 'voice', 'voice_mode'))
    { 'kind' => template.agent_function, 'name' => template.name, 'display_name' => template.customer_display_name,
      'enabled' => template.attending, 'inboxes' => Array(template.attend_inbox_ids).filter_map { |id| inbox_ref(id) },
      'channel_inbox' => (inbox_ref(template.inbox_id) unless template.attending), 'settings' => settings,
      'sources' => Array(data['sources']) & PORTABLE_SOURCES }.compact
  end

  # Las respuestas del asistente sin ids de la cuenta: personas → «p1», lo demás que no existe en otra cuenta, fuera.
  def portable(answers) = DemoKits::People.map(answers, drop: true) { |id| person_ref(id) }

  def person_ref(id)
    user = id.present? && @account.users.find_by(id: id)
    return nil unless user

    (@people[user.id] ||= { 'ref' => "p#{@people.size + 1}", 'name' => user.name })['ref']
  end

  def inbox_ref(id)
    inbox = id.present? && @account.inboxes.find_by(id: id)
    return nil unless inbox

    (@inboxes[inbox.id] ||= inbox_data(inbox, "i#{@inboxes.size + 1}"))['ref']
  end

  def inbox_data(inbox, ref)
    channel = inbox.channel
    web = inbox.channel_type == 'Channel::WebWidget'
    { 'ref' => ref, 'name' => inbox.name, 'channel' => web ? 'web_widget' : inbox.channel_type.to_s.demodulize.underscore,
      'website_url' => (channel.website_url if web), 'widget_color' => (channel.widget_color if web),
      'welcome_title' => (channel.welcome_title if web), 'welcome_tagline' => (channel.welcome_tagline if web),
      'timezone' => inbox.timezone, 'working_hours_enabled' => inbox.working_hours_enabled,
      'working_hours' => inbox.working_hours.order(:day_of_week).map { |w| hours(w) } }.compact
  end

  def hours(row)
    row.slice('day_of_week', 'closed_all_day', 'open_all_day', 'open_hour', 'open_minutes', 'close_hour', 'close_minutes')
  end

  def catalog
    categories = @account.catalog_categories.where(id: @category_ids).flat_map { |c| [c, *c.children] }.uniq
    items = @account.catalog_items.where(catalog_category_id: categories.map(&:id)).includes(:catalog_category, :catalog_unit, :tax_rate)
    { 'categories' => categories.map { |c| { 'name' => c.name, 'parent' => c.parent&.name } },
      'items' => items.order(:catalog_category_id, :name).map { |i| item(i) } }
  end

  def item(row)
    { 'sku' => row.sku, 'name' => row.name, 'kind' => row.kind, 'category' => row.catalog_category&.path, 'unit' => row.unit,
      'price' => row.price.to_f, 'currency' => row.currency, 'price_includes_tax' => row.price_includes_tax,
      'tax_percent' => row.quote_tax_percent.to_f, 'duration_minutes' => row.duration_minutes, 'description' => row.description,
      'active' => row.active }.compact
  end
end
