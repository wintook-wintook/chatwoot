# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Metricas-Comercial: «Comprometida por el cliente» (#committed=,
# validación de la fecha y el historial commitment_changed).
RSpec.describe CaseTicket, '#commitment' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:agent)   { create(:user, account: account) }

  def opportunity(attrs = {})
    described_class.create!({ account: account, title: 'Licencias', contact: contact, case_type: venta }.merge(attrs))
  end

  def save_commercial(ticket, data)
    changes = ticket.assign_commercial_data(data)
    ticket.save!
    ticket.log_commercial_change!(changes, actor: agent)
  end

  def commitment_events(ticket)
    ticket.case_events.where(event_type: :commitment_changed).order(:id).map(&:payload)
  end

  it 'marcarla exige la fecha (la de cierre pasa a ser la prometida)' do
    opp = opportunity
    opp.assign_commercial_data(committed: true)
    expect(opp).not_to be_valid
    expect(opp.errors[:expected_close_at]).to be_present
  end

  it 'se puede marcar desde el alta' do
    opp = opportunity(committed: true, expected_close_at: Date.new(2026, 10, 24), commit_note: 'Deposita el viernes')
    expect(opp).to be_committed
    expect(opp.commit_note).to eq('Deposita el viernes')
  end

  it 'deja en el historial cuándo se comprometió, si movió la fecha y si se quitó' do
    opp = opportunity(amount: 100, expected_close_at: Date.new(2026, 10, 30))

    save_commercial(opp, committed: true, expected_close_at: '2026-10-24', commit_note: ' Deposita el viernes ')
    first_mark = opp.committed_at
    save_commercial(opp, committed: true, expected_close_at: '2026-10-31')
    save_commercial(opp, amount: 200)
    save_commercial(opp, committed: false)

    expect(commitment_events(opp)).to eq([
                                           { 'action' => 'set', 'on' => '2026-10-24', 'note' => 'Deposita el viernes' },
                                           { 'action' => 'moved', 'from' => '2026-10-24', 'to' => '2026-10-31' },
                                           { 'action' => 'removed' }
                                         ])
    expect(first_mark).to be_present
    expect(opp.reload).not_to be_committed
    expect(opp.commit_note).to be_nil
    # Monto y fecha siguen en «Datos comerciales»; el compromiso va aparte.
    expect(opp.case_events.where(event_type: :amount_changed).count).to eq(3)
  end

  it 'volver a marcar una ya comprometida conserva cuándo se marcó' do
    opp = opportunity(committed: true, expected_close_at: Date.new(2026, 10, 24))
    marked = opp.committed_at
    save_commercial(opp, committed: true, commit_note: 'Confirmó por WhatsApp')
    expect(opp.reload.committed_at).to be_within(1.second).of(marked)
    expect(commitment_events(opp)).to eq([{ 'action' => 'note', 'note' => 'Confirmó por WhatsApp' }])
  end
end
