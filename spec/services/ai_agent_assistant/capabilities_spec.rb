# frozen_string_literal: true

# proyecto@ai_agent_assistant - F1
require 'rails_helper'

RSpec.describe AiAgentAssistant::Capabilities do
  # ==========================================================================
  # GUARDARRAÍL: el catálogo tiene que reconocer lo mismo que el motor.
  # Si alguien agrega una directiva al motor y no la registra aquí, el chat no
  # sabrá explicarla, el linter no la validará y el probador no la simulará.
  # Estos dos ejemplos son los que deben fallar en CI cuando eso pase.
  # ==========================================================================
  describe 'sincronía con el motor' do
    it 'usa las MISMAS expresiones que los servicios que ya las tenían como constante' do
      expect(described_class.find(:consulta)[:matcher])
        .to eq(ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE)
      expect(described_class.find(:crear_ticket)[:matcher])
        .to eq(Cases::TicketCreatorService::DIRECTIVE_RE)
      expect(described_class.find(:adjunto)[:matcher])
        .to eq(ContactTrackingResponseAnalyzerJob::ATTACHMENT_DIRECTIVE)
    end

    it 'registra todas las directivas que detecta KnowledgeBaseResponseService' do
      source = Rails.root.join('app/services/knowledge_base_response_service.rb').read
      body   = source[/def detect_search_directive.*?\n  end/m].to_s

      detectadas  = body.scan(/@buscar_[a-z_\[\]ií]+|@discourse|\{\{(?:doc|hoja):/i)
                        .map { |d| d.downcase.gsub(/\[ií\]/, 'i').delete('{').chomp(':') }
                        .uniq
      registradas = described_class.all.map { |c| c[:syntax][/@[a-z_]+|\{\{[a-z]+/i].to_s.downcase.delete('{') }

      detectadas.each do |directiva|
        expect(registradas).to include(directiva),
                               "El motor detecta #{directiva} pero no está en Capabilities::ALL"
      end
    end

    # Guardarraíl de la distinción más cara del módulo: qué descarta el prompt y qué
    # no. Se comprueba contra el COMPORTAMIENTO real del motor (PromptBuilder), no
    # leyendo el código fuente: si alguien agrega o quita una directiva de la lista,
    # el ejemplo de esa capacidad deja de coincidir con su bandera y esto falla.
    it 'swallows_prompt coincide con lo que el motor descarta de verdad' do
      described_class.all.each do |capability|
        prompt = "#{capability[:example]}\nTEXTO DISTINTIVO DEL AGENTE"
        limpio = AiAgentAssistant::PromptBuilder.clean_complementary_prompt(prompt)

        expect(limpio.blank?).to eq(capability[:swallows_prompt]),
                                 "#{capability[:key]}: swallows_prompt=#{capability[:swallows_prompt]} " \
                                 "pero el motor #{limpio.blank? ? 'SÍ' : 'NO'} descarta el prompt"
      end
    end
  end

  describe '.detect' do
    it 'reconoce una directiva simple' do
      found = described_class.detect('@buscar_predefinidas')
      expect(found.pluck(:key)).to eq([:buscar_predefinidas])
      expect(found.first[:resolves_turn]).to be(true)
    end

    it 'con dos fuentes, solo la de mayor precedencia resuelve el turno' do
      found = described_class.detect("@discourse\n@buscar_predefinidas")

      ganadora = found.find { |c| c[:resolves_turn] }
      muerta   = found.reject { |c| c[:resolves_turn] }

      expect(ganadora[:key]).to eq(:buscar_predefinidas)
      expect(muerta.pluck(:key)).to eq([:discourse])
    end

    it '{{consulta:}} gana a cualquier búsqueda' do
      found = described_class.detect('{{consulta:contpaq/saldo}} y @buscar_articulo')
      expect(found.find { |c| c[:resolves_turn] }[:key]).to eq(:consulta)
    end

    it 'las banderas conviven con una fuente sin competir' do
      found = described_class.detect('{{hoja:Precios}} @agendar_calendar @estado_ticket')
      expect(found.select { |c| c[:resolves_turn] }.pluck(:key))
        .to contain_exactly(:hoja, :agendar_calendar, :estado_ticket)
    end

    it 'no confunde {{doc:}} con un adjunto (la regex de adjuntos excluye los dos puntos)' do
      expect(described_class.detect('{{doc:Manual}}').pluck(:key)).to eq([:doc])
    end
  end

  describe '.prompt_swallowing' do
    it 'son las cuatro búsquedas, y NO las fuentes Google' do
      expect(described_class.prompt_swallowing.pluck(:key))
        .to contain_exactly(:buscar_predefinidas, :buscar_articulo, :buscar_foro, :discourse)
    end
  end

  describe '.resolve_for' do
    let(:account) { create(:account) }
    let(:inbox)   { create(:inbox, account: account) }

    it 'marca no disponible lo que la cuenta no tiene habilitado' do
      account.disable_features!('erp_connection', 'google_calendar')
      resolved = described_class.resolve_for(account: account, inbox: inbox)

      expect(resolved.find { |c| c[:key] == :consulta }[:available]).to be(false)
      expect(resolved.find { |c| c[:key] == :hoja }[:available]).to be(false)
    end

    it 'marca disponible lo que sí está habilitado' do
      account.enable_features!('google_calendar')
      resolved = described_class.resolve_for(account: account, inbox: inbox)

      expect(resolved.find { |c| c[:key] == :doc }[:available]).to be(true)
    end

    it 'no expone la regex al cliente, pero sí la clave de traducción' do
      resolved = described_class.resolve_for(account: account, inbox: inbox).first

      expect(resolved).not_to have_key(:matcher)
      expect(resolved[:i18n_key]).to eq('capabilities.consulta')
    end

    it 'devuelve una entrada por capacidad registrada' do
      expect(described_class.resolve_for(account: account, inbox: inbox).size)
        .to eq(described_class.all.size)
    end
  end
end
