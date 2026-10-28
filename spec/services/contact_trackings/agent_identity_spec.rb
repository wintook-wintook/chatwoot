# frozen_string_literal: true

require 'rails_helper'

# Agentes IA — el cliente ve el nombre del agente (o ninguno), no el del usuario con el
# que se guardan sus mensajes.
RSpec.describe ContactTrackings::AgentIdentity do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Mariana Duarte') }
  let(:conversation) { create(:conversation, account: account) }

  def agent(name)
    TrackingTemplate.new(customer_display_name: name)
  end

  def build(params)
    Messages::MessageBuilder.new(user, conversation, { content: 'Hola', private: false }.merge(params)).perform
  end

  it 'el mensaje del agente lleva su nombre para el cliente' do
    message = build(ai_agent: described_class.for(agent('  Sofía  ')))
    expect(message.content_attributes).to include('ai_agent' => true, 'ai_agent_name' => 'Sofía')
    expect(message.sender_name).to eq('Sofía')
  end

  it 'sin nombre del agente sale sin nombre (no el del usuario)' do
    message = build(ai_agent: described_class.for(agent('')))
    expect(message.sender_name).to be_nil
  end

  it 'los mensajes de personas siguen con su nombre' do
    expect(build({}).sender_name).to eq(user.available_name)
  end

  it 'desde la API no se puede marcar un mensaje como del agente' do
    params = ActionController::Parameters.new(content: 'Hola', private: false, ai_agent: { name: 'Falso' })
    message = Messages::MessageBuilder.new(user, conversation, params).perform
    expect(message.content_attributes['ai_agent']).to be_nil
    expect(message.sender_name).to eq(user.available_name)
  end

  it 'el nombre del agente se limpia y tiene tope de 30' do
    template = agent('  Sofía   Asistente ')
    template.valid?
    expect(template.customer_display_name).to eq('Sofía Asistente')
    template.customer_display_name = 'x' * 31
    template.valid?
    expect(template.errors[:customer_display_name]).to be_present
  end
end
