# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — el intento cuando el cliente no contesta lo escribe el motor 2.0 (Motor2::AttemptHook); los tiempos y
# las plantillas siguen siendo los de ContactTrackingJob.
RSpec.describe Motor2::Attempt do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:template) { create(:tracking_template, account: account, engine: '2', objective: 'Agendar su visita') }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation,
                              tracking_template: template)
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  it 'ContactTrackingJob usa el motor 2.0 para el texto del intento' do
    allow_any_instance_of(Motor2::Runner).to receive(:complete) # rubocop:disable RSpec/AnyInstance
      .and_return({ 'role' => 'assistant', 'content' => 'Mario, ¿te queda bien agendar tu visita esta semana?' })
    expect(ContactTrackingJob.new.send(:generate_message, tracking)).to eq('Mario, ¿te queda bien agendar tu visita esta semana? #IA')
  end

  it 'también el despachador de campañas (hereda de ContactTrackingJob)' do
    expect(TrackingDispatch::SendJob.ancestors).to include(Motor2::AttemptHook)
  end

  it 'si el modelo falla, el mensaje simple de siempre' do
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(nil) # rubocop:disable RSpec/AnyInstance
    expect(ContactTrackingJob.new.send(:generate_message, tracking)).to be_present
  end
end
