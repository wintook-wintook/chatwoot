# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_whatsapp_mejoras — dónde se usa una plantilla, antes de borrarla.
RSpec.describe Whatsapp::TemplateUsage do
  let!(:account) { create(:account) }
  let(:plantillas) { [{ 'name' => 'pago', 'language' => 'es_MX', 'status' => 'approved', 'components' => [] }] }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              message_templates: plantillas)
  end
  let(:inbox) { channel.inbox }
  let(:template) { create(:whatsapp_template, channel_whatsapp: channel, account: account, name: 'pago', language: 'es_MX') }
  let(:contact) { create(:contact, account: account) }

  def uso
    described_class.call(template)
  end

  def agente(nombres)
    create(:tracking_template, account: account, inbox_id: inbox.id, whatsapp_templates: nombres)
  end

  it 'sin uso devuelve todo vacío' do
    expect(uso).to eq(agents: [], trackings_count: 0, campaigns: [], portals: [])
  end

  it 'cuenta agentes y seguimientos vivos de esa bandeja, no los terminados ni otra plantilla' do
    uno = agente(%w[pago otra])
    agente(%w[otra])
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, status: 'active', whatsapp_templates: %w[pago pago pago])
    create(:contact_tracking, account: account, contact: create(:contact, account: account), inbox: inbox, status: 'completed',
                              whatsapp_templates: %w[pago pago pago])

    expect(uso).to include(agents: [{ id: uno.id, name: uno.name }], trackings_count: 1)
  end

  it 'si queda el mismo nombre en otro idioma, agentes y seguimientos no se rompen' do
    channel.update!(message_templates: plantillas + [plantillas.first.merge('language' => 'en_US')])
    agente(%w[pago])

    expect(uso).to include(agents: [], trackings_count: 0)
  end

  it 'cuenta campañas sin terminar y el acuse del portal' do
    uno = agente(%w[pago])
    viva = create(:tracking_campaign, account: account, inbox: inbox, tracking_template: uno, status: 'running')
    create(:tracking_campaign, account: account, inbox: inbox, tracking_template: uno, status: 'finished')
    portal = CasePortal.create!(account: account, inbox: inbox, name: 'Soporte', slug: 'soporte', acuse_template_name: 'pago',
                                acuse_template_language: 'es_MX')

    expect(uso).to include(campaigns: [{ id: viva.id, name: viva.name }], portals: [{ id: portal.id, name: portal.name }])
  end
end
