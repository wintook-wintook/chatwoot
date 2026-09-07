# frozen_string_literal: true

require 'rails_helper'

# @kbase_contpaq — la rama de CONTPAQi dentro del motor: entrega la respuesta del
# fabricante tal cual, sin pasarla por OpenAI.
RSpec.describe KnowledgeBaseResponseService do
  let(:account)      { create(:account) }
  let(:inbox)        { create(:inbox, account: account) }
  let(:contact)      { create(:contact, account: account, phone_number: '+523121122345') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message)      { create(:message, account: account, inbox: inbox, conversation: conversation, content: '¿Como timbro una nomina?') }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox,
                              complementary_prompt: '@soporte_contpaq(Agente CONTPAQi)')
  end

  let(:answer_url) { 'https://apim.test/v1/answer' }

  before do
    account.knowledge_sources.create!(
      name: 'Agente CONTPAQi', source_type: 'contpaq_support',
      config: { 'base_url' => 'https://apim.test/v1', 'token_url' => 'https://login.test/token',
                'client_id' => 'cid', 'client_secret' => 's', 'scope' => 'api://x/.default' }
    )
    stub_request(:post, 'https://login.test/token')
      .to_return(status: 200, body: { access_token: 'jwt', expires_in: 3599 }.to_json)
  end

  after { Redis::Alfred.delete(format(Redis::RedisKeys::CONTPAQ_ACCESS_TOKEN, source_id: account.knowledge_sources.first.id)) }

  def stub_answer(body)
    stub_request(:post, answer_url).to_return(status: 200, body: body.to_json)
  end

  def sent_replies
    conversation.messages.where(message_type: :outgoing).pluck(:content)
  end

  it 'entrega la respuesta de CONTPAQi tal cual, con el enlace a su fuente' do
    stub_answer(answer: 'Entra a Procesos > Timbrado.',
                sources: [{ title: 'Timbrado', source_url: 'https://contpaqi.test/t' }], message_id: 'm1')

    expect(described_class.new(message, tracking: tracking).perform).to be(true)
    expect(sent_replies.last).to eq("Entra a Procesos > Timbrado.\n\n📚 Documentación relacionada: https://contpaqi.test/t")
  end

  # Medido contra el servicio real: en un hilo con historial, un "¿de que producto
  # hablas?" llega con las fuentes del turno ANTERIOR. El enlace se entrega igual —no
  # hay forma de saber cuales corresponden a esta respuesta— pero el texto de la firma
  # no puede prometer que ahi esta la respuesta a lo que se acaba de preguntar.
  it 'la firma dice "documentacion relacionada", no "mas informacion"' do
    stub_answer(answer: '¿De que producto de CONTPAQi hablas?',
                sources: [{ title: 'Timbrado', source_url: 'https://contpaqi.test/otro-tema' }], message_id: 'm9')

    described_class.new(message, tracking: tracking).perform

    expect(sent_replies.last).to include('📚 Documentación relacionada: https://contpaqi.test/otro-tema')
    expect(sent_replies.last).not_to include('Más información')
  end

  it 'NO pasa la respuesta por OpenAI: la redaccion es del fabricante' do
    stub_answer(answer: 'Texto del fabricante.', sources: [], message_id: 'm2')
    described_class.new(message, tracking: tracking).perform

    expect(WebMock).not_to have_requested(:post, /openai/)
  end

  it 'manda el identificador del contacto y el de la conversacion' do
    stub_answer(answer: 'ok', sources: [], message_id: 'm3')
    described_class.new(message, tracking: tracking).perform

    expect(WebMock).to(have_requested(:post, answer_url).with do |req|
      body = JSON.parse(req.body)
      body['user_id'] == '3121122345@kontrolya.com' &&
        body['conversation_id'] == "acct-#{account.id}-conv-#{conversation.display_id}"
    end)
  end

  it 'entrega sin enlace los 200 que no son respuesta' do
    # Falta especificar el producto: llega con sources vacio y NO es un error.
    stub_answer(answer: '¿De que producto CONTPAQi hablamos?', sources: [], message_id: 'm4')

    expect(described_class.new(message, tracking: tracking).perform).to be(true)
    expect(sent_replies.last).to eq('¿De que producto CONTPAQi hablamos?')
  end

  it 'no cita una fuente sin URL publica en vez de dar un enlace roto' do
    stub_answer(answer: 'Respuesta.', sources: [{ title: 'Doc interno', source_url: '' }], message_id: 'm5')
    described_class.new(message, tracking: tracking).perform

    expect(sent_replies.last).to eq('Respuesta.')
  end

  it 'no guarda historial propio: la memoria del hilo la lleva CONTPAQi' do
    stub_answer(answer: 'ok', sources: [], message_id: 'm6')
    expect { described_class.new(message, tracking: tracking).perform }
      .not_to(change { Redis::Alfred.get("kb_history:#{conversation.id}") })
  end

  it 'deja el turno al conversacional si el servicio no responde' do
    stub_request(:post, answer_url).to_return(status: 503)
    expect(described_class.new(message, tracking: tracking).perform).to be(false)
    expect(sent_replies).to be_empty
  end

  it 'no consulta si la fuente nombrada no existe' do
    tracking.update!(complementary_prompt: '@soporte_contpaq(Fuente inexistente)')
    expect(described_class.new(message, tracking: tracking).perform).to be(false)
    expect(WebMock).not_to have_requested(:post, answer_url)
  end
end
