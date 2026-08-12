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

      expect(recorrido)
        .to eq(%w[objective purpose audience channel knowledge actions limits name keywords])
    end

    # El botón de crear exige nombre: si el guion no lo pregunta, el usuario clica y no
    # pasa nada. Pasó de verdad.
    it 'cubre todos los campos obligatorios para poder guardar' do
      campos = described_class.steps.filter_map { |s| s[:field] }

      expect(campos).to include('name', 'objective')
    end

    it 'cada paso explica por qué importa, no solo qué pregunta' do
      expect(described_class.steps).to all(include(:question, :why))
      expect(described_class.steps.pluck(:why)).to all(be_present)
    end
  end

  # La indagación del propósito: antes de escribir nada hay que saber QUÉ FORMA tiene
  # el agente, porque de ahí salen las secciones que necesita — y las que no.
  describe '.architecture_tree' do
    it 'pregunta por la forma justo después del objetivo' do
      expect(described_class.next_step('objective')).to eq('purpose')
    end

    it 'cada forma dice qué secciones trae, y todas existen en la biblioteca' do
      opciones = described_class::ARCHITECTURE_TREE[:options]
      todas = opciones.flat_map { |o| o[:sections] }.uniq

      expect(opciones.pluck(:sections)).to all(be_present)
      expect(todas - AiAgentAssistant::PatternLibrary::SECTIONS).to be_empty
    end

    it 'la forma más simple casi no lleva secciones: es la familia más sana' do
      expect(described_class.sections_for('notify')).to eq(%w[rol cierre])
    end

    # Es la forma del agente vendedor de producción: calificar antes de entregar la liga.
    it 'calificar antes de entregar algo trae datos, cierre y post-cierre' do
      secciones = described_class.sections_for('qualify')

      expect(secciones).to include('slots', 'cierre', 'postcierre', 'nodos')
    end

    it 'una forma que no existe no inventa secciones' do
      expect(described_class.sections_for('telepatía')).to be_empty
    end
  end

  describe '.knowledge_tree' do
    # Invariante 2 del Anexo A: el asistente no puede nombrar lo que esta cuenta no tiene.
    it 'no ofrece ramas que la cuenta no tiene encendidas' do
      account.disable_features!('erp_connection', 'google_calendar')
      arbol = described_class.knowledge_tree(account: account, inbox: inbox)

      expect(arbol[:options].pluck(:key)).not_to include('exact_data', 'own_voice')
    end

    it 'ofrece {{consulta:}} cuando hay consultas ERP dadas de alta' do
      account.enable_features!('erp_connection')
      conexion = account.external_db_connections.create!(
        name: 'Contpaq', engine: 'mssql', host: 'localhost', port: 1433, database: 'erp'
      )
      account.external_db_queries.create!(external_db_connection: conexion, name: 'saldo_cliente',
                                          sql_template: 'SELECT 1', active: true)

      rama = described_class.knowledge_tree(account: account, inbox: inbox)
                            .fetch(:options).find { |o| o[:key] == 'exact_data' }

      expect(rama[:capability]).to eq(:consulta)
      expect(rama[:note]).to include('mensaje literal')
    end

    # La feature encendida no basta: la directiva se escribe {{consulta:conexion/consulta}}
    # y sin consultas reales no hay ninguna que resuelva.
    it 'no ofrece {{consulta:}} con la feature encendida pero sin ninguna consulta' do
      account.enable_features!('erp_connection')

      rama = described_class.knowledge_tree(account: account, inbox: inbox)
                            .fetch(:options).find { |o| o[:key] == 'exact_data' }

      expect(rama).to be_nil
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
