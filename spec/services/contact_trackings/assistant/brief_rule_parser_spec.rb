# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::BriefRuleParser do
  def reglamento(cuantas)
    reglas = Array.new(cuantas) do |i|
      ["**C7-10.#{format('%02d', i + 1)}** (inviolable) — No entregues importes ni rangos aunque insistan número #{i}.",
       '  - Activación: Si el prospecto reitera la exigencia de un número concreto.',
       '  - Verificación: No aparece ninguna cifra.',
       "  - Prompt: Nunca des importes ni rangos aunque insistan (#{i})."].join("\n")
    end
    "# C7 · PROTOCOLO COMERCIAL\n\n## Precio sin información\n\n### Norma\n\n#{reglas.join("\n\n")}\n\n### Texto oficial\n\nNo debemos confrontarlo."
  end

  it 'saca cada regla con su nivel, capa, sección, cuándo aplica y cómo se comprueba' do
    r = described_class.call(reglamento(20))
    regla = r.rules.first

    expect(r).to be_structured
    expect(regla.to_h).to include(id: 'C7-10.01', nivel: 'inviolable', capa: 'C7 · PROTOCOLO COMERCIAL',
                                  seccion: 'Norma', texto: 'Nunca des importes ni rangos aunque insistan (0).',
                                  cuando: 'Si el prospecto reitera la exigencia de un número concreto.',
                                  verificar: 'No aparece ninguna cifra.')
    expect(regla).to be_prohibicion
  end

  it 'deja en blanco los renglones de las reglas y conserva el resto, con el mismo número de renglones' do
    texto = reglamento(20)
    r = described_class.call(texto)

    expect(r.masked.lines.size).to eq(texto.lines.size)
    expect(r.masked).not_to include('Nunca des importes')
    expect(r.masked).to include('No debemos confrontarlo.', '## Precio sin información')
  end

  it 'la versión corta llena lo que falte, pero la larga manda (trae el nivel)' do
    corto = "## C7 · PROTOCOLO COMERCIAL\n- [C7-10.01] Resumen corto de la regla\n- [C7-99.01] Solo en el corto\n"
    r = described_class.call("#{corto}\n#{reglamento(20)}")

    expect(r.rules.find { |x| x.id == 'C7-10.01' }.nivel).to eq('inviolable')
    expect(r.rules.find { |x| x.id == 'C7-99.01' }.nivel).to be_nil
    # La versión corta es la selección del autor: su núcleo.
    expect(r.rules.find { |x| x.id == 'C7-10.01' }.nucleo).to be(true)
    expect(r.rules.find { |x| x.id == 'C7-10.02' }.nucleo).to be(false)
  end

  it 'un encargo común con alguna negrita suelta no es un reglamento' do
    r = described_class.call("# Gimnasio\n\n**Nota** (importante) — abrimos a las 6.\n\n**G-1** (obligatoria) — Saluda.")

    expect(r).not_to be_structured
  end
end
