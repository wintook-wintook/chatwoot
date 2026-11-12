# frozen_string_literal: true

require 'rails_helper'

# Base común: «Cómo habla tu empresa» y la nota del contacto, en Seguimiento IA y Agentes listos.
RSpec.describe AgentBase::CompanyVoice do
  let(:account) { create(:account) }

  it 'guarda solo lo que tiene texto y arma el bloque' do
    described_class.update!(account, { 'tone' => ' De tú ', 'never' => 'No ofrecer descuentos', 'who' => '' })

    expect(described_class.get(account)).to include('tone' => 'De tú', 'who' => '')
    block = described_class.block(account)
    expect(block).to include('CÓMO HABLA LA EMPRESA', '- Tono: De tú', '- Nunca: No ofrecer descuentos')
    expect(block).not_to include('Quiénes somos')
  end

  it 'sin nada guardado no agrega nada' do
    expect(described_class.block(account)).to eq('')
  end

  it 'el Seguimiento IA y el agente de prospectos lo toman, con la nota del contacto' do
    described_class.update!(account, { 'roles' => 'Distribuidores: son socios' })
    user = create(:user, account: account, role: :administrator)
    inbox = create(:inbox, account: account)
    contact = create(:contact, account: account)
    create(:note, account: account, user: user, contact: contact, content: 'Viene recomendado por Juan', is_for_ia: true)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    follow_up = AiFollowUp.create!(account: account, conversation: conversation, contact: contact, objective: 'Saber cómo va',
                                   created_by: user)
    agent = ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', inbox_ids: [inbox.id], settings: {})

    prompts = [AiFollowUps::Prompt.new(follow_up).system, ReadyAgents::Prompt.new(agent, conversation).system]
    expect(prompts).to all(include('Distribuidores: son socios', 'Viene recomendado por Juan'))
  end
end
