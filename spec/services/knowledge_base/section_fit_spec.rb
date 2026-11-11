# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::SectionFit do
  # Ficha como la de la cuenta 1128 (conv 168): el costo de titulación queda al final.
  let(:title) { 'Licenciatura en Relaciones Internacionales' }
  let(:ficha) do
    <<~TXT
      LICENCIATURA EN RELACIONES INTERNACIONALES (clave LIC-RI)

      DATOS GENERALES
      - Modalidad: 100% en línea
      - Duración: 3 años (9 cuatrimestres)

      COSTOS Y BECAS
      - Precio normal por materia: $3,221.00
      - Primera beca: 38% toda la Licenciatura

      PERFIL DE EGRESO
      #{'Formación integral en relaciones internacionales. ' * 12}

      TITULACIÓN

      Costo de titulación:
      El precio de lista es $30,272, con descuento de hasta el 40% ($18,163).
    TXT
  end
  let(:max) { 600 }

  it 'devuelve el texto tal cual si cabe' do
    expect(described_class.call('corto', 'lo que sea', 2000)).to eq('corto')
  end

  it 'conserva la sección que se pregunta aunque esté al final' do
    out = described_class.call(ficha, 'en que precio esta la titulacio0n de relaciones internacionales', max, title: title)

    expect(out.size).to be <= max
    expect(out).to start_with('LICENCIATURA EN RELACIONES INTERNACIONALES')
    expect(out).to include('TITULACIÓN', '$30,272')
    expect(out).to include('[…]')
    expect(out).not_to include('PERFIL DE EGRESO')
  end

  it 'deja el orden original de las secciones' do
    out = described_class.call(ficha, 'precio de la titulación', max, title: title)

    expect(out.index('COSTOS Y BECAS')).to be < out.index('TITULACIÓN')
  end

  it 'no cuenta las palabras del título para elegir secciones' do
    out = described_class.call(ficha, 'relaciones internacionales', max, title: title)

    expect(out).to eq(ficha.truncate(max))
  end

  it 'corta al final como antes si ninguna sección coincide' do
    expect(described_class.call(ficha, 'hola', max, title: title)).to eq(ficha.truncate(max))
  end
end
