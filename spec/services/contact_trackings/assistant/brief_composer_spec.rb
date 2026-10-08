# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::BriefComposer do
  let(:ficha) do
    { 'temas' => [{ 'nombre' => 'desarrollo_web', 'que_hace' => 'Diagnostica', 'junta' => ['sitio web', 'tienda en línea'] },
                  { 'nombre' => 'concluir_intervencion', 'que_hace' => 'Cierra el ciclo' }] }
  end
  let(:brief) { instance_double(TrackingAgentBrief, digest: { 'ficha' => ficha }, filename: 'adam.md') }

  def mensaje(answers = {})
    described_class.new(brief, answers: answers, inventory: {}).call[:message]
  end

  it 'dice qué temas junta cada ruta agrupada' do
    expect(mensaje).to include('- desarrollo_web · qué hace: Diagnostica · junta: sitio web, tienda en línea')
  end

  context 'with a source that covers the brief (M4)' do
    let(:brief) do
      instance_double(TrackingAgentBrief, filename: 'adam.md',
                                          digest: { 'ficha' => ficha.merge('conocimiento' => [{ 'tema' => 'R.A.D.A.R.', 'resumen' => 'x' * 900 }]),
                                                    'fuentes_sugeridas' => [{ 'directiva' => '@buscar_foro(Foro_SC)',
                                                                              'cubiertos' => 57, 'total' => 80 }] })
    end

    it 'la usa en toda ruta de consulta y no copia el conocimiento' do
      texto = mensaje

      expect(texto).to include('antes de la flecha va EXACTAMENTE @buscar_foro(Foro_SC)')
      expect(texto).not_to include('DATOS DEL NEGOCIO Y CONOCIMIENTO')
    end

    it 'si la persona elige «ninguna», no hay decisión de fuente' do
      expect(mensaje('fuente_conocimiento' => 'ninguna')).not_to include('FUENTE DE CONOCIMIENTO')
    end
  end

  it 'deja fuera las rutas que la persona quitó en el modal' do
    texto = mensaje('temas_quitados' => ['concluir_intervencion'])

    expect(texto).to include('desarrollo_web')
    expect(texto).not_to include('concluir_intervencion')
  end
end
