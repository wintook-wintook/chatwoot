# frozen_string_literal: true

require 'rails_helper'

# fix/mensajes_programados — el job que corre cada minuto.
RSpec.describe ScheduledMessagesDeliveryJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account)) }

  def programado(scheduled_at, extra = {})
    ScheduledMessage.create!({ account: account, conversation: conversation, user: user, content: 'Hola',
                               scheduled_at: scheduled_at }.merge(extra))
  end

  it 'entrega lo que ya venció y deja lo que aún no' do
    vencido = programado(1.minute.ago)
    futuro = programado(1.hour.from_now)

    described_class.perform_now

    expect(vencido.reload.sent).to be(true)
    expect(futuro.reload.sent).to be(false)
  end

  it 'no entrega una plantilla en una bandeja que no las soporta' do
    plantilla = programado(1.minute.ago, is_template: true, template_name: 'pago', template_language: 'es_MX', template_category: 'UTILITY')

    described_class.perform_now

    expect(plantilla.reload.sent).to be(false)
  end
end
