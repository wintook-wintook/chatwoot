# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::Contract do
  let(:contrato) { described_class.call }

  # El guardarraíl que justifica que este archivo viva junto al parser: si alguien
  # cambia LINE_RE y no toca el contrato, el asistente empieza a dictar una gramática
  # muerta y produce Entrenamientos que no ejecutan nada, sin que nadie se entere.
  describe 'sincronía con los patrones reales del motor' do
    it 'el ejemplo de @ruta que dicta lo parsea RouteMap' do
      map = ContactTrackings::RouteMap.parse(described_class::ROUTE_EXAMPLE)

      expect(map.routes.size).to eq(1)
      expect(map.routes.first.name).to eq('soporte')
      expect(map.routes.first.tag).to eq('soporte1')
      expect(map.routes.first.description).to be_present
    end

    it 'la fuente del ejemplo la reconoce Directives' do
      directive = ContactTrackings::RouteMap.parse(described_class::ROUTE_EXAMPLE).routes.first.directive

      expect(KnowledgeBase::Directives.detect(directive)).to include(mode: :article)
    end

    it 'el escalamiento del ejemplo lo reconoce TicketCreator' do
      escalation = ContactTrackings::RouteMap.parse(described_class::ROUTE_EXAMPLE).routes.first.escalation

      expect(escalation).to match(Cases::TicketCreatorService::DIRECTIVE_RE)
    end

    it 'el ejemplo de @ruta_por_defecto lo parsea RouteMap y apunta al ejemplo de rama' do
      texto = "#{described_class::ROUTE_EXAMPLE}\n#{described_class::DEFAULT_EXAMPLE}"

      expect(ContactTrackings::RouteMap.parse(texto).default&.name).to eq('soporte')
    end

    it 'las seis secciones que dicta son las que busca el comprobador' do
      expect(contrato).to include(*ContactTrackings::Assistant::ProseChecks::SECTIONS)
    end
  end

  # Lo que el asistente dicta como ejemplo tiene que pasar su propio comprobador: si
  # no, le está enseñando al modelo a escribir algo que después va a rechazar.
  describe 'el ejemplo que dicta pasa el comprobador' do
    let(:account) { create(:account) }

    it 'no tiene ningún hallazgo bloqueante' do
      KnowledgeSource.create!(account: account, source_type: 'article', name: 'Centro de Ayuda', status: 'active')
      CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
      create(:label, account: account, title: 'soporte1')

      texto = "#{described_class::ROUTE_EXAMPLE}\n#{described_class::DEFAULT_EXAMPLE}"
      resultado = ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call

      expect(resultado[:blocking]).to be_empty
      expect(resultado[:degrading]).to be_empty
    end
  end

  describe 'lo que le advierte al modelo' do
    it 'insiste con los dos puntos, que es el error medido más frecuente' do
      expect(contrato).to include('DOS PUNTOS después del paréntesis de cierre son obligatorios')
    end

    it 'avisa que una directiva suelta blanquea el Entrenamiento entero' do
      expect(contrato).to include('BLANQUEA')
    end

    it 'le prohíbe inventar nombres y le da la salida <PENDIENTE:>' do
      expect(contrato).to include('No inventes nombres', '<PENDIENTE:')
    end

    # El catálogo de fuentes no se dicta acá: lo arma el inventario desde la cuenta.
    # Si estuviera escrito en el contrato, agregar una fuente al motor obligaría a
    # tocar dos archivos y uno se olvidaría.
    it 'no lista fuentes concretas: esas salen del inventario' do
      expect(contrato).not_to include('@buscar_foro(')
    end
  end
end
