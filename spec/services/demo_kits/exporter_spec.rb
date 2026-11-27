# frozen_string_literal: true

require 'rails_helper'

# Ajustes › Demostraciones — un kit exportado de una cuenta se importa en otra con las personas que se eligen; después
# se limpia lo de la demo o se quita todo.
RSpec.describe DemoKits::Exporter do
  let(:source) { create(:account) }
  let(:target) { create(:account) }
  let(:stylist) { create(:user, account: source, name: 'Ana') }
  let(:target_user) { create(:user, account: target, role: :administrator, name: 'Pedro') }
  let(:inbox) { create(:inbox, account: source, name: 'Chat de la estética') }
  let(:agent) do
    Motor2::Functions::Form.new(source, { 'kind' => 'customers', 'name' => 'Recepción', 'display_name' => 'Luz', 'enabled' => true,
                                          'inbox_ids' => [inbox.id], 'sources' => ['catalog'],
                                          'settings' => { 'user_id' => stylist.id, 'goal' => 'appointment', 'welcome' => '¡Hola!',
                                                          'areas' => { 'sales' => { 'on' => true, 'booking' => 'appointment',
                                                                                    'appointment_user_ids' => [stylist.id],
                                                                                    'case_type_id' => 99 } } } },
                                user: stylist).save
  end
  let(:category) { source.catalog_categories.create!(name: 'Estética') }

  before do
    CatalogParameters.ensure!(source)
    source.catalog_items.create!(name: 'Corte de dama', sku: 'EST-01', kind: :service, price: 350, duration_minutes: 45,
                                 price_includes_tax: true, catalog_category: category)
  end

  def kit = described_class.new(source, template_ids: [agent.id], category_ids: [category.id], name: 'Estética').call

  it 'lleva el agente, su bandeja, el catálogo y las personas como lugares (sin ids de la cuenta)' do
    data = kit
    expect(data).to include('kit' => 'kontrolya-demo', 'name' => 'Estética', 'people' => [{ 'ref' => 'p1', 'name' => 'Ana' }])
    expect(data['catalog']['items'].first).to include('sku' => 'EST-01', 'duration_minutes' => 45, 'price_includes_tax' => true)
    settings = data['agents'].first['settings']
    expect(settings).to include('user_id' => 'p1', 'goal' => 'appointment', 'welcome' => '¡Hola!')
    expect(settings.dig('areas', 'sales')).to include('appointment_user_ids' => ['p1'])
    expect(settings.dig('areas', 'sales')).not_to have_key('case_type_id')
  end

  def import(choices = { people: { 'p1' => target_user.id }, inboxes: { 'i1' => 'new' } })
    DemoKits::Importer.new(target, kit, user: target_user, **choices).call
  end

  it 'se importa en otra cuenta con quien se eligió (y otra vez actualiza, no duplica)' do
    result = import
    template = target.tracking_templates.find(result.ids(:tracking_template_ids).first)
    expect(template.motor2['answers']).to include('user_id' => target_user.id)
    expect(template.motor2.dig('answers', 'areas', 'sales', 'appointment_user_ids')).to eq([target_user.id])
    expect(template.attend_inbox_ids).to eq(result.ids(:inbox_ids))
    expect(target.catalog_items.find_by(sku: 'EST-01')).to have_attributes(duration_minutes: 45, price: 350)
    expect(import(inboxes: { 'i1' => result.ids(:inbox_ids).first }).ids(:catalog_item_ids)).to be_empty
  end

  it 'después se limpia lo de la demo o se quita todo' do
    result = import
    contact = create(:contact, account: target)
    create(:conversation, account: target, inbox_id: result.ids(:inbox_ids).first, contact: contact)
    expect(DemoKits::Cleaner.new(result).clean).to include(conversations: 1, contacts: 1)

    DemoKits::Cleaner.new(result).remove
    expect(target.tracking_templates.where(id: result.ids(:tracking_template_ids))).to be_empty
    expect(target.inboxes.where(id: result.ids(:inbox_ids))).to be_empty
    expect(target.catalog_items.where(sku: 'EST-01')).to be_empty
  end

  it 'la demo incluida «Estética Bella Luz» es un kit válido' do
    data = DemoKits::Library.load('estetica')
    expect(DemoKits::Library.summary(data)).to include(items: 16, categories: 1)
    expect(data['agents'].first['settings'].to_json).not_to match(/"user_id":\s*\d/)
  end
end
