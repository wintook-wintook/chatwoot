# frozen_string_literal: true

require 'rails_helper'

# Dali — no contestarle a la conversación equivocada: el nombre debe ser el del contacto y, si la
# lista anterior traía varias y no dijo a cuál, se le pregunta.
RSpec.describe Assistant::ReplyTarget do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:inbox) { create(:inbox, account: account) }
  let(:andres) { create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account, name: 'Andrés Liverio')) }
  let(:jane) { create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account, name: 'Jane Doe')) }
  let(:listed) { [{ 'id' => jane.display_id, 'name' => 'Jane Doe' }, { 'id' => andres.display_id, 'name' => 'Andrés Liverio' }] }

  before { allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(true) } # rubocop:disable RSpec/AnyInstance

  def reply(conversation, para, question:, listed: nil)
    tools.turn = { question: question, listed: listed }
    tools.call('propose_reply', { 'conversation_id' => conversation.display_id, 'para' => para, 'content' => 'Sí, hoy' })
  end

  it 'arma la tarjeta con a quién va' do
    result = reply(andres, 'Andres', question: 'contéstale que sí')
    expect(result[:proposal]['labels']).to include('to' => 'Andrés Liverio')
  end

  it 'rechaza si el nombre no es el del contacto de esa conversación' do
    result = reply(jane, 'Andrés Liverio', question: 'contéstale a Andrés')
    expect(result[:proposal]).to be_nil
    expect(result[:result][:error]).to include('es de Jane Doe, no de «Andrés Liverio»')
  end

  it 'con varias en la lista y sin decir a cuál, pide preguntar' do
    result = reply(jane, 'Jane', question: 'contéstale que sí', listed: listed)
    expect(result[:proposal]).to be_nil
    expect(result[:result][:error]).to include('pregúntale a cuál', "Andrés Liverio (##{andres.display_id})")
  end

  it 'con varias en la lista pero diciendo el nombre o el número, va directo' do
    expect(reply(andres, 'Andrés', question: 'contéstale a andres que sí', listed: listed)[:proposal]).to be_present
    expect(reply(andres, 'Andrés', question: "dile a la ##{andres.display_id} que sí", listed: listed)[:proposal]).to be_present
  end

  it 'si leyó una conversación, esa queda como la de la plática' do
    tools.turn = { question: 'qué me escribieron' }
    tools.call('my_conversations', {})
    tools.call('read_conversation', { 'conversation_id' => andres.display_id })
    expect(tools.listed_now).to eq([{ 'id' => andres.display_id, 'name' => 'Andrés Liverio' }])
  end
end
