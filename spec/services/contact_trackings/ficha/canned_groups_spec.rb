# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — la ficha del agente ofrece las categorías fijas.
RSpec.describe ContactTrackings::Ficha::CannedGroups do
  let(:account) { create(:account) }

  it 'con todas en General no ofrece «General» (sería todo): sigue por el principio del nombre' do
    create(:canned_response, account: account, short_code: 'PLAN Empresarial')
    create(:canned_response, account: account, short_code: 'PLAN Básico')
    expect(described_class.new(account).call.pluck(:label)).to eq(['PLAN'])
  end

  it 'en cuanto la cuenta usa las fijas, ofrece General, Ficha y Objeción' do
    create(:canned_response, account: account, short_code: 'Plan Empresarial — Precio', kind: 'ficha')
    create(:canned_response, account: account, short_code: 'Plan Básico — Precio', kind: 'ficha')
    create(:canned_response, account: account, short_code: 'ESTÁ MUY CARO', kind: 'objecion')
    create(:canned_response, account: account, short_code: 'Horario')

    grupos = described_class.new(account).call.select { |g| g[:source] == 'kind' }
    expect(grupos.map { |g| [g[:label], g[:count]] }).to contain_exactly(['Ficha', 2], ['Objeción', 1], ['General', 1])
  end

  it 'un nombre que empieza como una categoría fija no se ofrece como grupo por nombre' do
    create(:canned_response, account: account, short_code: 'Ficha técnica uno', kind: 'ficha')
    create(:canned_response, account: account, short_code: 'Ficha técnica dos')
    expect(described_class.new(account).call.select { |g| g[:source] == 'prefix' }).to eq([])
  end
end
