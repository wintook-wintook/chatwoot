# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — «Continuar la conversación anterior».
RSpec.describe TrackingAssistantSession do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:otro) { create(:user, account: account, role: :administrator) }
  let(:template) do
    create(:tracking_template, account: account, complementary_prompt: "@ruta(info #info: pregunta algo): @buscar_articulo\n")
  end
  let(:mensajes) { [{ 'role' => 'user', 'content' => 'quiero que cotice' }, { 'role' => 'assistant', 'content' => 'listo' }] }

  def cerrada(user, hace)
    described_class.create!(account: account, user: user, tracking_template: template, status: 'saved',
                            messages: mensajes, draft: 'borrador viejo', updated_at: hace.ago)
  end

  it 'la anterior es la propia más reciente; si no hay propia, la de otro' do
    ajena = cerrada(otro, 1.hour)
    expect(described_class.previous_for(template, admin)).to eq(ajena)
    propia = cerrada(admin, 2.days)
    expect(described_class.previous_for(template, admin)).to eq(propia)
  end

  it 'continuar crea una nueva con el historial, el Entrenamiento de hoy y un aviso; la anterior no cambia' do
    anterior = cerrada(admin, 1.day)
    nueva = anterior.continue_as(admin)

    expect(nueva).to be_open
    expect(nueva.tracking_template).to eq(template)
    expect(nueva.draft).to eq(template.complementary_prompt)
    expect(nueva.messages.first(2)).to eq(mensajes)
    expect(nueva.messages.last).to include('role' => 'assistant', 'content' => start_with('Seguimos la conversación anterior'))
    expect(anterior.reload.status).to eq('saved')
    expect(anterior.messages).to eq(mensajes)
  end
end
