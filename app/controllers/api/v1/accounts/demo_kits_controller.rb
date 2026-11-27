# frozen_string_literal: true

# Ajustes › Demostraciones (solo administradores) — kits de demo en JSON: exportar agentes listos con lo que usan,
# importarlos (de un archivo o de las demos que trae Kontrolya) y, después de la demo, limpiar o quitar.
#   GET    /demo_kits                 demos incluidas, importaciones, agentes y categorías para exportar, personas y bandejas
#   POST   /demo_kits/export          { template_ids: [], category_ids: [], name } → archivo .json
#   POST   /demo_kits/preview         { kit: 'estetica' } o { data: {…json…} } → resumen (qué crea, lugares a elegir)
#   POST   /demo_kits/import          { kit | data, people: { p1: user_id }, inboxes: { i1: 'new' | inbox_id } }
#   POST   /demo_kits/:id/clean       «Limpiar lo de la demo» (pláticas, cotizaciones, citas)
#   DELETE /demo_kits/:id             «Quitar la demo» (y lo que creó)
class Api::V1::Accounts::DemoKitsController < Api::V1::Accounts::BaseController
  MAX_BYTES = 5.megabytes

  before_action :require_admin
  before_action :set_import, only: %i[clean destroy]

  def index
    render json: { kits: DemoKits::Library.all, imports: imports, agents: agents, categories: categories, users: users,
                   inboxes: inboxes }
  end

  def export
    data = DemoKits::Exporter.new(Current.account, template_ids: Array(params[:template_ids]), category_ids: Array(params[:category_ids]),
                                                   name: params[:name]).call
    send_data JSON.pretty_generate(data), filename: "demo-#{data['name'].parameterize.presence || 'kontrolya'}.json",
                                          type: 'application/json'
  end

  def preview
    render json: DemoKits::Library.summary(kit_data).merge(name: kit_data['name'], description: kit_data['description'])
  rescue JSON::ParserError, DemoKits::Importer::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def import
    result = DemoKits::Importer.new(Current.account, kit_data, user: current_user, people: plain(params[:people]),
                                                               inboxes: plain(params[:inboxes]), source: params[:kit].presence || 'archivo').call
    render json: { import: import_json(result) }
  rescue JSON::ParserError, DemoKits::Importer::Error, ActiveRecord::RecordInvalid, ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def clean
    render json: { cleaned: DemoKits::Cleaner.new(@import).clean }
  end

  def destroy
    render json: { cleaned: DemoKits::Cleaner.new(@import).remove }
  end

  private

  def require_admin
    render_access_denied unless access_grant.admin?
  end

  def set_import
    @import = DemoImport.where(account_id: Current.account.id).find(params[:id])
  end

  # De las demos incluidas o el JSON que subió (leído en el navegador).
  def kit_data
    @kit_data ||= if params[:kit].present?
                    DemoKits::Library.load(params[:kit])
                  else
                    raw = params[:data].is_a?(String) ? params[:data] : params[:data].to_unsafe_h.to_json
                    raise DemoKits::Importer::Error, 'El archivo es muy grande.' if raw.bytesize > MAX_BYTES

                    data = JSON.parse(raw)
                    raise DemoKits::Importer::Error, 'El archivo no es un kit de demo de Kontrolya.' unless data['kit'] == 'kontrolya-demo'

                    data
                  end
  end

  def plain(value) = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h

  def imports = DemoImport.where(account_id: Current.account.id).order(created_at: :desc).limit(50).map { |i| import_json(i) }

  def import_json(row)
    { id: row.id, name: row.name, source: row.source, created_at: row.created_at, user: row.user&.name,
      counts: DemoImport::KEYS.index_with { |k| row.ids(k).size }, agent_ids: row.ids(:tracking_template_ids),
      inbox_ids: row.ids(:inbox_ids), website_tokens: website_tokens(row.ids(:inbox_ids)) }
  end

  # Para abrir el chat de la página de la demo (/widget_tests?website_token=…).
  def website_tokens(inbox_ids) = Channel::WebWidget.joins(:inbox).where(inboxes: { id: inbox_ids }).pluck(:website_token)

  def agents
    Current.account.tracking_templates.where(archived_at: nil).where.not(agent_function: nil).order(:name)
           .map { |t| { id: t.id, name: t.name, kind: t.agent_function } }
  end

  def categories
    Current.account.catalog_categories.includes(:parent).order(:name)
           .map { |c| { id: c.id, name: c.path, items: c.catalog_items.count } }
  end

  def users = Current.account.users.order(:name).map { |u| { id: u.id, name: u.name, calendar: calendar_user_ids.include?(u.id) } }

  def calendar_user_ids = @calendar_user_ids ||= UserCalendarIntegration.where(account_id: Current.account.id).pluck(:user_id)

  def inboxes
    Current.account.inboxes.where.not(channel_type: 'Channel::Internal').order(:name)
           .map { |i| { id: i.id, name: i.name, channel_type: i.channel_type } }
  end
end
