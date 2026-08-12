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
      resultado = library(prompt: '{{hoja:Precios}}')

      expect(resultado[:prompt_is_discarded]).to be(false)
      expect(block('single_close_node', prompt: '{{hoja:Precios}}')[:status]).to eq('ready')
    end

    it 'con una fuente ya puesta, la segunda fuente se marca como ocupada' do
      account.enable_features!('google_calendar')

      expect(block('doc_source', prompt: '{{hoja:Precios}}')[:status]).to eq('source_taken')
      expect(block('sheet_source', prompt: '{{hoja:Precios}}')[:status]).to eq('ready')
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
