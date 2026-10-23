# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — @crear_ticket: el anti-duplicado (§11.2) respeta la clase del
# caso. Una oportunidad abierta no absorbe una solicitud de soporte. El intake IA
# se simula (`extract`); el mensaje al cliente sale por la conversación.
RSpec.describe Cases::TicketCreatorService do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'No me funciona la impresora')
  end
  let!(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6', position: 0) }
  let!(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial, position: 1) }
  let(:tracking) { create(:contact_tracking, account: account, contact: contact, inbox: inbox, complementary_prompt: directive) }
  let(:directive) { 'Atiende al cliente. @crear_ticket' }
  let(:intake) do
    { 'ticket_worthy' => true, 'title' => 'Impresora sin funcionar', 'description' => 'No imprime.',
      'case_type_id' => soporte.id, 'missing_info' => [] }
  end

  before do
    CaseAiConfig.for_account(account).update!(enabled: true)
    allow_any_instance_of(Cases::Ai::Intake).to receive(:available?).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Cases::Ai::Intake).to receive(:extract) { intake } # rubocop:disable RSpec/AnyInstance
  end

  def run
    service = described_class.new(message, tracking: tracking)
    service.create_if_needed
    service
  end

  def open_opportunity
    CaseTicket.create!(account: account, contact: contact, case_type: venta, title: 'Cotización', status: :in_progress)
  end

  it 'con una oportunidad abierta, una solicitud de soporte abre su propio ticket' do
    opportunity = open_opportunity

    expect(run.outcome).to eq(:created)
    ticket = account.case_tickets.where.not(id: opportunity.id).last
    expect(ticket).to have_attributes(case_type_id: soporte.id, title: 'Impresora sin funcionar')
  end

  it 'reusa el ticket de soporte abierto (misma clase) y no crea otro' do
    existing = CaseTicket.create!(account: account, contact: contact, case_type: soporte, title: 'Falla')

    expect { expect(run.outcome).to eq(:linked_existing) }.not_to change(CaseTicket, :count)
    expect(existing.reload.conversation_id).to eq(conversation.id)
  end

  context 'with @crear_ticket(tipo=Venta)' do
    let(:directive) { 'Rama comercial. @crear_ticket(tipo=Venta)' }

    it 'reusa la oportunidad abierta (la clase de la directiva)' do
      open_opportunity
      expect(run.outcome).to eq(:linked_existing)
    end
  end

  it 'si el intake elige un tipo de otra clase con un caso abierto, lo reusa' do
    open_opportunity
    intake['case_type_id'] = venta.id

    expect { expect(run.outcome).to eq(:linked_existing) }.not_to change(CaseTicket, :count)
  end

  it 'sin IA, el alta básica usa el primer tipo de Soporte aunque otro tipo esté primero' do
    venta.update!(position: 0)
    soporte.update!(position: 5)
    open_opportunity
    allow_any_instance_of(Cases::Ai::Intake).to receive(:available?).and_return(false) # rubocop:disable RSpec/AnyInstance

    run
    expect(account.case_tickets.order(:id).last.case_type_id).to eq(soporte.id)
  end

  it 'una conversación que no amerita ticket no se vincula a nada' do
    open_opportunity
    intake.merge!('ticket_worthy' => false, 'case_type_id' => venta.id)

    expect(run.outcome).to eq(:not_worthy)
  end
end
