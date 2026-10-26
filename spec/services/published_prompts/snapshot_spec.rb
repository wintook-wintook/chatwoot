# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F1). Sin escrituras: todo se arma con build.
RSpec.describe PublishedPrompts::Snapshot do
  let(:template) do
    build(:tracking_template,
          objective: 'Vender servicios de grúa',
          ai_context: 'Empresa de grúas',
          complementary_prompt: "Cotiza con {{hoja:precios}} y manda {{catalogo_pdf}}.\n@agendar_calendar",
          keyword_actions: [{ 'keyword' => 'baja', 'action' => 'stop', 'direction' => 'incoming' }],
          inbox_id: 7, kbase_hook_id: 9, tags: ['vip'], whatsapp_templates: [{ 'name' => 'hola' }],
          calendar_integration_ids: [3], booking_calendar_ids: { 'x' => 1 },
          retry_interval_value: 2, retry_interval_unit: 'hours', timezone: '')
  end

  let(:attributes) { described_class.new(template).attributes }

  it 'copia el prompt y lo que no depende de la cuenta' do
    expect(attributes).to include(
      objective: 'Vender servicios de grúa',
      ai_context: 'Empresa de grúas',
      prompt: template.complementary_prompt,
      keyword_actions: template.keyword_actions
    )
    expect(attributes[:settings]).to include('retry_interval_value' => 2, 'retry_interval_unit' => 'hours')
  end

  it 'deja fuera lo atado a la cuenta del autor y los ajustes vacíos' do
    expect(attributes.keys).not_to include(:inbox_id, :kbase_hook_id, :tags, :whatsapp_templates,
                                           :calendar_integration_ids, :booking_calendar_ids, :user_id)
    expect(attributes[:settings]).not_to have_key('timezone')
  end

  it 'lista lo que quien lo baje tiene que configurar' do
    expect(attributes[:requirements]).to eq([
                                              { 'kind' => 'google_sheet', 'name' => 'precios' },
                                              { 'kind' => 'attachment', 'name' => 'catalogo_pdf' },
                                              { 'kind' => 'calendar' }
                                            ])
  end
end
