# frozen_string_literal: true

# proyecto@ai_agent_assistant - F0
require 'rails_helper'

RSpec.describe AiAgentAssistant::EngineConfig do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }

  def enable_tracking_bot(target_inbox, model_ia)
    create(:integrations_hook,
           account: account,
           inbox: target_inbox,
           app_id: 'tracking_bot',
           status: 'enabled',
           settings: { 'model_ia' => model_ia }.compact)
  end

  describe '.model_for' do
    it 'usa el modelo configurado en la integración tracking_bot del inbox' do
      enable_tracking_bot(inbox, 'gpt-4o')
      expect(described_class.model_for(inbox)).to eq('gpt-4o')
    end

    it 'cae al modelo por defecto cuando el inbox no tiene la integración' do
      expect(described_class.model_for(inbox)).to eq(described_class::DEFAULT_MODEL)
    end

    it 'cae al modelo por defecto cuando el hook está deshabilitado' do
      hook = enable_tracking_bot(inbox, 'gpt-4o')
      hook.update!(status: 'disabled')
      expect(described_class.model_for(inbox)).to eq(described_class::DEFAULT_MODEL)
    end

    # Defensa en profundidad: el modelo Hook ya valida `settings` contra el schema de
    # apps.yml, así que por la UI no puede entrar un modelo inválido. Esto cubre filas
    # heredadas o editadas a mano en la BD, que sí saltarían esa validación.
    it 'ignora un valor que no esté en la lista permitida' do
      hook = enable_tracking_bot(inbox, 'gpt-4o')
      # Saltarse la validación es EL PUNTO de este test: simula una fila heredada.
      hook.update_column(:settings, { 'model_ia' => 'modelo-inventado' }) # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.model_for(inbox)).to eq(described_class::DEFAULT_MODEL)
    end

    it 'no resuelve el hook de OTRO inbox' do
      otro = create(:inbox, account: account)
      enable_tracking_bot(otro, 'gpt-4o')
      expect(described_class.model_for(inbox)).to eq(described_class::DEFAULT_MODEL)
    end

    it 'tolera un inbox nulo' do
      expect(described_class.model_for(nil)).to eq(described_class::DEFAULT_MODEL)
    end
  end

  describe '.model_for_tracking' do
    it 'resuelve por el inbox del seguimiento' do
      enable_tracking_bot(inbox, 'gpt-4-turbo')
      tracking = instance_double(ContactTracking, inbox: inbox)
      expect(described_class.model_for_tracking(tracking, :scheduled)).to eq('gpt-4-turbo')
    end

    it 'tolera un tracking nulo' do
      expect(described_class.model_for_tracking(nil)).to eq(described_class::DEFAULT_MODEL)
    end
  end

  describe '.max_tokens_for' do
    it 'conserva los topes que tenía cada punto de llamada' do
      expect(described_class.max_tokens_for(:scheduled)).to eq(150)
      expect(described_class.max_tokens_for(:datetime)).to eq(120)
      expect(described_class.max_tokens_for(:conversational)).to eq(250)
      expect(described_class.max_tokens_for(:authoring)).to eq(250)
      expect(described_class.max_tokens_for(:router)).to eq(300)
    end

    it 'usa un tope razonable ante un propósito desconocido' do
      expect(described_class.max_tokens_for(:no_existe)).to eq(250)
    end
  end

  # Guardarraíl: si alguien agrega un modelo al selector de la UI y no aquí, el motor
  # lo descartaría en silencio y el usuario volvería a elegir un modelo que no se aplica
  # — que es exactamente el defecto T8 que F0 arregla.
  describe 'sincronía con config/integration/apps.yml' do
    it 'ALLOWED_MODELS coincide con el enum de model_ia' do
      apps   = YAML.load_file(Rails.root.join('config/integration/apps.yml'))
      schema = apps.dig('tracking_bot', 'settings_json_schema')
      schema = JSON.parse(schema) if schema.is_a?(String)
      enum   = schema.dig('properties', 'model_ia', 'enum')

      expect(enum).to match_array(described_class::ALLOWED_MODELS)
    end
  end
end
