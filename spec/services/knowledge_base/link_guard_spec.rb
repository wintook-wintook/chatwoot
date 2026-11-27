# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::LinkGuard do
  let(:fuente) { "Liga para inscribirse: https://neoclase.com/cursos/ad101-fundamentos-de-administracion/\nWhatsApp 55 6857 4646" }

  it 'deja las ligas que estaban en lo que vio el modelo' do
    reply = 'Inscríbete aquí: https://neoclase.com/cursos/ad101-fundamentos-de-administracion/ ¿Te inscribes ya?'

    expect(described_class.call(reply, fuente)).to eq([reply, []])
  end

  it 'acepta la misma liga sin la diagonal final ni con punto pegado' do
    reply = 'Liga: https://neoclase.com/cursos/ad101-fundamentos-de-administracion.'

    expect(described_class.call(reply, fuente).last).to eq([])
  end

  it 'quita la liga inventada y el renglón que queda colgando' do
    reply = "La segunda beca es del 52%.\n\nPuedes inscribirte aquí: https://neoclase.com/cursos/lic-administracion/\n\n¿Te gustaría inscribirte ya?"

    texto, quitadas = described_class.call(reply, fuente)
    expect(quitadas).to eq(['https://neoclase.com/cursos/lic-administracion/'])
    expect(texto).to eq("La segunda beca es del 52%.\n\n¿Te gustaría inscribirte ya?")
  end

  it 'deja el texto de un enlace en formato markdown inventado' do
    texto, quitadas = described_class.call('Revisa el [plan de estudios](https://neoclase.com/plan-ri.pdf) de la carrera.', fuente)

    expect(quitadas).to eq(['https://neoclase.com/plan-ri.pdf'])
    expect(texto).to eq('Revisa el plan de estudios de la carrera.')
  end
end
