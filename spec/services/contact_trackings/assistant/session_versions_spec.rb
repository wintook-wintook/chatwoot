# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase D de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::SessionVersions do
  let(:account) { create(:account) }
  let(:sesion) { TrackingAssistantSession.new(account: account, user: create(:user, account: account)) }
  let(:agente) { "@ruta(soporte #soporte: no puedo entrar): -\n\n[ESTILO]\nBreve." }

  def resultado(draft: nil, reply: 'Listo', changes: nil)
    ContactTrackings::Assistant::InterviewResult.new(draft: draft, reply: reply, changes: changes, validation: {})
  end

  def registrar(on_screen:, delivered:, result:)
    described_class.new(sesion, on_screen: on_screen, delivered: delivered).record(result)
    sesion.version_list.map { |v| v.slice('source', 'summary') }
  end

  it 'marca como cargado el agente que se trajo y nadie tocó' do
    versiones = registrar(on_screen: agente, delivered: agente, result: resultado)

    expect(versiones).to eq([{ 'source' => 'loaded' }])
  end

  it 'marca como a mano lo que cambió, con las piezas que tocó' do
    sesion.add_version(draft: agente, source: 'assistant')

    versiones = registrar(on_screen: agente.sub('Breve.', 'Corto.'), delivered: agente, result: resultado)

    expect(versiones.last).to eq('source' => 'manual', 'summary' => '~ [ESTILO]')
  end

  # Una edición rechazada devuelve el Entrenamiento que había: no suma nada.
  it 'no suma versiones cuando el turno devuelve lo mismo que había' do
    sesion.add_version(draft: agente, source: 'assistant')

    versiones = registrar(on_screen: agente, delivered: agente, result: resultado(draft: agente))

    expect(versiones.size).to eq(1)
  end

  it 'resume la entrega con el primer cambio, o con el mensaje si no hay' do
    versiones = registrar(on_screen: '', delivered: '', result: resultado(draft: agente, reply: 'Armé soporte'))

    expect(versiones).to eq([{ 'source' => 'assistant', 'summary' => 'Armé soporte' }])
  end
end
