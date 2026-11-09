# frozen_string_literal: true

require 'rails_helper'

# Si la plataforma vuelve a registrar la suscripción del teléfono (sin la marca de Dali),
# los avisos de ese teléfono deben seguir abriendo Dali.
describe NotificationSubscriptionBuilder do
  let(:user) { create(:user) }
  let(:attrs) { { endpoint: 'https://push.example/1', p256dh: 'x', auth: 'y' } }

  def build(extra = {})
    params = ActionController::Parameters.new(subscription_type: 'browser_push', subscription_attributes: attrs.merge(extra)).permit!
    described_class.new(user: user, params: params).perform
  end

  it 'conserva la marca dali al volver a registrarse sin ella' do
    build(dali: true)
    subscription = build
    expect(subscription.reload.subscription_attributes['dali']).to be(true)
    expect(NotificationSubscription.where(identifier: attrs[:endpoint]).count).to eq(1)
  end
end
