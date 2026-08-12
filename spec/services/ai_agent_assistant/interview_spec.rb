# frozen_string_literal: true

# proyecto@ai_agent_assistant - F5
require 'rails_helper'

RSpec.describe AiAgentAssistant::Interview do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }

  describe 'el guion' do
    it 'abre por el objetivo: es el único campo que siempre llega al modelo' do
      expect(described_class.first_step).to eq('objective')
    end

    it 'avanza en orden y termina' do
      recorrido = []
      paso = described_class.first_step
      while paso
        recorrido << paso
        paso = described_class.next_step(paso)
      end

      expect(recorrido).to eq(%w[objective audience channel knowledge actions limits keywords])
    end

    it 'cada paso explica por qué importa, no solo qué pregunta' do
      expect(described_class.steps).to all(include(:question, :why))
      expect(described_class.steps.pluck(:why)).to all(be_present)
    end
  end

  describe '.knowledge_tree' do
    # Invariante 2 del Anexo A: el asistente no puede nombrar lo que esta cuenta no tiene.
    it 'no ofrece ramas que la cuenta no tiene encendidas' do
      account.disable_features!('erp_connection', 'google_calendar')
      arbol = described_class.knowledge_tree(account: account, inbox: inbox)

      expect(arbol[:options].pluck(:key)).not_to include('exact_data', 'own_voice')
    end

    it 'ofrece {{consulta:}} cuando el ERP está disponible' do
      account.enable_features!('erp_connection')

      arbol = described_class.knowledge_tree(account: account, inbox: inbox)
      rama  = arbol[:options].find { |o| o[:key] == 'exact_data' }

      expect(rama[:capability]).to eq(:consulta)
      expect(rama[:note]).to include('mensaje literal')
    end

    # Si {{doc:}} no está pero {{hoja:}} sí, la rama «voz propia» sigue viva con la que sí está.
    it 'promueve la alternativa cuando la vía principal no está disponible' do
      account.enable_features!('google_calendar')
      arbol = described_class.knowledge_tree(account: account, inbox: inbox)
      rama  = arbol[:options].find { |o| o[:key] == 'own_voice' }

      expect([rama[:capability], *rama[:alternatives]]).to include(:doc, :hoja)
    end

    it 'la rama de búsqueda solo lista los acervos que ya están vectorizados' do
      fuente = account.knowledge_sources.create!(source_type: 'canned_response', name: 'Predefinidas')
      account.knowledge_items.create!(knowledge_source: fuente, source_type: 'canned_response',
                                      source_id: 1, title: 'Horario', content: 'Abrimos de 9 a 6.')

      rama = described_class.knowledge_tree(account: account, inbox: inbox)
                            .fetch(:options).find { |o| o[:key] == 'just_answer' }

      expect(rama[:children][:options].pluck(:capability)).to eq([:buscar_predefinidas])
    end

    # Si la cuenta no tiene ningún acervo, la rama entera desaparece: ofrecer una
    # búsqueda sin nada que buscar es una directiva inerte que además anula el prompt.
    it 'quita la rama de búsqueda entera cuando no hay ningún acervo' do
      rama = described_class.knowledge_tree(account: account, inbox: inbox)
                            .fetch(:options).find { |o| o[:key] == 'just_answer' }

      expect(rama).to be_nil
    end

    it 'siempre deja la rama «no necesita saber nada»: es la familia más sana' do
      arbol = described_class.knowledge_tree(account: account, inbox: inbox)

      rama = arbol[:options].find { |o| o[:key] == 'no_knowledge' }
      expect(rama[:capability]).to be_nil
    end

    it 'las banderas de acción se listan aparte: se suman sin competir' do
      account.enable_features!('google_calendar')
      arbol = described_class.knowledge_tree(account: account, inbox: inbox)

      expect(arbol[:addons]).to be_an(Array)
      expect(arbol[:addons] - described_class::FREE_ADDONS).to be_empty
    end
  end
end
