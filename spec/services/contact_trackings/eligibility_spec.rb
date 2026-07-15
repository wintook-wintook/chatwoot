# frozen_string_literal: true

require 'rails_helper'

# @campanas_vendedor / proyecto@bulk_tracking_assign
RSpec.describe ContactTrackings::Eligibility do
  # Clase de prueba que incluye el mixin.
  let(:host) { Class.new { include ContactTrackings::Eligibility }.new }

  describe '#channel_contactability' do
    let(:contact_with_phone) { build_stubbed(:contact, phone_number: '+5215512345678', email: nil) }
    let(:contact_with_email) { build_stubbed(:contact, phone_number: nil, email: 'a@b.com') }
    let(:contact_blank) { build_stubbed(:contact, phone_number: nil, email: nil) }

    it 'canal de teléfono: contactable con teléfono' do
      expect(host.channel_contactability(contact_with_phone, 'Channel::Whatsapp')).to eq([true, nil])
    end

    it 'canal de teléfono: NO contactable sin teléfono' do
      expect(host.channel_contactability(contact_blank, 'Channel::Sms')).to eq([false, 'NO_PHONE'])
    end

    it 'canal de email: contactable con correo' do
      expect(host.channel_contactability(contact_with_email, 'Channel::Email')).to eq([true, nil])
    end

    it 'canal de email: NO contactable sin correo' do
      expect(host.channel_contactability(contact_blank, 'Channel::Email')).to eq([false, 'NO_EMAIL'])
    end

    it 'canal con source_id autogenerado: siempre contactable' do
      expect(host.channel_contactability(contact_blank, 'Channel::Api')).to eq([true, nil])
    end

    it 'canal no soportado: no contactable' do
      expect(host.channel_contactability(contact_blank, 'Channel::Telegram')).to eq([false, 'UNSUPPORTED_CHANNEL'])
    end

    it 'reusable=true: contactable aunque falte teléfono (reutiliza conversación)' do
      expect(host.channel_contactability(contact_blank, 'Channel::Whatsapp', reusable: true)).to eq([true, nil])
    end
  end
end
