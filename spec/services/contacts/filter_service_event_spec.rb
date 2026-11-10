# frozen_string_literal: true

require 'rails_helper'

# Plan-Eventos E2 — condición «Evento» en el filtro de contactos (y en los segmentos).
RSpec.describe Contacts::FilterService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:feria) { account.events.create!(name: 'Feria', starts_at: 1.day.ago) }
  let(:curso) { account.events.create!(name: 'Curso', starts_at: 2.days.ago) }
  let!(:ana) { create(:contact, account: account, name: 'Ana') }
  let!(:luis) { create(:contact, account: account, name: 'Luis') }

  before do
    create(:contact, account: account, name: 'Pepe') # no está en ningún evento
    feria.attendees.create!(account: account, contact: ana, status: :attended)
    feria.attendees.create!(account: account, contact: luis, status: :no_show)
    curso.attendees.create!(account: account, contact: luis, status: :attended)
  end

  def filter(values, operator = 'equal_to')
    payload = [{ attribute_key: 'event', filter_operator: operator, values: values, query_operator: nil }
      .with_indifferent_access]
    described_class.new(account, user, { payload: payload }).perform[:contacts].pluck(:name).sort
  end

  it 'por evento y estado, por cualquier evento y en negativo' do
    expect(filter(["#{feria.id}:attended"])).to eq(['Ana'])
    expect(filter(["#{feria.id}:no_show"])).to eq(['Luis'])
    expect(filter(['any:attended'])).to eq(%w[Ana Luis])
    expect(filter(["#{curso.id}:any"])).to eq(['Luis'])
    expect(filter(['any:attended'], 'not_equal_to')).to eq(['Pepe'])
  end

  it 'se combina con otras condiciones (y)' do
    payload = [
      { attribute_key: 'event', filter_operator: 'equal_to', values: ['any:attended'], query_operator: 'and' },
      { attribute_key: 'name', filter_operator: 'equal_to', values: ['luis'], query_operator: nil }
    ].map(&:with_indifferent_access)
    names = described_class.new(account, user, { payload: payload }).perform[:contacts].pluck(:name)
    expect(names).to eq(['Luis'])
  end
end
