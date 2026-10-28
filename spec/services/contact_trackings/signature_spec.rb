# frozen_string_literal: true

require 'rails_helper'

# prospeccion V1 (docs/prospeccion_estudio.md §9 F2, §10 V1) — firma en correo en lugar de las marcas.
RSpec.describe ContactTrackings::Signature do
  let(:account) { create(:account) }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, email_signature: "Ana López\nVentas · Wintook") }

  def tracking_in(inbox)
    build(:contact_tracking, account: account, inbox: inbox, tracking_template: template)
  end

  it 'fuera de correo deja la marca de siempre' do
    expect(described_class.apply('Hola', tracking_in(other_inbox), ' #IA')).to eq('Hola #IA')
    expect(described_class.apply('Claro', tracking_in(other_inbox), "\n\n-TB")).to eq("Claro\n\n-TB")
  end

  it 'en correo quita la marca y pone la firma del agente y el pie de baja (V4)' do
    text = described_class.apply('Hola', tracking_in(email_inbox), ' #IA')

    expect(text).to start_with("Hola\n\nAna López\nVentas · Wintook\n\n")
    expect(text).not_to include('#IA')
    expect(text).to match(%r{/baja/\S+\z})
  end

  it 'en correo sin firma: el texto y el pie de baja' do
    template.email_signature = '  '
    expect(described_class.apply('Hola', tracking_in(email_inbox), ' #IA')).to match(%r{\AHola\n\n.+/baja/\S+\z})
  end

  it 'texto vacío se queda vacío' do
    expect(described_class.apply('', tracking_in(email_inbox), ' #IA')).to eq('')
  end
end
