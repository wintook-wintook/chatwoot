# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O4 — la columna «organizacion» de la importación de contactos.
RSpec.describe DataImport::ContactManager do
  let(:account) { create(:account) }
  let(:manager) { described_class.new(account) }

  it 'liga a la organización por RFC o nombre, o la crea como prospecto, sin guardarla en los atributos' do
    acme = account.organizations.create!(name: 'Acme', tax_id: 'ACM010101AAA')
    por_rfc = manager.build_contact({ name: 'Luis', email: 'luis@acme.mx', organizacion: 'acm010101aaa' }.with_indifferent_access)
    nueva = manager.build_contact({ name: 'Ana', email: 'ana@globex.com', organization: 'Globex' }.with_indifferent_access)
    por_rfc.save!
    nueva.save!

    expect(por_rfc.organization).to eq(acme)
    expect(nueva.organization).to have_attributes(name: 'Globex', stage: 'prospect')
    expect(por_rfc.custom_attributes.keys).not_to include('organizacion')
  end
end
