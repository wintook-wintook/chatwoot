# frozen_string_literal: true

require 'rails_helper'

# Plan-Contratos R1 — estado calculado, cobro del periodo y renovación.
RSpec.describe Contract do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:monitoreo) { account.contract_types.create!(name: 'Monitoreo', default_term_months: 12) }

  def contract(attrs = {})
    account.contracts.create!({ contact: contact, contract_type: monitoreo, title: 'Monitoreo 24/7', price: 450,
                                starts_on: Date.new(2026, 1, 10), term_months: 12 }.merge(attrs))
  end

  it 'calcula el fin del plazo y el primer cobro desde el inicio' do
    record = contract
    expect(record.ends_on).to eq(Date.new(2027, 1, 10))
    expect(record.next_charge_on).to eq(Date.new(2026, 1, 10))
  end

  it 'registrar el pago avanza un periodo y, al pasar del plazo, renueva si es automático' do
    record = contract(next_charge_on: Date.new(2026, 12, 10))
    record.register_payment!(Date.new(2026, 12, 9))
    expect(record.next_charge_on).to eq(Date.new(2027, 1, 10))
    expect(record.ends_on).to eq(Date.new(2027, 1, 10))

    record.register_payment!
    expect(record.next_charge_on).to eq(Date.new(2027, 2, 10))
    expect(record.ends_on).to eq(Date.new(2028, 1, 10))
  end

  it 'cobra cada N semanas o años según el contrato' do
    expect(contract(every: 2, unit: :week).advance(Date.new(2026, 1, 1))).to eq(Date.new(2026, 1, 15))
    expect(contract(every: 1, unit: :year).advance(Date.new(2026, 1, 1))).to eq(Date.new(2027, 1, 1))
  end

  describe 'estado' do
    let(:today) { Date.new(2026, 6, 1) }

    it 'distingue al corriente, pago vencido, por renovar, terminado, suspendido y cancelado' do
      al_corriente = contract(next_charge_on: Date.new(2026, 6, 10))
      vencido = contract(next_charge_on: Date.new(2026, 5, 10))
      por_renovar = contract(starts_on: Date.new(2025, 6, 20), next_charge_on: Date.new(2026, 6, 20))
      terminado = contract(starts_on: Date.new(2025, 5, 1), next_charge_on: Date.new(2026, 7, 1), auto_renew: false)
      suspendido = contract(status: :suspended)
      cancelado = contract.tap { |c| c.cancel!('Se mudó') }

      expected = { al_corriente => 'active', vencido => 'overdue', por_renovar => 'renewal_due',
                   terminado => 'ended', suspendido => 'suspended', cancelado => 'cancelled' }
      expected.each { |record, state| expect(record.state(today)).to eq(state) }
      Contract::STATES.each do |state|
        ids = account.contracts.in_state(state, today).pluck(:id)
        expect(ids).to eq(expected.select { |_, s| s == state }.keys.map(&:id))
      end
    end

    it 'sin plazo nunca se vuelve «por renovar» ni «terminado»' do
      record = contract(term_months: nil, next_charge_on: Date.new(2026, 6, 10))
      expect(record.ends_on).to be_nil
      expect(record.state(today)).to eq('active')
      expect(account.contracts.in_state('active', today)).to include(record)
    end
  end

  it 'solo guarda los campos propios que define su tipo' do
    monitoreo.update!(custom_fields: [{ label: 'Número de cuenta', type: 'text' }])
    record = contract(custom_attributes: { 'numero_de_cuenta' => 'A-77', 'otro' => 'x' })
    expect(record.custom_attributes).to eq('numero_de_cuenta' => 'A-77')
  end

  describe 'precio del producto' do
    let(:servicio) { account.catalog_items.create!(name: 'Monitoreo', kind: :service, price: 500, currency: 'MXN') }

    it 'con la casilla toma el precio del producto y lo sigue cuando cambia' do
      sigue = contract(catalog_item: servicio, price: 1, price_from_catalog: true)
      especial = contract(catalog_item: servicio, price: 420)
      expect(sigue.price).to eq(500)

      servicio.update!(price: 550, currency: 'USD')
      expect(sigue.reload).to have_attributes(price: 550, currency: 'USD')
      expect(especial.reload).to have_attributes(price: 420, currency: 'MXN')
    end

    it 'sin producto no hay casilla y queda el precio capturado' do
      record = contract(price: 300, price_from_catalog: true)
      expect(record).to have_attributes(price: 300, price_from_catalog: false)
    end
  end

  it 'no acepta un equipo de otro cliente' do
    otro = create(:contact, account: account)
    equipo = account.customer_assets.create!(contact: otro, name: 'Panel')
    expect { contract(customer_asset: equipo) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
