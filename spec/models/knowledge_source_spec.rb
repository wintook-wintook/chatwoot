# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeSource do
  let(:account) { create(:account) }

  describe 'contpaq_support' do
    it 'es un source_type valido' do
      source = account.knowledge_sources.new(name: 'Agente CONTPAQi', source_type: 'contpaq_support')
      expect(source).to be_valid
    end

    it 'se direcciona por nombre, asi que este es unico en la cuenta' do
      account.knowledge_sources.create!(name: 'Agente CONTPAQi', source_type: 'contpaq_support')
      duplicada = account.knowledge_sources.new(name: 'agente contpaqi', source_type: 'contpaq_support')

      expect(duplicada).not_to be_valid
      expect(duplicada.errors[:name]).to be_present
    end

    it 'guarda las credenciales en config sin exigirlas' do
      # Fail-soft a proposito: una fuente a medio configurar debe poder guardarse; el
      # motor deja el turno al conversacional en vez de impedir el alta.
      source = account.knowledge_sources.create!(name: 'Agente CONTPAQi', source_type: 'contpaq_support',
                                                 config: { 'base_url' => 'https://example.test/v1',
                                                           'client_id' => 'abc' })

      expect(source.config['base_url']).to eq('https://example.test/v1')
      expect(account.knowledge_sources.new(name: 'Otra', source_type: 'contpaq_support')).to be_valid
    end
  end

  it 'rechaza un source_type que no esta en el catalogo' do
    source = account.knowledge_sources.new(name: 'X', source_type: 'inventado')
    expect(source).not_to be_valid
  end
end
