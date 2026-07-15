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

  describe '#account_timezone' do
    it 'devuelve el IANA tz de la cuenta de Google' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'value' => 'America/Argentina/Buenos_Aires' })
      allow(HTTParty).to receive(:get).and_return(response)

      expect(service.account_timezone).to eq('America/Argentina/Buenos_Aires')
    end

    it 'devuelve nil cuando la API falla (no rompe el flujo)' do
      response = instance_double(HTTParty::Response, success?: false, code: 500, body: 'boom')
      allow(HTTParty).to receive(:get).and_return(response)

      expect(service.account_timezone).to be_nil
    end
  end

  # proyecto@bot_seguimiento_calendar — la invitación debe llegar por correo a invitados
  # de CUALQUIER dominio (no solo gmail): hay que pasar sendUpdates=all.
  describe 'envío de invitaciones por correo (sendUpdates=all)' do
    let(:ok) { instance_double(HTTParty::Response, success?: true, parsed_response: { 'id' => 'evt_1' }) }

    it 'create_event pasa sendUpdates=all e incluye al invitado no-gmail como attendee' do
      allow(HTTParty).to receive(:post).and_return(ok)

      service.create_event(
        summary: 'Cita', start_time: Time.current, end_time: 30.minutes.from_now,
        attendees: ['cliente@hotmail.com']
      )

      expect(HTTParty).to have_received(:post) do |_url, opts|
        expect(opts[:query]).to include(sendUpdates: 'all')
        expect(opts[:body]).to include('cliente@hotmail.com')
      end
    end

    it 'update_event pasa sendUpdates=all al mover la cita' do
      allow(HTTParty).to receive(:patch).and_return(ok)

      service.update_event(
        'evt_1', start_time: Time.current, end_time: 30.minutes.from_now,
                 attendees: ['cliente@outlook.com']
      )

      expect(HTTParty).to have_received(:patch) do |_url, opts|
        expect(opts[:query]).to include(sendUpdates: 'all')
        expect(opts[:body]).to include('cliente@outlook.com')
      end
    end
  end
end
