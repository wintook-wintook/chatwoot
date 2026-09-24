# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — el chat recibe lo que ya marcó el comprobador
RSpec.describe ContactTrackings::Assistant::CheckerSection do
  let(:account) { create(:account) }

  around { |example| I18n.with_locale(:es) { example.run } }

  it 'lista los rojos y ámbar como hechos, con su línea o su ruta' do
    draft = "@ruta(precios #precios: cuánto cuesta): @buscar_predefinidas -> @crear_ticket(tipo=Comercial\n\n[ESTILO\nBreve."

    texto = described_class.call(draft, account: account)

    expect(texto).to include('HECHOS', '- ROJO (ruta precios)', '- ROJO: Línea 3:', 'DENTRO de "mensaje"')
  end

  it 'sin hallazgos lo dice; sin Entrenamiento no agrega nada' do
    account.labels.create!(title: 'precios')

    expect(described_class.call('@ruta(precios #precios: cuánto cuesta): @buscar_articulo', account: account))
      .to include('Sin hallazgos')
    expect(described_class.call('  ', account: account)).to be_nil
  end

  describe 'ofrecer corregir' do
    let(:draft) { "@ruta(info #info: costos): {{hoja:CATALOGO}}\n\n[EVIDENCIA]\nPara esos datos ejecuta {{hoja:CATALOGO}}." }
    let(:resultado) { described_class.result(draft, account) }

    it 'ofrece el botón cuando piden un análisis y hay avisos que se arreglan escribiendo' do
      oferta = described_class.fix_offer(resultado, 'Analiza mi prompt')

      expect(oferta.first[:choices]).to eq(['Sí, corrige lo que se puede en el texto'])
    end

    it 'no lo ofrece en una pregunta suelta' do
      expect(described_class.fix_offer(resultado, '¿qué hace la ruta info?')).to be_nil
    end

    # 24/09/2026: con la hoja inexistente en la cuenta de prueba, la corrección cambió
    # la fuente de la ruta por el foro de otra empresa.
    it 'la corrección no cambia una ruta que no tenía un aviso corregible' do
      corregido = "@ruta(info #info: costos): @buscar_foro(Foro Kontrolya)\n\n[EVIDENCIA]\nUsa la información consultada."

      expect(described_class.restore_routes(draft, corregido, resultado).lines.first.strip)
        .to eq('@ruta(info #info: costos): {{hoja:CATALOGO}}')
    end

    it 'sí deja la que tenía un aviso corregible (un paréntesis sin cerrar)' do
      roto = '@ruta(info #info: costos): - -> @crear_ticket(tipo=Soporte'
      arreglado = '@ruta(info #info: costos): - -> @crear_ticket(tipo=Soporte)'

      expect(described_class.restore_routes(roto, arreglado, described_class.result(roto, account))).to eq(arreglado)
    end
  end
end
