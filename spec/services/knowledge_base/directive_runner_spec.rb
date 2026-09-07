# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBase::DirectiveRunner do
  let(:account) { create(:account) }
  let(:knowledge_source) { create(:knowledge_source, account: account, source_type: 'canned_response') }
  let(:item) do
    create(:knowledge_item, account: account, knowledge_source: knowledge_source, source_type: 'canned_response', title: 'GESTION - Datos fiscales')
      .tap { |i| i.define_singleton_method(:neighbor_distance) { 0.35 } }
  end

  let(:context) { KnowledgeBase::Context.new(account: account, query: 'necesito actualizar mis datos fiscales') }

  before do
    create(:integrations_hook, :openai, account: account)
  end

  def stub_embedding(status: 200, body: { data: [{ embedding: [0.1, 0.2] }] })
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_chat(status: 200, body: { choices: [{ message: { content: 'Respuesta redactada.' } }] })
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#call' do
    context 'when the question is blank' do
      let(:context) { KnowledgeBase::Context.new(account: account, query: '   ') }

      it 'devuelve reason: :no_directive sin llamar a OpenAI' do
        result = described_class.new(context).call

        expect(result.resolved?).to be false
        expect(result.reason).to eq(:no_directive)
      end
    end

    context 'when the embedding could not be generated' do
      before { stub_embedding(status: 500, body: {}) }

      it 'devuelve reason: :embedding_failed' do
        result = described_class.new(context).call

        expect(result.resolved?).to be false
        expect(result.reason).to eq(:embedding_failed)
      end
    end

    context 'when nothing beats the threshold' do
      before do
        stub_embedding
        allow(KnowledgeItem).to receive(:search_by_embedding).and_return([])
      end

      it 'devuelve reason: :no_match con items vacío' do
        result = described_class.new(context).call

        expect(result.resolved?).to be false
        expect(result.reason).to eq(:no_match)
        expect(result.items).to eq([])
      end
    end

    context 'when there is a match and compose: true (default)' do
      before do
        stub_embedding
        stub_chat
        allow(KnowledgeItem).to receive(:search_by_embedding).and_return([item])
      end

      it 'devuelve resolved: true con la respuesta redactada' do
        result = described_class.new(context).call

        expect(result.resolved?).to be true
        expect(result.reply).to eq('Respuesta redactada.')
        expect(result.source).to eq('Respuestas predefinidas')
        expect(result.items.first[:id]).to eq(item.id)
        expect(result.reason).to be_nil
      end
    end

    context 'when there is a match but the model writes nothing' do
      before do
        stub_embedding
        stub_chat(body: { choices: [{ message: { content: '' } }] })
        allow(KnowledgeItem).to receive(:search_by_embedding).and_return([item])
      end

      it 'devuelve reason: :llm_empty con los items ya encontrados' do
        result = described_class.new(context).call

        expect(result.resolved?).to be false
        expect(result.reason).to eq(:llm_empty)
        expect(result.items).not_to be_empty
      end
    end

    context 'when compose: false' do
      let(:context) { KnowledgeBase::Context.new(account: account, query: 'necesito actualizar mis datos fiscales', compose: false) }

      before do
        stub_embedding
        allow(KnowledgeItem).to receive(:search_by_embedding).and_return([item])
      end

      it 'devuelve resolved: true sin pedirle redacción al modelo' do
        result = described_class.new(context).call

        expect(result.resolved?).to be true
        expect(result.reply).to be_nil
        expect(a_request(:post, 'https://api.openai.com/v1/chat/completions')).not_to have_been_made
      end
    end
  end
end
