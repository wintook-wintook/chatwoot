# frozen_string_literal: true

# proyecto@ai_agent_assistant - F4
require 'rails_helper'

RSpec.describe 'Tracking Template Versions API', type: :request do
  let!(:account)  { create(:account) }
  let(:agent)     { create(:user, account: account, role: :agent) }
  let(:inbox)     { create(:inbox, account: account) }
  let!(:template) do
    create(:tracking_template, account: account, inbox: inbox, name: 'Cobranza',
                               objective: 'Confirmar el pago de la factura vencida.',
                               complementary_prompt: "Eres cobranza.\nNo prometas descuentos.")
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/tracking_templates/#{template.id}/versions" }

  describe 'GET index' do
    it 'returns unauthorized for an unauthenticated user' do
      get base_url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lista el historial de la más nueva a la más vieja, con qué cambió cada una' do
      template.update!(complementary_prompt: "Eres cobranza.\nOfrece plan de pagos.")

      get base_url, headers: agent.create_new_auth_token, as: :json

      versions = response.parsed_body['versions']
      expect(versions.pluck('version')).to eq([2, 1])
      expect(versions.first['changed_fields']).to eq(['complementary_prompt'])
      # La versión de origen no «cambió» nada: es el punto de partida.
      expect(versions.last['changed_fields']).to be_empty
    end

    it 'no deja ver el historial de un agente de otra cuenta' do
      ajeno = create(:tracking_template, account: create(:account), name: 'Ajeno')

      get "/api/v1/accounts/#{account.id}/tracking_templates/#{ajeno.id}/versions",
          headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET show' do
    it 'devuelve el snapshot y el diff línea por línea contra la anterior' do
      template.update!(complementary_prompt: "Eres cobranza.\nOfrece plan de pagos.")
      version = template.versions.ordered.first

      get "#{base_url}/#{version.id}", headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['snapshot']['complementary_prompt']).to include('Ofrece plan de pagos')
      diff = body['diff'].find { |d| d['field'] == 'complementary_prompt' }
      expect(diff['lines']).to include(['del', 'No prometas descuentos.'], ['add', 'Ofrece plan de pagos.'])
    end

    it 'compara contra la versión pedida en compare_with' do
      template.update!(objective: 'Segundo objetivo del agente.')
      template.update!(objective: 'Tercer objetivo del agente.')
      primera = template.versions.find_by(version: 1)
      tercera = template.versions.find_by(version: 3)

      get "#{base_url}/#{tercera.id}", params: { compare_with: primera.id },
                                       headers: agent.create_new_auth_token, as: :json

      diff = response.parsed_body['diff'].find { |d| d['field'] == 'objective' }
      expect(diff['from']).to eq('Confirmar el pago de la factura vencida.')
      expect(diff['to']).to eq('Tercer objetivo del agente.')
    end
  end

  describe 'POST restore' do
    it 'devuelve el agente al contenido de esa versión y deja constancia' do
      original = template.complementary_prompt
      template.update!(complementary_prompt: 'Algo que no funcionó.')
      primera = template.versions.find_by(version: 1)

      post "#{base_url}/#{primera.id}/restore", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(template.reload.complementary_prompt).to eq(original)

      nueva = template.versions.ordered.first
      expect(nueva.version).to eq(3)
      expect(nueva.source).to eq('restore')
      expect(nueva.note).to eq('Restaurado desde la versión 1')
    end

    it 'no borra el historial: restaurar avanza, no retrocede' do
      template.update!(complementary_prompt: 'Algo que no funcionó.')
      primera = template.versions.find_by(version: 1)

      expect do
        post "#{base_url}/#{primera.id}/restore", headers: agent.create_new_auth_token, as: :json
      end.to change { template.versions.count }.from(2).to(3)
    end

    # El agente se movió de inbox y el viejo se borró después. Restaurar la versión
    # anterior no debe dejarlo apuntando a un inbox muerto.
    it 'restaura sin inbox si el que tenía en esa versión ya no existe' do
      otro = create(:inbox, account: account)
      template.update!(inbox: otro)
      primera = template.versions.find_by(version: 1)
      inbox.destroy!

      post "#{base_url}/#{primera.id}/restore", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(template.reload.inbox_id).to be_nil
    end
  end

  describe 'nota de guardado' do
    it 'la nota del formulario viaja al snapshot' do
      patch "/api/v1/accounts/#{account.id}/tracking_templates/#{template.id}",
            params: { tracking_template: { complementary_prompt: 'nuevo prompt',
                                           version_note: 'Se agregó el plan de pagos' } },
            headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(template.versions.ordered.first.note).to eq('Se agregó el plan de pagos')
    end

    it 'registra al autor del guardado' do
      patch "/api/v1/accounts/#{account.id}/tracking_templates/#{template.id}",
            params: { tracking_template: { objective: 'Un objetivo distinto del anterior.' } },
            headers: agent.create_new_auth_token, as: :json

      expect(template.versions.ordered.first.user).to eq(agent)
    end
  end
end
