# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — el chat recibe lo que ya marcó el comprobador
RSpec.describe ContactTrackings::Assistant::CheckerSection do
  let(:account) { create(:account) }

  around { |example| I18n.with_locale(:es) { example.run } }

  it 'lista los rojos y ámbar como hechos, con su línea o su ruta' do
    draft = "@ruta(precios #precios: cuánto cuesta): @buscar_predefinidas -> @crear_ticket(tipo=Comercial\n\n[ESTILO\nBreve."

    texto = described_class.call(draft, account: account)

    expect(texto).to include('HECHOS', '- ROJO (ruta precios)', '- ROJO (línea 3)', 'DENTRO de "mensaje"')
  end

  it 'sin hallazgos lo dice; sin Entrenamiento no agrega nada' do
    account.labels.create!(title: 'precios')

    expect(described_class.call('@ruta(precios #precios: cuánto cuesta): @buscar_articulo', account: account))
      .to include('Sin hallazgos')
    expect(described_class.call('  ', account: account)).to be_nil
  end
end
