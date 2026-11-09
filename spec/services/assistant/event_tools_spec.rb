# frozen_string_literal: true

require 'rails_helper'

# Dali — captar en la expo: el enlace NFC del evento desde el teléfono.
RSpec.describe Assistant::EventTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, phone_number: '+5215512345678', sync_templates: false, validate_provider_config: false)
  end
  let!(:event) { Event.create!(account: account, name: 'Expo Industrial 2026', starts_at: Time.current) }
  let!(:ana) { create(:user, account: account, name: 'Ana López') }

  it 'encuentra el evento por nombre con sus WhatsApp y el mensaje sugerido' do
    result = tools.call('nfc_links', { 'event' => 'industrial' })[:result]
    expect(result[:event]).to include(id: event.id)
    expect(result[:whatsapp_inboxes].pluck(:id)).to eq([channel.inbox.id])
    expect(result[:default_message]).to include('Expo Industrial 2026')
  end

  it 'propone el enlace de Ana y al confirmar lo crea con su url; la segunda vez lo reutiliza' do
    proposal = tools.call('propose_nfc_link', { 'event_id' => event.id, 'seller' => 'ana' })[:proposal]
    expect(proposal['labels']['rows']).to include(['SELLER', 'Ana López'], ['INBOX', channel.inbox.name])

    first = executor.call('nfc_link', proposal['payload'])
    expect(first['url']).to start_with('https://wa.me/5215512345678')
    expect(event.capture_links.sole.user).to eq(ana)

    again = executor.call('nfc_link', proposal['payload'])
    expect(again['url']).to eq(first['url'])
    expect(event.capture_links.count).to eq(1)
  end

  it 'encuentra el evento sin importar acentos ni mayúsculas' do
    other = Event.create!(account: account, name: 'PRESENTACION KONTROLYA', starts_at: Time.current)
    expect(tools.call('nfc_links', { 'event' => 'presentación kontrolya' })[:result][:event]).to include(id: other.id)
  end

  it 'pregunta cuál si el vendedor es ambiguo' do
    create(:user, account: account, name: 'Ana María')
    error = tools.call('propose_nfc_link', { 'event_id' => event.id, 'seller' => 'ana' })[:result][:error]
    expect(error).to include('Hay varios')
  end

  it 'sin permiso de escribir en Campañas no lo crea' do
    viewer = instance_double(Access::Grant, allowed?: true, writable?: false)
    viewer_tools = Assistant::Tools.new(account: account, user: user, grant: viewer, zone: Time.zone)
    expect(viewer_tools.call('propose_nfc_link', { 'event_id' => event.id })[:result][:error]).to include('permiso')
  end
end
