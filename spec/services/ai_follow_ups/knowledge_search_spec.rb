# frozen_string_literal: true

require 'rails_helper'

# Seguimiento IA — lo que consulta: respuestas predefinidas (con o sin instrucciones, por
# palabras cuando no hay nada vectorizado) y la nota IA del contacto. Nada más: ni artículos,
# documentos ni páginas web. OpenAI no se llama.
RSpec.describe AiFollowUps::KnowledgeSearch do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:canned_source) { create(:knowledge_source, account: account, source_type: 'canned_response', name: 'Predefinidas') }

  before do
    canned_source
    doc = create(:knowledge_source, account: account, source_type: 'google_doc', name: 'Manual')
    create(:canned_response, account: account, short_code: 'horario', content: 'Abrimos de lunes a viernes de 9 a 18 h.')
    create(:canned_response, account: account, short_code: 'precio_laptops', content_is_prompt: true,
                             content: 'Cuando el cliente pregunte el precio de laptops, pídele la cantidad y el modelo antes de cotizar.')
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    KnowledgeItem.create!(account: account, knowledge_source: doc, source_type: 'google_doc', source_id: 1,
                          title: 'Garantía', content: 'La garantía de las laptops es de 12 meses.')
  end

  describe 'búsquedas (sin nada vectorizado: por palabras)' do
    subject(:search) { described_class.new(account: account) }

    it 'encuentra una predefinida de información' do
      expect(search.canned('¿Cuál es el horario?')[:results].first).to include(codigo: 'horario', tipo: 'informacion')
    end

    it 'entrega aparte las instrucciones de una predefinida que es prompt' do
      result = search.canned('precio de laptops')[:results].find { |r| r[:codigo] == 'precio_laptops' }
      expect(result).to include(tipo: 'instrucciones')
      expect(result[:instrucciones_internas]).to include('pídele la cantidad')
    end

    it 'no consulta otras fuentes (documentos, páginas web)' do
      expect(search.canned('garantía')[:results]).to eq([])
      expect(AiFollowUps::ToolDefinitions::ALL.map { |t| t.dig(:function, :name) }).not_to include('buscar_conocimiento')
    end

    it 'si la fuente de predefinidas está desactivada no las usa' do
      canned_source.update!(status: 'inactive')
      expect(search.canned_available?).to be(false)
    end
  end

  describe 'en el turno del agente' do
    let(:follow_up) do
      AiFollowUps::Creator.new(account: account, user: user, conversation: conversation,
                               params: { objective: 'Que pida su cotización' }).call
    end

    def tool_call(name, args)
      { 'role' => 'assistant', 'content' => nil,
        'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function',
                           'function' => { 'name' => name, 'arguments' => args.to_json } }] }
    end

    it 'el objetivo y las indicaciones mandan y van al final (quién es la persona)' do
      follow_up.update!(instructions: 'Es nuestra distribuidora; pregúntale por su prospecto.')
      system = AiFollowUps::Prompt.new(follow_up).system
      expect(system).to include('mandan sobre todo lo demás', 'Es nuestra distribuidora')
      expect(system.rindex('INDICACIONES DE QUIEN DELEGÓ')).to be > system.index('CON QUIÉN HABLAS')
    end

    it 'la nota IA del contacto va en lo que sabe el agente' do
      create(:note, account: account, user: user, contact: contact, content: 'Compra cada trimestre; prefiere Lenovo.',
                    is_for_ia: true)
      system = AiFollowUps::Prompt.new(follow_up).system
      expect(system).to include('LO QUE SABEMOS DEL CLIENTE', 'prefiere Lenovo')
    end

    it 'sigue las instrucciones de la predefinida y no se las copia al cliente' do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                       content: '¿Qué precio tienen las laptops?')
      leaked = 'Cuando el cliente pregunte el precio de laptops, pídele la cantidad y el modelo antes de cotizar.'
      allow_any_instance_of(AiFollowUps::Runner).to receive(:complete) # rubocop:disable RSpec/AnyInstance
        .and_return(tool_call('buscar_respuesta_predefinida', pregunta: 'precio laptops'),
                    { 'role' => 'assistant', 'content' => leaked },
                    { 'role' => 'assistant', 'content' => '¡Con gusto! ¿Cuántas laptops necesitas y de qué modelo?' })
      AiFollowUps::Runner.new(follow_up, trigger: :reply).call

      sent = follow_up.messages.where(private: false).last
      expect(sent.content).to eq('¡Con gusto! ¿Cuántas laptops necesitas y de qué modelo?')
      expect(follow_up.reload.log.pluck('kind')).to include('canned', 'leak')
    end
  end
end
