# frozen_string_literal: true

require 'rails_helper'

# 11/11/2026 (cuenta 1128, Agente Escuela v2): la ficha más parecida quedaba en segundo
# lugar, y los datos del Entrenamiento y el Contexto no contaban como fuente.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:template) { create(:tracking_template, account: account, inbox: inbox, ai_context: 'Instalaciones en Ecatepec.') }
  let(:prompt) { "[DATOS DE LA ESCUELA]\n- Dirección: Av. Circunvalación Poniente 197." }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, tracking_template: template,
                              complementary_prompt: prompt)
  end
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, content: '¿Dónde están?') }
  let(:service) { described_class.new(message, tracking: tracking, branch: nil) }

  def item(id, distance)
    Struct.new(:id, :title, :neighbor_distance).new(id, "item #{id}", distance)
  end

  describe '#by_similarity' do
    it 'entrega primero el item más parecido de cualquiera de las consultas' do
      derecho = item(1, 0.52)
      trabajo_social = item(2, 0.33)
      administracion = item(3, 0.54)
      lists = [[derecho, administracion], [trabajo_social]]

      expect(service.send(:by_similarity, [derecho, trabajo_social, administracion], lists).map(&:id)).to eq([2, 1, 3])
    end

    it 'toma la mejor similitud cuando el item salió en dos consultas' do
      lejos = item(1, 0.6)
      cerca = item(1, 0.2)
      otro = item(2, 0.4)

      ordenados = service.send(:by_similarity, [lejos, otro], [[lejos, otro], [cerca]])
      expect(ordenados.map(&:id)).to eq([1, 2])
      expect(ordenados.first.neighbor_distance).to eq(0.2)
    end
  end

  it 'incluye el Contexto del agente en el system prompt' do
    expect(service.send(:agent_context_block)).to eq("Contexto del negocio:\nInstalaciones en Ecatepec.")
  end

  it 'los datos del Entrenamiento cuentan como fuente si el agente tiene uno' do
    expect(service.send(:agent_data_rule)).to include('también son fuente')
  end

  context 'without Entrenamiento propio' do
    let(:prompt) { nil }

    it 'no agrega la regla' do
      expect(service.send(:agent_data_rule)).to eq('')
    end
  end
end
