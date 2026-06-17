# frozen_string_literal: true

require 'rails_helper'

# proyecto@bot_seguimiento_calendar
RSpec.describe GoogleCalendarService do
  subject(:service) { described_class.new(integration) }

  let(:integration) { instance_double(UserCalendarIntegration, token_expired?: false, access_token: 'tok') }

  describe '#delete_event' do
    it 'borra el evento y devuelve true cuando la API responde ok (204)' do
      response = instance_double(HTTParty::Response, code: 204, success?: true, parsed_response: nil)
      allow(HTTParty).to receive(:delete).and_return(response)

      expect(service.delete_event('evt_1')).to be(true)
    end

    it 'es idempotente: trata 404/410 (evento ya borrado) como éxito' do
      response = instance_double(HTTParty::Response, code: 410)
      allow(HTTParty).to receive(:delete).and_return(response)

      expect(service.delete_event('evt_gone')).to be(true)
    end

    it 'propaga un error real de la API (p. ej. 500)' do
      response = instance_double(HTTParty::Response, code: 500, success?: false, body: 'boom')
      allow(HTTParty).to receive(:delete).and_return(response)

      expect { service.delete_event('evt_x') }.to raise_error(/Google Calendar API error 500/)
    end
  end
end
