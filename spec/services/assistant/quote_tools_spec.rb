# frozen_string_literal: true

require 'rails_helper'

# Dali — cotizaciones: buscar en el catálogo, proponer (tarjeta) y crear/mandar al confirmar.
RSpec.describe Assistant::QuoteTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let!(:service) { account.catalog_items.create!(name: 'Mantenimiento de minisplit', kind: :service, price: 1200, unit: 'servicio') }

  before { CaseSetting.for_account(account).update!(default_tax_percent: 16) }

  def propose(items, **extra)
    tools.call('propose_create_quote', { 'contact_id' => contact.id, 'items' => items }.merge(extra.stringify_keys))
  end

  it 'busca en el catálogo con su precio' do
    found = tools.call('search_catalog', { 'query' => 'minisplit' })[:result]
    expect(found[:items].first).to include(id: service.id, price: 1200.0, unit: 'servicio')
  end

  it 'propone con el precio del catálogo y una partida libre, con totales e IVA de la empresa' do
    result = propose([{ 'catalog_item_id' => service.id, 'quantity' => 3 },
                      { 'description' => 'Capacitor 35 µF', 'quantity' => 1, 'unit_price' => 180 }])
    labels = result[:proposal]['labels']
    expect(labels['items'].pluck('unit_price')).to eq([1200.0, 180.0])
    expect(labels['totals']).to eq('net' => 3780.0, 'tax' => 604.8, 'total' => 4384.8)
    expect(labels['rows']).to include(['CLIENT', 'Mario Pérez'])
  end

  it 'no propone una partida libre sin precio: pide preguntarlo' do
    result = propose([{ 'description' => 'Instalación especial', 'quantity' => 1 }])
    expect(result[:result][:error]).to include('Falta el precio')
    expect(result[:proposal]).to be_nil
  end

  it 'al confirmar crea la cotización en borrador con sus partidas y la manda por su conversación' do
    proposal = propose([{ 'catalog_item_id' => service.id, 'quantity' => 2 }])[:proposal]
    payload = proposal['payload'].merge('items' => [{ 'catalog_item_id' => service.id, 'quantity' => 2, 'unit_price' => 1000 }])

    result = executor.call('create_quote', payload)
    quote = account.quotes.last
    expect(result['label']).to include(quote.folio)
    expect(quote).to have_attributes(status: 'draft', contact_id: contact.id, assignee_id: user.id)
    expect(quote.items.sole).to have_attributes(catalog_item_id: service.id, unit_price: 1000, tax_percent: 16)
    expect(quote.net_total).to eq(2000)

    expect { executor.call('send_quote', { 'quote_id' => quote.id }) }
      .to raise_error(Assistant::Executor::Refused)
    create(:conversation, account: account, contact: contact)
    executor.call('send_quote', { 'quote_id' => quote.id })
    expect(quote.reload.status).to eq('sent')
  end

  it 'sin permiso de escribir en Ventas no propone' do
    grant = instance_double(Access::Grant, writable?: false, contacts: account.contacts, case_tickets: account.case_tickets)
    limited = Assistant::Tools.new(account: account, user: user, grant: grant, zone: Time.zone)
    result = limited.call('propose_create_quote', { 'contact_id' => contact.id, 'items' => [{ 'quantity' => 1 }] })
    expect(result[:result][:error]).to include('permiso')
  end

  it 'lista las cotizaciones del cliente' do
    executor.call('create_quote', propose([{ 'catalog_item_id' => service.id, 'quantity' => 1 }])[:proposal]['payload'])
    listed = tools.call('list_quotes', { 'contact_id' => contact.id })[:result][:quotes]
    expect(listed.first).to include(contact: 'Mario Pérez', status: 'draft', net_total: 1200.0)
  end
end
