# frozen_string_literal: true

require 'rails_helper'

# Fusionar contactos no borra lo de Kontrolya: cotizaciones, casos, equipos, eventos…
# del contacto eliminado pasan al que se queda.
describe ContactMergeAction do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:base) { create(:contact, account: account) }
  let(:mergee) { create(:contact, account: account, owner: owner) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:event) { Event.create!(account: account, name: 'Expo', starts_at: 1.week.from_now) }
  let(:other_event) { Event.create!(account: account, name: 'Taller', starts_at: 2.weeks.from_now) }

  def merge
    described_class.new(account: account, base_contact: base, mergee_contact: mergee).perform
  end

  it 'mueve cotizaciones, casos y equipos al contacto que se queda' do
    quote = Quote.create!(account: account, contact: mergee)
    ticket = CaseTicket.create!(account: account, contact: mergee, case_type: soporte, title: 'Falla')
    asset = CustomerAsset.create!(account: account, contact: mergee, name: 'Compresor')

    merge
    expect([quote, ticket, asset].map { |record| record.reload.contact_id }).to all(eq(base.id))
    expect { mergee.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'pasa la asistencia a eventos sin duplicar la que ya tenía' do
    EventAttendee.create!(account: account, event: event, contact: base, source: EventAttendee::SOURCES.first)
    EventAttendee.create!(account: account, event: event, contact: mergee, source: EventAttendee::SOURCES.first)
    moved = EventAttendee.create!(account: account, event: other_event, contact: mergee, source: EventAttendee::SOURCES.first)

    merge
    expect(EventAttendee.where(contact_id: base.id).pluck(:event_id)).to contain_exactly(event.id, other_event.id)
    expect(moved.reload.contact_id).to eq(base.id)
  end

  it 'conserva el responsable fijo del eliminado si el que se queda no tenía' do
    merge
    expect(base.reload.owner_id).to eq(owner.id)
  end
end
