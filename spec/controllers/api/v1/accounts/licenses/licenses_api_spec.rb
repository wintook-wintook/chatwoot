# frozen_string_literal: true

require 'rails_helper'

# feat/licencias (F2) — la gestión de licencias por API
RSpec.describe 'Licenses API', type: :request do
  let(:wintook) { create(:account, custom_attributes: { 'wintook_internal' => true }) }
  let(:gestor) { create(:user, account: wintook, role: :agent, custom_attributes: { 'can_manage_licenses' => true }) }
  let(:lector) { create(:user, account: wintook, role: :agent, custom_attributes: { 'can_view_licenses' => true }) }
  let(:base) { "/api/v1/accounts/#{wintook.id}/licenses" }
  let(:plan) { create(:license_plan, name: 'Básico', duration_days: 30, default_max_agents: 5) }

  describe 'quién entra' do
    it 'sin permiso: 401' do
      sin_permiso = create(:user, account: wintook, role: :administrator)

      get "#{base}/accounts", headers: sin_permiso.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'con permiso pero desde una cuenta de cliente: 401' do
      cliente = create(:account)
      create(:account_user, account: cliente, user: gestor)

      get "/api/v1/accounts/#{cliente.id}/licenses/accounts", headers: gestor.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it '«Ver» lee pero no escribe' do
      get "#{base}/plans", headers: lector.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)

      post "#{base}/plans", params: { plan: { name: 'X', duration_days: 30, default_max_agents: 2 } },
                            headers: lector.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'la cuenta le dice al navegador si es de Wintook (para mostrar el menú)' do
    get "/api/v1/accounts/#{wintook.id}", headers: lector.create_new_auth_token, as: :json

    expect(response.parsed_body['wintook_internal']).to be(true)
  end

  describe 'catálogo' do
    it 'crea y edita planes, con canales y funciones que existen' do
      post "#{base}/plans", params: { plan: { name: 'Pro', duration_days: 180, default_max_agents: 10, features: %w[campaigns] } },
                            headers: gestor.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
      id = response.parsed_body['id']

      patch "#{base}/plans/#{id}", params: { plan: { default_max_agents: 12 } }, headers: gestor.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('default_max_agents' => 12, 'features' => %w[campaigns])

      get "#{base}/plans", headers: gestor.create_new_auth_token, as: :json
      expect(response.parsed_body['available_features']).to include('campaigns', 'channel_whatsapp')
    end

    it 'rechaza una función que no existe' do
      post "#{base}/plans", params: { plan: { name: 'Pro', duration_days: 30, default_max_agents: 2, features: %w[volar] } },
                            headers: gestor.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'cuentas' do
    let!(:sin_licencia) { create(:account, name: 'Sin Licencia SA') }
    let!(:en_demo) { create(:account, name: 'Demo SA').tap { |a| create(:account_license, account: a, license_type: :demo) } }
    let!(:vencida) { create(:account, name: 'Vencida SA').tap { |a| create(:account_license, account: a, status: :expired) } }
    let!(:por_vencer) { create(:account, name: 'Por Vencer SA').tap { |a| create(:account_license, account: a, expires_at: 3.days.from_now) } }

    def ids_con(estado)
      get "#{base}/accounts", params: { estado: estado, per_page: 100, q: 'SA' }, headers: lector.create_new_auth_token
      response.parsed_body['accounts'].pluck('id')
    end

    it 'filtra por estado de licencia' do
      expect(ids_con('sin_licencia')).to include(sin_licencia.id)
      expect(ids_con('sin_licencia')).not_to include(en_demo.id, vencida.id)
      expect(ids_con('demo')).to eq([en_demo.id])
      expect(ids_con('vencida')).to eq([vencida.id])
      expect(ids_con('por_vencer')).to include(por_vencer.id)
      expect(ids_con('por_vencer')).not_to include(en_demo.id)
    end

    it 'cada fila dice su estado; el detalle trae el historial' do
      get "#{base}/accounts", params: { q: 'Vencida SA' }, headers: lector.create_new_auth_token
      expect(response.parsed_body['accounts'].first).to include('license_state' => 'vencida', 'license' => nil)

      get "#{base}/accounts/#{en_demo.id}", headers: lector.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('license_state' => 'demo')
      expect(response.parsed_body['licenses'].size).to eq(1)
    end
  end

  describe 'emitir y cancelar' do
    let(:cliente) { create(:account) }

    it 'emite una licencia a otra cuenta y la registra a nombre de quien la dio' do
      post "#{base}/account_licenses", params: { target_account_id: cliente.id, license_plan_id: plan.id, max_agents: 7 },
                                       headers: gestor.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(cliente.current_license).to have_attributes(max_agents: 7, created_by: gestor)
    end

    it 'cancela solo una programada' do
      vigente = create(:account_license, account: cliente)
      programada = create(:account_license, account: cliente, status: :scheduled)

      post "#{base}/account_licenses/#{vigente.id}/cancel", headers: gestor.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      post "#{base}/account_licenses/#{programada.id}/cancel", headers: gestor.create_new_auth_token, as: :json
      expect(programada.reload).to be_cancelled
    end
  end
end
