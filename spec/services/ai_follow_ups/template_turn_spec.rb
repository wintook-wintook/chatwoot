# frozen_string_literal: true

require 'rails_helper'

# Seguimiento IA — ventana de WhatsApp cerrada: el agente elige una plantilla aprobada, llena
# sus variables y la manda. OpenAI no se llama (se simula AiFollowUps::Runner#complete).
RSpec.describe AiFollowUps::TemplateTurn do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:templates) do
    [
      { 'name' => 'retomar_cotizacion', 'status' => 'APPROVED', 'category' => 'UTILITY', 'language' => 'es_MX',
        'components' => [{ 'type' => 'BODY', 'text' => 'Hola {{1}}, ¿pudiste revisar la cotización {{2}}?' }] },
      { 'name' => 'saludo_general', 'status' => 'APPROVED', 'category' => 'MARKETING', 'language' => 'es_MX',
        'components' => [{ 'type' => 'BODY', 'text' => 'Hola, ¿seguimos en contacto?' }] },
      { 'name' => 'con_imagen', 'status' => 'APPROVED', 'category' => 'MARKETING', 'language' => 'es_MX',
        'components' => [{ 'type' => 'HEADER', 'format' => 'IMAGE' }, { 'type' => 'BODY', 'text' => 'Mira esto' }] },
      { 'name' => 'codigo', 'status' => 'APPROVED', 'category' => 'AUTHENTICATION', 'language' => 'es_MX',
        'components' => [{ 'type' => 'BODY', 'text' => 'Tu código es {{1}}' }] },
      { 'name' => 'pendiente', 'status' => 'PENDING', 'category' => 'UTILITY', 'language' => 'es_MX',
        'components' => [{ 'type' => 'BODY', 'text' => 'Aún no' }] }
    ]
  end
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', message_templates: templates,
                              sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez', phone_number: '+5215512345678') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:params) { { objective: 'Que confirme la cotización 1520' } }
  let(:follow_up) do
    AiFollowUps::Creator.new(account: account, user: user, conversation: conversation, params: params).call
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function',
                         'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def stub_model(*replies)
    allow_any_instance_of(AiFollowUps::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def run_turn
    AiFollowUps::Runner.new(follow_up, trigger: :scheduled).call
  end

  def sent
    follow_up.messages.where(private: false)
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    # La última vez que escribió el cliente fue hace 2 días: ventana cerrada.
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'Lo reviso', created_at: 2.days.ago)
  end

  it 'solo ofrece las aprobadas y usables (sin archivo en el encabezado ni autenticación)' do
    names = AiFollowUps::Templates.new(conversation).available.pluck(:name)
    expect(names).to contain_exactly('retomar_cotizacion', 'saludo_general')
  end

  it 'elige una plantilla, llena las variables y la manda como intento' do
    stub_model(tool_call('enviar_plantilla', nombre: 'retomar_cotizacion', idioma: 'es_MX',
                                             variables: { '1' => 'Mario', '2' => '1520' }, motivo: 'pide la cotización'),
               { 'role' => 'assistant', 'content' => 'listo' })
    expect(conversation.can_reply?).to be(false)
    run_turn

    message = sent.last
    expect(message.content).to eq('Hola Mario, ¿pudiste revisar la cotización 1520?')
    expect(message.additional_attributes['template_params'])
      .to include('name' => 'retomar_cotizacion', 'language' => 'es_MX', 'processed_params' => { 'body' => { '1' => 'Mario', '2' => '1520' } })
    expect(follow_up.reload.status).to eq('active')
    expect(follow_up.attempts).to eq(1)
    expect(follow_up.log.pluck('kind')).to include('template')
  end

  it 'no manda si faltan variables; si ninguna sirve, se detiene y avisa' do
    stub_model(tool_call('enviar_plantilla', nombre: 'retomar_cotizacion', variables: { '1' => 'Mario' }, motivo: 'x'),
               tool_call('ninguna_plantilla', motivo: 'no sé el folio'), { 'role' => 'assistant', 'content' => '' })
    run_turn

    expect(sent).to be_empty
    expect(follow_up.reload.status).to eq('blocked')
    expect(follow_up.outcome).to include('no sé el folio')
    expect(conversation.messages.where(private: true).last.content).to include('no pudo escribir')
  end

  it 'no repite la última plantilla si hay otras' do
    stub_model(tool_call('enviar_plantilla', nombre: 'saludo_general', motivo: 'retomar'), { 'role' => 'assistant', 'content' => '' })
    run_turn
    follow_up.reload.update!(next_run_at: 1.minute.ago)

    stub_model(tool_call('enviar_plantilla', nombre: 'saludo_general', motivo: 'otra vez'),
               tool_call('enviar_plantilla', nombre: 'retomar_cotizacion', variables: { '1' => 'Mario', '2' => '1520' },
                                             motivo: 'distinta'),
               { 'role' => 'assistant', 'content' => '' })
    run_turn

    expect(sent.reorder(:created_at).map { |m| m.additional_attributes.dig('template_params', 'name') })
      .to eq(%w[saludo_general retomar_cotizacion])
    expect(follow_up.reload.attempts).to eq(2)
  end

  it 'sin plantillas usables se detiene sin llamar al modelo' do
    channel.update_columns(message_templates: templates.last(3)) # rubocop:disable Rails/SkipsModelValidations
    stub_model
    run_turn

    expect(follow_up.reload.status).to eq('blocked')
    expect(follow_up.outcome).to eq(AiFollowUps::Runner::NO_TEMPLATES)
  end

  context 'with a pinned template (plantilla fijada)' do
    let(:params) { { objective: 'Que confirme la cotización 1520', template_name: 'saludo_general' } }

    it 'solo le ofrece esa' do
      expect(follow_up.template_name).to eq('saludo_general')
      turn = described_class.new(follow_up, sender: user)
      expect(turn.candidates.pluck(:name)).to eq(['saludo_general'])
      expect(turn.instructions).not_to include('retomar_cotizacion')
    end

    it 'rechaza una plantilla que no se puede usar' do
      expect do
        AiFollowUps::Creator.new(account: account, user: user, conversation: conversation,
                                 params: { objective: 'x', template_name: 'con_imagen' }).call
      end.to raise_error(ArgumentError, /con_imagen/)
    end
  end
end
