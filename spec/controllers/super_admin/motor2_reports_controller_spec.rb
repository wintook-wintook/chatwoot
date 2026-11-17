# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Super Admin Motor 2.0 Reportes', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, name: 'Escuela Norte') }
  let(:template) { create(:tracking_template, account: account, engine: '2', name: 'Becas') }
  let!(:report) do
    Motor2Report.create!(account: account, tracking_template: template, kind: 'missing_skill',
                         diagnosis: 'Mandar el estado de cuenta en PDF', turns: [{ 'role' => 'user', 'content' => 'Mi estado de cuenta' }])
  end

  it 'lista los nuevos de todas las empresas' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/motor2_reports'
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Mandar el estado de cuenta en PDF', 'Escuela Norte', 'Becas')
  end

  it 'marcarlo corregido vuelve a correr las pruebas del agente' do
    sign_in(super_admin, scope: :super_admin)
    expect { patch "/super_admin/motor2_reports/#{report.id}", params: { status: 'fixed' } }
      .to have_enqueued_job(Motor2::RunTestsJob).with(template.id)
    expect(report.reload.status).to eq('fixed')
  end
end
