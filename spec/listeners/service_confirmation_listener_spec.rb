require 'rails_helper'

RSpec.describe ServiceConfirmationListener do
  let!(:conversation) { create(:conversation) }

  def evento(antes, ahora)
    Events::Base.new('conversation.updated', Time.zone.now,
                     conversation: conversation, changed_attributes: { label_list: [antes, ahora] })
  end

  it 'al poner la etiqueta pago_confirmado encola la confirmación' do
    expect { described_class.instance.conversation_updated(evento(['urgente'], %w[urgente pago_confirmado])) }
      .to have_enqueued_job(ContactTrackings::PaymentConfirmedJob).with(conversation.id)
  end

  it 'otras etiquetas, o si ya la tenía, no hace nada' do
    expect { described_class.instance.conversation_updated(evento([], ['urgente'])) }
      .not_to have_enqueued_job(ContactTrackings::PaymentConfirmedJob)
    expect { described_class.instance.conversation_updated(evento(['pago_confirmado'], %w[pago_confirmado x])) }
      .not_to have_enqueued_job(ContactTrackings::PaymentConfirmedJob)
  end
end
