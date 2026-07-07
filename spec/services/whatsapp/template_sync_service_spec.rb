# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — sync con upsert por fila + parser inverso de components.
RSpec.describe Whatsapp::TemplateSyncService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:provider) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

  let(:remote) do
    [
      {
        'id' => '555', 'name' => 'cobro_vencido', 'language' => 'es', 'category' => 'UTILITY',
        'status' => 'APPROVED', 'quality_score' => { 'score' => 'GREEN' },
        'components' => [
          { 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Hola {{1}}', 'example' => { 'header_text' => ['Juan'] } },
          { 'type' => 'BODY', 'text' => 'Saldo {{1}}', 'example' => { 'body_text' => [['$100']] } },
          { 'type' => 'FOOTER', 'text' => 'Gracias' },
          { 'type' => 'BUTTONS', 'buttons' => [
            { 'type' => 'QUICK_REPLY', 'text' => 'Sí' },
            { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x/{{1}}', 'example' => ['https://x/a'] }
          ] }
        ]
      }
    ]
  end

  before do
    allow(channel).to receive(:provider_service).and_return(provider)
    allow(provider).to receive(:templates_list).and_return(remote)
  end

  it 'crea la fila parseando los components inversos' do
    result = described_class.new(channel).perform

    expect(result.synced).to eq(1)
    expect(result.created).to eq(1)

    t = channel.whatsapp_templates.find_by(name: 'cobro_vencido', language: 'es')
    expect(t).to have_attributes(
      meta_template_id: '555', status: 'APPROVED', quality_score: 'GREEN', category: 'UTILITY',
      header_type: 'text', header_content: 'Hola {{1}}', body_text: 'Saldo {{1}}', footer_text: 'Gracias'
    )
    expect(t.sample_values).to eq('header' => ['Juan'], 'body' => ['$100'])
    expect(t.buttons).to eq(
      [
        { 'type' => 'QUICK_REPLY', 'text' => 'Sí' },
        { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x/{{1}}', 'example' => ['https://x/a'] }
      ]
    )
  end

  it 'es idempotente: la segunda corrida actualiza, no duplica' do
    described_class.new(channel).perform
    result = described_class.new(channel).perform

    expect(result.created).to eq(0)
    expect(result.updated).to eq(1)
    expect(channel.whatsapp_templates.where(name: 'cobro_vencido', language: 'es').count).to eq(1)
  end

  it 'no borra locales sin contraparte remota' do
    local = create(:whatsapp_template, account: channel.account, channel_whatsapp: channel,
                                       name: 'solo_local', language: 'es', meta_template_id: nil)
    described_class.new(channel).perform

    expect(WhatsappTemplate.exists?(local.id)).to be(true)
  end

  it 'reconcilia un draft local con su contraparte de Meta (mismo name+language)' do
    draft = create(:whatsapp_template, account: channel.account, channel_whatsapp: channel,
                                       name: 'cobro_vencido', language: 'es', status: 'DRAFT', meta_template_id: nil)
    described_class.new(channel).perform

    expect(draft.reload).to have_attributes(meta_template_id: '555', status: 'APPROVED')
  end
end
