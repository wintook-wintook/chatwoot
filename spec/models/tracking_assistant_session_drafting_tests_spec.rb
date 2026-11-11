require 'rails_helper'

# proyecto@crear_agente_conversando FD — al guardar, las pruebas de la conversación
# pasan a la pila del agente.
RSpec.describe TrackingAssistantSession do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) do
    TrackingTemplate.create!(account: account, name: 'Precio Bot', objective: 'cotizar',
                             complementary_prompt: "@ruta(cotizar: precio): -\n@ruta_por_defecto: cotizar")
  end
  let(:sesion) do
    described_class.create!(account: account, user: user, proposal: { 'pruebas' => [
                              { 'frase' => 'precio de la grúa', 'cae_en' => 'cotizar', 'estable' => true },
                              { 'frase' => 'quiero una demo', 'cae_en' => 'demo', 'estable' => true },
                              { 'frase' => 'Precio de la grúa', 'cae_en' => 'cotizar', 'estable' => true }
                            ] })
  end

  it 'crea una prueba por frase, con la ruta solo si existe en el Entrenamiento' do
    sesion.mark_saved!(template)
    casos = template.test_cases.order(:position)
    expect(casos.pluck(:message, :expected_route, :kind)).to eq([['precio de la grúa', 'cotizar', 'ruta'],
                                                                 ['quiero una demo', nil, 'propia']])
  end

  it 'no repite una prueba que la pila ya tiene' do
    ContactTrackings::Assistant::TestCases.add_own(account, template, 'precio de la grúa')
    sesion.mark_saved!(template)
    expect(template.test_cases.where('LOWER(message) = ?', 'precio de la grúa').count).to eq(1)
  end
end
