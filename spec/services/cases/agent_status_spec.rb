# frozen_string_literal: true

require 'rails_helper'

# El robot de la lista y el tablero de casos: ¿un agente atiende la conversación del caso?
RSpec.describe Cases::AgentStatus do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  def case_with_conversation(**attrs)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    CaseTicket.create!({ account: account, title: 'Falla', contact: contact, case_type: soporte, conversation: conversation }.merge(attrs))
  end

  def follow_up(ticket, status: 'active')
    AiFollowUp.create!(account: account, conversation: ticket.conversation, case_ticket: ticket, objective: 'Que confirme la cotización',
                       status: status, attempts: 1, max_attempts: 3)
  end

  def tracking(ticket, status: 'active')
    template = create(:tracking_template, account: account, name: 'Cobranza')
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: ticket.conversation,
                              tracking_template: template, status: status)
  end

  it 'el Seguimiento IA activo del caso: robot morado con su detalle' do
    ticket = case_with_conversation
    follow_up(ticket)
    status = described_class.for([ticket])[ticket.id]
    expect(status).to include(state: 'active', kind: 'follow_up', objective: 'Que confirme la cotización', attempts: 1, max_attempts: 3)
  end

  it 'un agente del módulo en pausa: robot ámbar con el nombre del agente' do
    ticket = case_with_conversation
    tracking(ticket, status: 'paused')
    expect(described_class.for([ticket])[ticket.id]).to include(state: 'paused', kind: 'agent', name: 'Cobranza')
  end

  it 'si hay los dos, manda el Seguimiento IA (es el que contesta)' do
    ticket = case_with_conversation
    tracking(ticket)
    follow_up(ticket)
    expect(described_class.for([ticket])[ticket.id][:kind]).to eq('follow_up')
  end

  it 'el agente delegado desde el caso cuenta aunque sea de otra conversación' do
    ticket = case_with_conversation
    other = create(:conversation, account: account, inbox: inbox, contact: contact)
    delegated = create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: other, status: 'scheduled')
    ticket.update_columns(contact_tracking_id: delegated.id) # rubocop:disable Rails/SkipsModelValidations
    expect(described_class.for([ticket.reload])[ticket.id]).to include(state: 'active', kind: 'agent')
  end

  it 'sin agente, sin conversación, y cerrados fuera' do
    alone = case_with_conversation
    no_conv = CaseTicket.create!(account: account, title: 'Sin plática', contact: contact, case_type: soporte)
    finished = case_with_conversation
    follow_up(finished, status: 'done')
    closed = case_with_conversation
    closed.update_columns(status: 'closed') # rubocop:disable Rails/SkipsModelValidations

    result = described_class.for([alone, no_conv, finished, closed.reload])
    expect(result[alone.id]).to eq(state: 'none')
    expect(result[no_conv.id]).to eq(state: 'no_conversation')
    expect(result[finished.id]).to eq(state: 'none')
    expect(result).not_to have_key(closed.id)
  end

  it 'filtra con agente y sin agente' do
    with_fu = case_with_conversation
    follow_up(with_fu)
    with_tr = case_with_conversation
    tracking(with_tr)
    alone = case_with_conversation
    scope = account.case_tickets
    expect(described_class.with_agent(scope).ids).to contain_exactly(with_fu.id, with_tr.id)
    expect(described_class.without_agent(scope).ids).to contain_exactly(alone.id)
  end
end
