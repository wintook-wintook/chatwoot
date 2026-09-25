# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — «Analiza mi prompt» y el botón de corregir
RSpec.describe ContactTrackings::Assistant::AnalysisTurn do
  let(:account) { create(:account) }
  let(:draft) { "@ruta(info #info: costos): {{hoja:CATALOGO}}\n\n[EVIDENCIA]\nPara esos datos ejecuta {{hoja:CATALOGO}}." }

  around { |example| I18n.with_locale(:es) { example.run } }

  def turno(dicho, draft: self.draft, building: false)
    described_class.new(account, draft: draft, said: dicho, editing: true, building: building)
  end

  # 25/09/2026: con 6 avisos, el modelo contestó pidiendo que le dijeran qué revisar.
  it 'la respuesta a un análisis empieza con lo que marca el comprobador' do
    texto = turno('Analiza mi prompt').reply('¿Qué quieres que revise?')

    expect(texto).to start_with('**Lo que marca el comprobador**')
    expect(texto).to include('🟡', '¿Qué quieres que revise?')
  end

  it 'una pregunta suelta no lleva la lista ni el botón' do
    t = turno('¿qué hace la ruta info?')

    expect(t.reply('Busca precios.')).to eq('Busca precios.')
    expect(t.fix_offer).to be_nil
  end

  it 'ofrece el botón cuando hay avisos que se arreglan escribiendo' do
    expect(turno('Analiza mi prompt').fix_offer.first[:choices]).to eq(['Sí, corrige lo que se puede en el texto'])
  end

  it 'mientras se construye el agente no ofrece corregir' do
    expect(turno('Analiza mi prompt', building: true).fix_offer).to be_nil
  end

  # 24/09/2026: la corrección cambió la fuente de la ruta por el foro de otra empresa.
  it 'tras corregir, una ruta sin aviso corregible vuelve a quedar como estaba' do
    corregido = "@ruta(info #info: costos): @buscar_foro(Foro Kontrolya)\n\n[EVIDENCIA]\nUsa la información consultada."
    t = turno('1) Sí, corrige lo que se puede en el texto')

    expect(t.fix_request?).to be(true)
    expect(t.guard(draft, corregido).lines.first.strip).to eq('@ruta(info #info: costos): {{hoja:CATALOGO}}')
  end

  it 'sí deja la ruta que tenía un aviso corregible (un paréntesis sin cerrar)' do
    roto = '@ruta(info #info: costos): - -> @crear_ticket(tipo=Soporte'
    arreglado = '@ruta(info #info: costos): - -> @crear_ticket(tipo=Soporte)'

    expect(turno('1) Sí, corrige lo que se puede en el texto', draft: roto).guard(roto, arreglado)).to eq(arreglado)
  end
end
