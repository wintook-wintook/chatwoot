# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F4) — los números del tablero. La base de pruebas es la de dev y puede traer
# otras licencias: se mide la DIFERENCIA que causan los datos de cada prueba.
RSpec.describe Licenses::Summary do
  def resumen
    described_class.new.call
  end

  it 'cuenta de pago, demo, por vencer, vencidas y sin licencia' do
    antes = resumen[:kpis]
    create(:account_license, license_type: :paid, expires_at: 3.days.from_now)
    create(:account_license, license_type: :demo, expires_at: 20.days.from_now)
    create(:account_license, status: :expired)
    create(:account)

    despues = resumen[:kpis]

    expect(despues[:paid] - antes[:paid]).to eq(1)
    expect(despues[:demo] - antes[:demo]).to eq(1)
    expect(despues[:expiring][7] - antes[:expiring][7]).to eq(1)
    expect(despues[:expiring][30] - antes[:expiring][30]).to eq(2)
    expect(despues[:expired] - antes[:expired]).to eq(1)
    # Tres cuentas nuevas: dos con licencia (la de la expirada ya cuenta como vencida) y una sin.
    expect(despues[:without_license] - antes[:without_license]).to eq(1)
  end

  it 'conversión: de las cuentas con demo, cuántas tuvieron después una de pago' do
    antes = resumen[:kpis][:conversion]
    convertida = create(:account)
    create(:account_license, account: convertida, license_type: :demo, status: :cancelled, created_at: 20.days.ago)
    create(:account_license, account: convertida, license_type: :paid, created_at: 1.day.ago)
    create(:account_license, license_type: :demo)

    despues = resumen[:kpis][:conversion]

    expect(despues[:demo_accounts] - antes[:demo_accounts]).to eq(2)
    expect(despues[:converted] - antes[:converted]).to eq(1)
  end

  it 'vencimientos por semana (9 semanas) y activas por plan' do
    antes = resumen
    create(:account_license, name: 'Plan Resumen X', expires_at: 10.days.from_now)
    create(:account_license, name: 'Plan Resumen X', expires_at: 11.days.from_now)

    despues = resumen

    expect(despues[:expirations].size).to eq(9)
    expect(despues[:expirations].sum { |s| s[:count] } - antes[:expirations].sum { |s| s[:count] }).to eq(2)
    expect(despues[:by_plan]).to include({ name: 'Plan Resumen X', count: 2 })
  end
end
