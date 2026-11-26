# frozen_string_literal: true

require 'rails_helper'

# «Redactar con Dali»: escribe con lo que ya tiene la campaña (la ficha, las ligas…), en formato de WhatsApp o en
# bloques de correo; el botón del correo solo lleva ligas de la campaña.
RSpec.describe TrackingCampaigns::CopyWriter do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { Motor2::Functions::Form.new(account, { kind: 'campaign_seller', name: 'Vendedor', enabled: true, settings: {} }, user: admin).save }
  let(:links) { [{ 'name' => 'Comprar', 'url' => 'https://ejemplo.com/compra', 'use' => 'package' }] }
  let(:campaign) do
    brief = TrackingCampaigns::Motor2Brief.brief('kind' => 'offer', 'offer_goal' => 'external', 'goal_keyword' => 'COMPRADO',
                                                 'offer_what' => 'Mantenimiento preventivo', 'links' => links,
                                                 'facts' => { 'price' => '$1,800 (antes $2,600)' })
    account.tracking_campaigns.create!(name: 'Promo', engine: '2', status: 'saved', tracking_template: seller, user: admin, brief: brief,
                                       touches: { 'attempts' => 2 })
  end

  def writer(params, answer)
    described_class.new(campaign, params).tap do |w|
      allow(w).to receive_messages(available?: true, chat: answer)
    end
  end

  it 'WhatsApp: le pasa lo que sabe, sin la URL de la liga (se agrega sola), y deja las negritas con un asterisco' do
    w = writer({ target: 'info', tone: 'entusiasta' }, { 'texto' => '🔥 **Promo** de mantenimiento' })
    expect(w.call).to eq(text: '🔥 *Promo* de mantenimiento')
    expect(w).to have_received(:chat) do |system:, user:, **|
      expect(user).to include('Mantenimiento preventivo', '$1,800 (antes $2,600)')
      expect(system).to include('(Comprar) se agrega sola', '*COMPRADO*', 'entusiasta')
      expect(system).not_to include('https://ejemplo.com/compra')
    end
  end

  it '«sin emojis» manda sobre las reglas' do
    w = writer({ target: 'info', instruction: 'sin emojis' }, { 'texto' => '🔥 Promo ✅ hoy' })
    expect(w.call).to eq(text: 'Promo hoy')
  end

  it 'correo: asunto, asunto B y bloques; un botón con una liga que no es de la campaña se quita' do
    answer = { 'asunto' => '{{contacto}}, tu mantenimiento', 'asunto_b' => 'Ahorra hoy',
               'bloques' => [{ 'tipo' => 'texto', 'texto' => 'Hola {{contacto}}' },
                             { 'tipo' => 'boton', 'texto' => 'Comprar', 'url' => 'https://ejemplo.com/compra' },
                             { 'tipo' => 'boton', 'texto' => 'Otra', 'url' => 'https://inventada.com' }] }
    result = writer({ target: 'email', number: 1 }, answer).call
    expect(result).to include(subject: '{{contacto}}, tu mantenimiento', subject_b: 'Ahorra hoy')
    expect(result[:blocks]).to eq([{ type: 'text', text: 'Hola {{contacto}}', url: '' },
                                   { type: 'button', text: 'Comprar', url: 'https://ejemplo.com/compra' }])
  end

  it 'el toque no repite lo anterior y sin respuesta de la IA avisa' do
    campaign.update!(brief: campaign.brief.merge('opener' => 'Hola {{contacto}}, ¿te cuento de la promo?'))
    w = writer({ target: 'touch', number: 1 }, nil)
    expect(w.call).to eq(error: 'Dali no pudo redactarlo; intenta de nuevo.')
    expect(w).to have_received(:chat) { |user:, **| expect(user).to include('Apertura (fijo): Hola {{contacto}}, ¿te cuento de la promo?') }
  end
end
