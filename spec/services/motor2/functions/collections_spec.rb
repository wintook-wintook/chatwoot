# frozen_string_literal: true

require 'rails_helper'

# Agente listo «Cobranza» sobre el motor 2.0: cobra con la cartera (receivable_*) y atiende lo que contesta el cliente.
# OpenAI no se llama: se simulan las respuestas del modelo (Motor2::Runner#complete).
RSpec.describe Motor2::Functions::Collections do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana Admin') }
  let(:collector) { create(:user, account: account, role: :agent, name: 'Carlos Cobranza') }
  let(:wa) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox }
  let(:contact) { create(:contact, account: account, name: 'Laura Pérez', phone_number: '+528112345678') }
  let(:conversation) { create(:conversation, account: account, inbox: wa, contact: contact) }
  let(:settings) do
    { 'payment_info' => "BBVA · CLABE 012345678901234567\nReferencia: tu clave de cliente", 'user_id' => collector.id,
      'outreach_on' => true, 'every_days' => 7, 'remind_before_days' => 3,
      'templates' => { 'due' => 'sample_shipping_confirmation', 'overdue_30' => 'sample_shipping_confirmation' } }
  end
  let!(:agent) do
    Motor2::Functions::Form.new(account, { kind: 'collections', name: 'Cobranza', enabled: true, settings: settings,
                                           channel: { inbox_id: wa.id } }, user: admin).save
  end
  let!(:customer) do
    account.receivable_customers.create!(external_key: 'clave:C-1', name: 'Grúas del Norte', contact: contact, link_status: 'linked',
                                         phone: '+528112345678')
  end

  def invoice(folio, due_on, balance)
    customer.receivables.create!(account: account, folio: folio, due_on: due_on, balance: balance, total: balance)
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def collections_tracking
    ContactTracking.create!(Motor2::InboxRouter.attributes(agent.reload, conversation)
                              .merge(motor2_state: { 'follow_up' => true, 'collections' => { 'customer_id' => customer.id } }))
  end

  def reply_to(text)
    message = create(:message, account: account, inbox: wa, conversation: conversation, message_type: :incoming, content: text, sender: contact)
    Motor2::ReplyJob.perform_now(message.id)
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({}) # rubocop:disable RSpec/AnyInstance
    invoice('A-1', 20.days.ago.to_date, 15_000)
    invoice('A-2', 10.days.from_now.to_date, 3500)
  end

  it 'está en el catálogo y su prompt trae lo que debe ESE cliente (de la cartera) y los datos para pagar' do
    expect(Motor2::Functions.available?('collections')).to be(true)
    expect(agent).to have_attributes(agent_function: 'collections', attending: false, inbox_id: wa.id)
    prompt = Motor2::Config.new(agent.reload).function.prompt(conversation)
    expect(prompt).to include('Resumen de saldo pendiente — Grúas del Norte', 'Factura A-1', '$15,000.00 MXN', 'Total: $18,500.00 MXN',
                              'CLABE 012345678901234567', 'VENCIDO de 16 a 30 días')
  end

  it 'el resumen de saldo lo arma el código (montos de la cartera); una promesa de pago se registra y frena los toques' do
    collections_tracking
    stub_model(tool_call('registrar_promesa', { fecha: 3.days.from_now.to_date.iso8601, monto: 15_000 }),
               answer('¡Gracias! Quedamos que pagas el viernes.'))
    reply_to('el viernes pago lo vencido')

    promise = customer.payment_promises.last
    expect(promise).to have_attributes(promised_on: 3.days.from_now.to_date, amount: 15_000, status: 'pending')
    expect(conversation.messages.where(private: true).last.content).to include('Promesa de pago')
    expect(Receivables::Promises.active?(customer)).to be(true)

    result = Receivables::Outreach.new(agent.reload).call
    expect(result[:skipped]).to include('promesa vigente' => 1)
  end

  it '«ya pagué» pasa al cobrador para validar y sus facturas dejan de cobrarse' do
    collections_tracking
    stub_model(tool_call('ya_pague', { nota: 'Transferencia del lunes' }), answer('Gracias, cobranza revisa tu comprobante.'))
    reply_to('ya pagué, te mando el comprobante')

    expect(customer.payment_claims.last).to have_attributes(status: 'pending', note: 'Transferencia del lunes')
    expect(customer.receivables.collectable.count).to eq(0)
    expect(conversation.reload.assignee_id).to eq(collector.id)
    expect(conversation.messages.where(private: true).last.content).to include('dice que ya pagó')
  end

  it 'una factura en aclaración no se cobra y se abre un caso' do
    allow_any_instance_of(Cases::OrchestratorService).to receive(:create_for_manual) # rubocop:disable RSpec/AnyInstance
    collections_tracking
    stub_model(tool_call('aclarar_factura', { folio: 'a-1', motivo: 'Ya la devolví' }), answer('El área la revisa.'))
    reply_to('la A-1 no es mía, la devolví')

    expect(customer.receivables.find_by(folio: 'A-1').disputed_at).to be_present
    expect(Receivables::Summary.new(customer).invoices.pluck(:folio)).to eq(['A-2'])
  end

  it 'cobra solo: a quien le toca, con la plantilla de su etapa y el saldo en las variables del contacto; no repite el mismo día' do
    expect { Receivables::Outreach.new(agent.reload).call }.to have_enqueued_job(ContactTrackingJob)
    tracking = ContactTracking.where(tracking_template_id: agent.id).last
    expect(tracking).to have_attributes(contact_id: contact.id, whatsapp_templates: ['sample_shipping_confirmation'], max_attempts: 1)
    expect(tracking.motor2_state.dig('collections', 'stage')).to eq('overdue_30')
    expect(contact.reload.custom_attributes).to include('cobranza_saldo' => '$18,500.00 MXN', 'cobranza_facturas' => '2')

    tracking.update!(status: 'completed')
    expect(Receivables::Outreach.new(agent.reload).call[:skipped]).to include('todavía no le toca' => 1)
  end

  it 'el mensaje del toque (correo o ventana abierta) lleva el resumen exacto y los datos para pagar' do
    tracking = collections_tracking
    text = Motor2::CollectionsTouch.text(tracking)
    expect(text).to start_with('Hola Laura, seguimos pendientes del pago de tu cuenta:')
    expect(text).to include('Factura A-1 · venció el', '$3,500.00 MXN', 'CLABE 012345678901234567', '¿En qué fecha podrías realizar tu pago?')
  end
end
