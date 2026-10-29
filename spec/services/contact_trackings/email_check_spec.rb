# frozen_string_literal: true

require 'rails_helper'

# prospeccion V7a
RSpec.describe ContactTrackings::EmailCheck do
  before { allow(Rails.cache).to receive_messages(read: nil, write: true) }

  it 'mal escrito: inválido sin consultar DNS' do
    expect(described_class.deliverable?('juan@@gmail')).to be(false)
    expect(described_class.deliverable?('sin-arroba.com')).to be(false)
    expect(described_class).not_to have_received(:lookup)
  end

  it 'el dominio recibe correo: válido' do
    expect(described_class.deliverable?(' Juan@Empresa.MX ')).to be(true)
    expect(described_class).to have_received(:lookup).with('empresa.mx')
  end

  it 'el dominio no recibe correo: inválido' do
    allow(described_class).to receive(:lookup).and_return(false)
    expect(described_class.deliverable?('juan@no-existe.mx')).to be(false)
  end

  it 'el DNS no contestó: válido y no se recuerda' do
    allow(described_class).to receive(:lookup).and_return(nil)
    expect(described_class.deliverable?('juan@lento.mx')).to be(true)
    expect(Rails.cache).not_to have_received(:write)
  end

  it 'recuerda el dominio: 7 días si recibe, 1 día si no' do
    described_class.deliverable?('a@bueno.mx')
    allow(described_class).to receive(:lookup).and_return(false)
    described_class.deliverable?('a@malo.mx')

    expect(Rails.cache).to have_received(:write).with('prospeccion:email_domain:bueno.mx', true, expires_in: 7.days)
    expect(Rails.cache).to have_received(:write).with('prospeccion:email_domain:malo.mx', false, expires_in: 1.day)
  end

  it 'si ya está en caché no vuelve a consultar' do
    allow(Rails.cache).to receive(:read).with('prospeccion:email_domain:visto.mx').and_return(false)
    expect(described_class.deliverable?('a@visto.mx')).to be(false)
    expect(described_class).not_to have_received(:lookup)
  end
end
