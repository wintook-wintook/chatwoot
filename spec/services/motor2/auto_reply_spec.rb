# frozen_string_literal: true

require 'rails_helper'

# Campaña con Vendedor IA — la respuesta automática de su WhatsApp Business no cuenta como que contestó: se marca, se
# recuerda en el contacto, los toques siguen, la IA no le contesta y en Resultados sale aparte.
RSpec.describe Motor2::AutoReply do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:channel_email, account: account).inbox }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:campaign) do
    account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'running', tracking_template: seller, inbox: inbox, user: admin,
                                       scheduled_for: 1.day.ago, brief: { 'kind' => 'offer', 'offer_what' => 'Promo' }, touches: { 'attempts' => 3 })
  end
  let(:contact) { create(:contact, account: account, name: 'Mario', email: 'mario@ejemplo.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:tracking) do
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, tracking_template: seller, tracking_campaign: campaign,
                            conversation: conversation, scheduled_for: 2.days.from_now, status: 'scheduled', max_attempts: 3,
                            attempt_count: 1, objective: 'Ofrecer', last_attempt_at: 1.minute.ago, created_at: 1.hour.ago)
  end

  def ours(at)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, content: 'Hola Mario, tenemos una promo',
                     created_at: at)
  end

  def theirs(text, at: Time.current)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text, created_at: at)
  end

  it 'reconoce las frases de máquina, «gracias por comunicarte» solo si llegó en segundos, y no las de una persona' do
    ours(5.seconds.ago)
    expect(described_class.new(tracking, theirs('Gracias por comunicarte con Acme. En breve te atenderemos.')).auto?).to be(true)
    expect(described_class.new(tracking, theirs('Nuestro horario de atención es de 9 a 18 h')).auto?).to be(true)
    expect(described_class.new(tracking, theirs("Elige una opción:\n1. Ventas\n2. Soporte")).auto?).to be(true)
    expect(described_class.new(tracking, theirs('Gracias por tu mensaje')).auto?).to be(true) # en segundos
    expect(described_class.new(tracking, theirs('Sí me interesa, ¿cuánto cuesta?')).auto?).to be(false)
    expect(described_class.new(tracking, theirs('Estoy de vacaciones, regreso el lunes')).auto?).to be(false) # la IA lo reprograma
  end

  it '«gracias por tu mensaje» un rato después es de una persona' do
    ours(10.minutes.ago)
    expect(described_class.new(tracking, theirs('Gracias por tu mensaje, sí me interesa')).auto?).to be(false)
  end

  it 'la marca, la recuerda en el contacto, los toques siguen, la IA no contesta y no cuenta como que contestó' do
    ours(5.seconds.ago)
    message = theirs('Hola, bienvenido a Acme. En breve te atenderemos.')
    expect(Motor2::Runner).not_to receive(:new)
    Motor2::Reply.new(tracking, message).call

    expect(message.reload.content_attributes['auto_reply']).to be(true)
    expect(contact.reload.additional_attributes['auto_reply_text']).to include('bienvenido a Acme')
    expect(conversation.reload.label_list).to include('autorespuesta')
    expect(tracking.reload.status).to eq('scheduled')

    results = TrackingCampaigns::Motor2Results.new(campaign).call
    expect(results.dig(:funnel, :replied)).to eq(0)
    expect(results.dig(:exits, :auto_replied)).to eq(1)
  end

  it 'el texto que ya mandó como automático se reconoce aunque llegue tarde y sin frases típicas' do
    contact.update!(additional_attributes: { 'auto_reply_text' => 'Hola 👋 soy Mario de Taller Ruiz, ahorita te contesto' })
    ours(1.hour.ago)
    expect(described_class.new(tracking, theirs('Hola 👋 soy Mario de Taller Ruiz, ahorita te contesto!')).auto?).to be(true)
  end
end
