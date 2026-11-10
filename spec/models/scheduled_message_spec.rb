# frozen_string_literal: true

require 'rails_helper'

# fix/mensajes_programados — el modelo usa columnas de plantilla que nunca tuvieron migración.
RSpec.describe ScheduledMessage do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:datos) { { account: account, conversation: conversation, user: user, content: 'Hola', scheduled_at: 1.hour.from_now } }

  it 'guarda un mensaje normal: is_template existe y por omisión es falso' do
    programado = described_class.create!(datos)

    expect(programado).to have_attributes(is_template: false, sent: false)
  end

  it 'una plantilla necesita nombre, idioma y categoría' do
    programado = described_class.new(datos.merge(is_template: true))

    expect(programado).not_to be_valid
    expect(programado.errors.attribute_names).to include(:template_name, :template_language, :template_category)
  end

  describe '#deliver!' do
    it 'manda el mensaje normal a la conversación y lo marca enviado' do
      programado = described_class.create!(datos)

      mensaje = programado.deliver!

      expect(mensaje).to have_attributes(content: 'Hola', message_type: 'outgoing', private: false)
      expect(programado.reload).to have_attributes(sent: true, sent_at: be_present)
    end

    it 'el recordatorio al agente es una nota privada' do
      programado = described_class.create!(datos.merge(message_type: 'private'))

      expect(programado.deliver!).to have_attributes(private: true)
    end

    it 'la plantilla sale con template_params como el envío nativo' do
      programado = described_class.create!(datos.merge(is_template: true, template_name: 'pago', template_language: 'es_MX',
                                                       template_category: 'UTILITY', template_params: { '1' => 'Juan' }))

      mensaje = programado.deliver!

      expect(mensaje.additional_attributes['template_params']).to eq('name' => 'pago', 'category' => 'UTILITY', 'language' => 'es_MX',
                                                                     'processed_params' => { '1' => 'Juan' })
    end

    it 'no se entrega dos veces' do
      programado = described_class.create!(datos)
      programado.deliver!

      expect { programado.deliver! }.not_to(change { conversation.messages.count })
    end
  end
end
