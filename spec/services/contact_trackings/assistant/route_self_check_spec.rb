# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::RouteSelfCheck do
  let(:account) { create(:account) }

  def probar(draft)
    described_class.new(account, draft: draft).call
  end

  # El clasificador real habla con OpenAI. Acá interesa QUÉ SE LE PREGUNTA y qué se
  # hace con lo que contesta, así que se lo reemplaza por una tabla: frase probada →
  # nombre de rama elegida. Lo que no se reemplaza es de dónde sale la frase, que es
  # justamente lo que este servicio decide.
  def clasificador_responde(tabla)
    allow(ContactTrackings::BranchClassifierService).to receive(:new) do |_tracking, message, map|
      elegida = tabla[message.content]
      instance_double(ContactTrackings::BranchClassifierService,
                      classify: elegida && map.routes.find { |r| r.name == elegida })
    end
  end

  describe 'de dónde sale la frase de prueba' do
    # La descripción es una lista de situaciones; el cliente escribe UNA. Probar con
    # la lista entera sería probar contra un mensaje que nadie manda.
    it 'prueba con la primera situación de la descripción, no con la lista entera' do
      draft = <<~T
        @ruta(soporte #soporte: no puedo entrar, me da error, no abre): @buscar_articulo
        @ruta(precios #precios: cuanto cuesta la licencia): @buscar_predefinidas
      T
      probadas = []
      allow(ContactTrackings::BranchClassifierService).to receive(:new) do |_t, message, map|
        probadas << message.content
        instance_double(ContactTrackings::BranchClassifierService, classify: map.routes.first)
      end

      probar(draft)

      expect(probadas).to eq(['no puedo entrar', 'cuanto cuesta la licencia'])
    end

    # "usar" a secas no es un mensaje: sin canal, el clasificador no eligió ninguna
    # rama y la pantalla mostraba un cruce que no existía.
    it 'suma situaciones hasta que la frase tenga al menos tres palabras' do
      draft = <<~T
        @ruta(soporte #soporte: usar, configurar, dar de alta un cliente): @buscar_articulo
        @ruta(precios #precios: cuanto cuesta la licencia): @buscar_predefinidas
      T
      probadas = []
      allow(ContactTrackings::BranchClassifierService).to receive(:new) do |_t, message, map|
        probadas << message.content
        instance_double(ContactTrackings::BranchClassifierService, classify: map.routes.first)
      end

      probar(draft)

      expect(probadas.first).to eq('usar, configurar, dar de alta un cliente')
    end
  end

  describe 'el veredicto' do
    let(:draft) do
      <<~T
        @ruta(soporte #soporte: no puedo entrar): @buscar_articulo
        @ruta(comercial #comercial: cuanto cuesta): @buscar_predefinidas
      T
    end

    it 'no devuelve nada cuando cada rama se elige a sí misma' do
      clasificador_responde('no puedo entrar' => 'soporte', 'cuanto cuesta' => 'comercial')

      expect(probar(draft)).to be_empty
    end

    it 'devuelve el cruce con la rama probada, la frase y la que salió elegida' do
      clasificador_responde('no puedo entrar' => 'comercial', 'cuanto cuesta' => 'comercial')

      cruces = probar(draft)

      expect(cruces.size).to eq(1)
      expect(cruces.first).to have_attributes(route: 'soporte', probe: 'no puedo entrar', chosen: 'comercial')
    end

    # Que el clasificador no elija nada también es un cruce: esa rama no se alcanza.
    it 'cuenta como cruce que no se elija ninguna rama' do
      clasificador_responde({})

      expect(probar(draft).map(&:chosen)).to eq([nil, nil])
    end
  end

  describe 'cuándo no se corre' do
    # Con una sola rama el clasificador la devuelve sin preguntarle al modelo: no hay
    # con qué cruzarse y la llamada sería gasto puro. Si el servicio la hiciera igual,
    # el doble no está puesto y el ejemplo fallaría al intentar salir a la red.
    it 'no prueba un Entrenamiento de una sola rama' do
      expect(probar('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo')).to be_empty
    end

    # Una descripción que todavía no existe no es algo que probar.
    it 'saltea la rama cuya descripción está marcada como pendiente' do
      draft = <<~T
        @ruta(soporte #soporte: <PENDIENTE: frases del cliente>): @buscar_articulo
        @ruta(comercial #comercial: cuanto cuesta): @buscar_predefinidas
      T
      clasificador_responde('cuanto cuesta' => 'comercial')

      expect(probar(draft)).to be_empty
    end

    it 'no prueba un Entrenamiento sin ramas' do
      expect(probar('[ROL] Sos un asesor amable.')).to be_empty
    end

    it 'saltea la rama cuya descripción quedó vacía' do
      draft = <<~T
        @ruta(soporte #soporte: ): @buscar_articulo
        @ruta(comercial #comercial: cuanto cuesta): @buscar_predefinidas
      T
      clasificador_responde('cuanto cuesta' => 'comercial')

      expect(probar(draft)).to be_empty
    end

    # El costo crece lineal con las ramas, así que hay tope. Sin él, un Entrenamiento
    # con veinte ramas dispara veinte llamadas cada vez que el asistente entrega.
    it 'no prueba más ramas que el tope' do
      draft = Array.new(described_class::MAX_PROBES + 3) { |i| "@ruta(r#{i} #r#{i}_x: frase #{i}): -" }.join("\n")
      llamadas = 0
      allow(ContactTrackings::BranchClassifierService).to receive(:new) do |_t, _m, map|
        llamadas += 1
        instance_double(ContactTrackings::BranchClassifierService, classify: map.routes.first)
      end

      probar(draft)

      expect(llamadas).to eq(described_class::MAX_PROBES)
    end
  end
end
