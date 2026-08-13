# frozen_string_literal: true

# proyecto@ai_agent_assistant - F6
require 'rails_helper'

RSpec.describe AiAgentAssistant::PatternLibrary do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }

  def library(prompt: nil, template: nil)
    described_class.for(account: account, inbox: inbox, template: template, prompt: prompt)
  end

  def block(key, **options)
    library(**options)[:blocks].find { |b| b[:key] == key }
  end

  describe 'el catálogo' do
    it 'cada bloque declara de dónde salió: un bloque sin evidencia es una opinión' do
      expect(described_class::BLOCKS.pluck(:source)).to all(be_present)
    end

    it 'cada bloque cae en una sección conocida' do
      expect(described_class::BLOCKS.pluck(:section) - described_class::SECTIONS).to be_empty
    end

    it 'deja huecos para el negocio en vez de texto de relleno' do
      con_huecos = described_class::BLOCKS.select { |b| b[:body].include?('<') }
      expect(con_huecos.size).to be >= (described_class::BLOCKS.size / 2)
    end

    it 'ningún bloque se acerca al techo del prompt por sí solo' do
      expect(described_class::BLOCKS.map { |b| b[:body].length }).to all(be < 300)
    end

    it 'lo determinista se ofrece como configuración, no como texto del prompt' do
      config = described_class::BLOCKS.select { |b| b[:kind] == :config }.pluck(:key)
      expect(config).to include('keyword_actions_pair', 'whatsapp_templates_per_attempt')
    end
  end

  describe 'disponibilidad contra la cuenta' do
    it 'marca no disponible el bloque cuya directiva la cuenta no tiene' do
      account.disable_features!('google_calendar', 'erp_connection')

      expect(block('sheet_source')[:status]).to eq('unavailable')
      expect(block('erp_query')[:status]).to eq('unavailable')
    end

    it 'marca listo el bloque cuya directiva sí está encendida' do
      account.enable_features!('google_calendar')
      account.knowledge_sources.create!(source_type: 'google_doc', name: 'Manual')

      expect(block('doc_source')[:status]).to eq('ready')
    end

    it 'los bloques sin requisito están siempre listos' do
      expect(block('single_close_node')[:status]).to eq('ready')
    end
  end

  # Esta es la razón de ser de la pieza: el bloque está bien escrito y aun así no
  # serviría de nada en ESTE prompt.
  describe 'letra muerta' do
    it 'con una búsqueda activa, todo bloque de prompt es presupuesto tirado' do
      resultado = library(prompt: "@discourse\nAlgo más")

      expect(resultado[:prompt_is_discarded]).to be(true)
      de_prompt = resultado[:blocks].select { |b| b[:kind] == :prompt && b[:available] }

      expect(de_prompt).to be_present
      expect(de_prompt.pluck(:status).uniq).to eq(['dead_letter'])
    end

    it 'los bloques de configuración sobreviven a la búsqueda: no van en el prompt' do
      resultado = library(prompt: '@buscar_articulo')
      config = resultado[:blocks].select { |b| b[:kind] == :config }

      expect(config.pluck(:status).uniq).to eq(['ready'])
    end

    it '{{hoja:}} y {{doc:}} no vuelven letra muerta a nadie: conservan el prompt' do
      account.enable_features!('google_calendar')
      account.knowledge_sources.create!(source_type: 'google_doc', name: 'Manual')
      account.knowledge_sources.create!(source_type: 'google_sheet', name: 'Precios')
      resultado = library(prompt: '{{hoja:Precios}}')

      expect(resultado[:prompt_is_discarded]).to be(false)
      expect(block('single_close_node', prompt: '{{hoja:Precios}}')[:status]).to eq('ready')
    end

    it 'con una fuente ya puesta, la segunda fuente se marca como ocupada' do
      account.enable_features!('google_calendar')
      account.knowledge_sources.create!(source_type: 'google_doc', name: 'Manual')
      account.knowledge_sources.create!(source_type: 'google_sheet', name: 'Precios')

      expect(block('doc_source', prompt: '{{hoja:Precios}}')[:status]).to eq('source_taken')
      expect(block('sheet_source', prompt: '{{hoja:Precios}}')[:status]).to eq('ready')
    end
  end

  describe 'secciones' do
    it 'cada sección declara para qué sirve: es lo que el asistente usa para ofrecerla' do
      expect(described_class::SECTIONS - described_class::SECTION_PURPOSE.keys).to be_empty
      expect(described_class::SECTION_PURPOSE.values).to all(be_present)
    end

    it 'cubre la arquitectura de los prompts de producción, no solo el esqueleto de cinco' do
      expect(described_class::SECTIONS)
        .to include('arquitectura', 'apertura', 'slots', 'interrupciones', 'postcierre', 'nodos')
    end

    it 'hay al menos un bloque por sección que va dentro del prompt' do
      de_prompt = described_class::SECTIONS - ['config']
      cubiertas = described_class::BLOCKS.select { |b| b[:kind] == :prompt }.pluck(:section).uniq

      expect(de_prompt - cubiertas).to be_empty
    end
  end

  describe '.sections_in' do
    it 'reconoce los encabezados que el prompt ya trae' do
      prompt = "[ROL Y LÍMITES]\nEres cobranza.\n\n[8. NODOS LITERALES]\nHola.\n"

      expect(described_class.sections_in(prompt)).to eq(['ROL Y LÍMITES', '8. NODOS LITERALES'])
    end

    it 'no confunde una directiva ni un corchete a media línea con una sección' do
      expect(described_class.sections_in('mira el [manual] antes')).to be_empty
      expect(described_class.sections_in('{{hoja:Precios}}')).to be_empty
    end

    # Falsos positivos reales: el agente 39 escribe «[medida original] = [resultado] m²»
    # y el 42 «[horarios disponibles]». Ocupan su línea, pero son huecos, no secciones.
    it 'un hueco a rellenar no es una sección, aunque esté solo en su línea' do
      expect(described_class.sections_in("[horarios disponibles]\n9:00, 10:00")).to be_empty
      expect(described_class.sections_in('[medida original] = [resultado] m²')).to be_empty
    end

    it 'reconoce los encabezados en mayúsculas de los agentes que sí están seccionados' do
      expect(described_class.sections_in("[NODO: INICIO]\nHola.")).to eq(['NODO: INICIO'])
      expect(described_class.sections_in("[8. NODOS LITERALES]\nx")).to eq(['8. NODOS LITERALES'])
    end

    it 'viaja con la biblioteca para no proponer lo que ya está escrito' do
      resultado = library(prompt: "[CIERRE]\nHasta luego.")

      expect(resultado[:sections_present]).to eq(['CIERRE'])
    end
  end

  describe 'guía de forma y esqueleto' do
    it 'las siete reglas van en orden de impacto y abren por la decisión de familia' do
      expect(described_class::FORM_RULES.size).to eq(7)
      expect(described_class::FORM_RULES.first[:key]).to eq('family_first')
    end

    it 'el esqueleto es estructura, no contenido: no hay nada que clonar' do
      expect(described_class::SKELETON).to include('[ROL Y LÍMITES]', '[CIERRE]')
      expect(described_class::SKELETON).to include('<')
    end

    it 'viajan con la biblioteca para que el chat y el editor citen lo mismo' do
      resultado = library

      expect(resultado[:rules].size).to eq(7)
      expect(resultado[:skeleton]).to be_present
    end
  end
end
