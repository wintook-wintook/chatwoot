# frozen_string_literal: true

require 'rails_helper'

# Plan-Organizaciones O5 — {{organizacion.nombre}} y compañía en mensajes y plantillas.
describe OrganizationDrop do
  let(:account) { create(:account) }
  let(:organization) { account.organizations.create!(name: 'Acme', tax_id: 'ACM010101AAA', stage: :customer) }

  it 'da nombre, RFC, etapa y tipo en español y con su alias en inglés' do
    drop = described_class.new(organization)
    expect([drop.nombre, drop.name, drop.rfc]).to eq(%w[Acme Acme ACM010101AAA])
    I18n.with_locale(:es) { expect([drop.etapa, drop.tipo]).to eq(%w[Cliente Empresa]) }
  end

  it 'en un mensaje saliente se reemplaza con la organización del contacto' do
    contact = create(:contact, account: account, organization: organization)
    conversation = create(:conversation, account: account, contact: contact)
    message = create(:message, conversation: conversation, account: account, message_type: :outgoing,
                               content: 'Hola, equipo de {{organizacion.nombre}} ({{organization.name}})')
    expect(message.content).to eq('Hola, equipo de Acme (Acme)')
  end

  it 'sin organización queda vacío' do
    expect(described_class.new(nil).nombre).to be_nil
  end
end
