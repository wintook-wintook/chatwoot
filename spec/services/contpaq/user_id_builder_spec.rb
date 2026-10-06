# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contpaq::UserIdBuilder do
  let(:account) { create(:account) }

  def build_for(contact)
    described_class.new(contact, account).build
  end

  it 'usa los ultimos 10 digitos del telefono' do
    contact = create(:contact, account: account, phone_number: '+523121122345')
    expect(build_for(contact)).to eq('3121122345@kontrolya.com')
  end

  it 'prefiere el telefono aunque el contacto tenga correo' do
    contact = create(:contact, account: account, phone_number: '+523121122345', email: 'persona@example.com')
    expect(build_for(contact)).to eq('3121122345@kontrolya.com')
  end

  it 'sin telefono, usa el contacto y su cuenta a cuatro digitos' do
    contact = create(:contact, account: account, phone_number: nil)
    expect(build_for(contact)).to eq("#{contact.id}_#{format('%04d', account.id)}@kontrolya.com")
  end

  it 'toma lo que haya si el telefono tiene menos de 10 digitos' do
    # E.164 admite desde 2 digitos: mejor un identificador corto que descartar el telefono.
    contact = create(:contact, account: account, phone_number: '+52312')
    expect(build_for(contact)).to eq('52312@kontrolya.com')
  end

  it 'es nil sin contacto: sin identificar no se gasta una llamada de la cuota' do
    expect(build_for(nil)).to be_nil
  end
end
