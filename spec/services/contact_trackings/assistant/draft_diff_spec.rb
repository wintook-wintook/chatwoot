# frozen_string_literal: true

# proyecto@asistente_agentes_ia — fase A de PROMPT STUDIO
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::DraftDiff do
  let(:actual) do
    <<~T
      @ruta(soporte #soporte1: no puedo entrar): @buscar_articulo
      @ruta(precios #comercial1: cuanto cuesta): @buscar_predefinidas
      @ruta_por_defecto: soporte

      [QUIEN ERES]
      Sos el asistente de Kontrolya.

      [NO SIMULAR]
      Nunca digas que ya quedó agendado.

      [ESTILO]
      Breve y amable.
    T
  end

  def cambios(despues, antes = actual)
    described_class.new(antes, despues).changes.map { |c| [c.kind, c.key] }
  end

  it 'no ve cambios en un texto idéntico' do
    expect(cambios(actual)).to be_empty
  end

  # Reacomodar saltos de línea no es un cambio que valga la pena mostrar.
  it 'no ve cambios cuando solo se movieron espacios o saltos de línea' do
    expect(cambios(actual.gsub("\n\n", "\n\n\n").gsub('Breve y amable.', "Breve   y\namable."))).to be_empty
  end

  # El caso medido sobre el v6.11: agregar una rama sumó también una línea en
  # [ETIQUETAS]. Las dos cosas tienen que verse, aunque el modelo declare una.
  it 've una rama agregada y la sección que cambió con ella' do
    despues = actual.sub('@ruta_por_defecto', "@ruta(factura #factura1: mi CFDI): {{hoja:facturas}}\n@ruta_por_defecto")
                    .sub('Breve y amable.', "Breve y amable.\nSin emojis.")

    expect(cambios(despues)).to contain_exactly([:added, '@ruta(factura)'], [:changed, '[ESTILO]'])
  end

  it 've una rama con otra descripción, fuente o etiqueta' do
    expect(cambios(actual.sub('no puedo entrar', 'se cayo el sistema'))).to eq([[:changed, '@ruta(soporte)']])
    expect(cambios(actual.sub('@buscar_articulo', '@discourse'))).to eq([[:changed, '@ruta(soporte)']])
  end

  # Las secciones se toman por su rótulo, sean cuales sean: [NO SIMULAR] no está en
  # la lista del contrato y vale igual.
  it 've una sección que no está en el contrato cuando se borra' do
    despues = actual.sub("[NO SIMULAR]\nNunca digas que ya quedó agendado.\n", '')

    expect(cambios(despues)).to eq([[:removed, '[NO SIMULAR]']])
  end

  it 've el cambio de la rama por defecto' do
    expect(cambios(actual.sub('@ruta_por_defecto: soporte', '@ruta_por_defecto: precios')))
      .to eq([[:changed, '@ruta_por_defecto']])
  end

  it 've la prosa que va antes del primer rótulo' do
    expect(cambios("Texto suelto nuevo.\n\n#{actual}")).to eq([[:added, described_class::PREAMBLE_KEY]])
  end

  # Borrar el segundo [ESTILO] no puede quedar tapado por el primero.
  it 'distingue dos secciones con el mismo rótulo' do
    doble = "#{actual}\n[ESTILO]\nSin emojis."

    expect(cambios(actual, doble)).to eq([[:removed, '[ESTILO]']])
  end

  describe '#undeclared' do
    let(:despues) do
      actual.sub('no puedo entrar', 'se cayo').sub("[NO SIMULAR]\nNunca digas que ya quedó agendado.\n", '')
    end

    it 'devuelve lo que cambió y no se nombró' do
      diff = described_class.new(actual, despues)

      expect(diff.undeclared(['@ruta(soporte)']).map(&:key)).to eq(['[NO SIMULAR]'])
    end

    # El modelo escribe la clave a su manera: mayúsculas, tildes, espacios.
    it 'reconoce la clave aunque venga con otras mayúsculas, tildes o espacios' do
      diff = described_class.new(actual.sub('Sos el asistente', 'Sos la asistente'), actual)

      expect(diff.undeclared(['[quién  eres]'])).to be_empty
    end
  end

  describe 'qué es destructivo' do
    def destructivos(despues)
      described_class.new(actual, despues).changes.select(&:destructive?).map(&:key)
    end

    it 'borrar una sección o una rama, y cambiar una rama' do
      despues = actual.sub('no puedo entrar', 'se cayo')
                      .sub("@ruta(precios #comercial1: cuanto cuesta): @buscar_predefinidas\n", '')
                      .sub("[ESTILO]\nBreve y amable.\n", '')

      expect(destructivos(despues)).to contain_exactly('@ruta(soporte)', '@ruta(precios)', '[ESTILO]')
    end

    # Agregar o retocar una sección se muestra, pero no justifica otra llamada.
    it 'NO agregar ni retocar el texto de una sección' do
      despues = "#{actual.sub('Breve y amable.', 'Breve.')}\n[HORARIO]\nDe 9 a 18."

      expect(destructivos(despues)).to be_empty
    end
  end
end
