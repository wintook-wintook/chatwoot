require 'rails_helper'

RSpec.describe ContactTrackings::AttachmentText do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: conversation.inbox, content: 'Cotizar lo adjunto') }

  def adjunto(nombre, tipo)
    ruta = Rails.root.join('spec/fixtures/files/solicitudes', nombre)
    message.attachments.create!(account: account, file_type: :file,
                                file: { io: File.open(ruta), filename: nombre, content_type: tipo })
  end

  before { Rails.cache.clear }

  it 'Excel: las filas de cada hoja, sin IA' do
    texto = described_class.for(adjunto('programa.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'))

    expect(texto).to include('Hoja: Programa')
    expect(texto).to include('Plana 30 t | 1 | Patio Carmen | Dos Bocas | 12 de octubre 2026 | 09:00')
    expect(texto).to include('Low boy 50 t | 1 | Km 14+500 | Blue Giant | 12 de octubre 2026 | 11:00')
  end

  it 'Word: párrafos y tablas, sin IA' do
    texto = described_class.for(adjunto('requisicion.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'))

    expect(texto).to eq("REQUISICION OCI747255\nEquipo | Fecha\nGrua 80 t | 13 de octubre 2026")
  end

  it 'PDF: lo transcribe la IA con el archivo, una sola vez' do
    create(:integrations_hook, :openai, account: account)
    pedido = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .with { |r| JSON.parse(r.body).dig('messages', 0, 'content', 0, 'type') == 'file' }
             .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                        body: { choices: [{ message: { content: 'REQUISICION OCI747255' } }] }.to_json)
    pdf = adjunto('requisicion.pdf', 'application/pdf')
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

    2.times { expect(described_class.for(pdf)).to eq('REQUISICION OCI747255') }
    expect(pedido).to have_been_made.once
  end

  it 'si la IA se niega («Lo siento, no puedo…»), no se toma como el texto ni se guarda' do
    create(:integrations_hook, :openai, account: account)
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                 body: { choices: [{ message: { content: 'Lo siento, pero no puedo transcribir el texto de documentos.' } }] }.to_json)

    expect(described_class.for(adjunto('requisicion.pdf', 'application/pdf'))).to be_nil
  end

  it 'el mensaje con el texto de sus adjuntos' do
    adjunto('requisicion.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')

    expect(described_class.message_text(message.reload))
      .to eq("Cotizar lo adjunto\n\n[archivo adjunto: requisicion.docx]\nREQUISICION OCI747255\nEquipo | Fecha\nGrua 80 t | 13 de octubre 2026")
  end

  it 'una imagen o un formato sin texto: nil' do
    expect(described_class.for(adjunto('requisicion.pdf', 'application/pdf').tap { |a| a.update!(file_type: :image) })).to be_nil
  end
end
