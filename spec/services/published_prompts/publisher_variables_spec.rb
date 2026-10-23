# frozen_string_literal: true

require 'rails_helper'

# proyecto@adaptar_prompts_publicados (F4): los datos del negocio del autor viajan como variables.
RSpec.describe PublishedPrompts::Publisher do
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account, role: :administrator) }
  let(:prompt) { "[ROL]\nEres el asistente de Grúas del Norte. Llámanos al 81 1234 5678." }
  let(:template) do
    create(:tracking_template, account: account, complementary_prompt: prompt,
                               ai_context: 'Atiende a clientes de Grúas del Norte.')
  end
  let(:variables) do
    [{ 'text' => 'Grúas del Norte', 'label' => 'Nombre del negocio' }, { 'text' => '81 1234 5678', 'label' => 'Teléfono' }]
  end

  def publish(**args)
    described_class.new(template, author).publish!(**args)
  end

  it 'la copia publicada lleva las marcas; el agente del autor no cambia' do
    pub = publish(variables: variables)

    expect(pub.prompt).to eq(
      "[ROL]\nEres el asistente de <PENDIENTE: Nombre del negocio>. Llámanos al <PENDIENTE: Teléfono>."
    )
    expect(pub.variables).to eq(variables)
    expect(template.reload.complementary_prompt).to eq(prompt)
  end

  it 'el Contexto no se toca (la pestaña Configurar no lo edita)' do
    expect(publish(variables: variables).ai_context).to eq('Atiende a clientes de Grúas del Norte.')
  end

  it 'al republicar sin mandar variables, usa las de la versión anterior' do
    publish(variables: variables)
    pub = publish(title: 'Otra vez')

    expect(pub).to have_attributes(version: 2, variables: variables)
    expect(pub.prompt).to include('<PENDIENTE: Teléfono>')
  end

  it 'con una lista vacía las quita' do
    publish(variables: variables)

    expect(publish(variables: []).prompt).to eq(prompt)
  end

  it 'no publica si una variable no aparece en el Entrenamiento' do
    expect { publish(variables: [{ 'text' => 'Monterrey', 'label' => 'Ciudad' }]) }
      .to raise_error(PublishedPrompts::Variables::Invalid, /Monterrey/)
    expect(PublishedPrompt.where(tracking_template: template)).not_to exist
  end

  it 'la copia bajada nace con las marcas y la pestaña Configurar las pide' do
    pub = publish(variables: variables)
    otra = create(:account)
    copia = PublishedPrompts::Installer.new(pub, otra, create(:user, account: otra)).install!

    claves = ContactTrackings::Assistant::AdaptationInventory.new(copia.complementary_prompt, account: otra).call.pluck(:key)
    expect(claves).to include('var:nombre del negocio', 'var:teléfono')
  end
end
