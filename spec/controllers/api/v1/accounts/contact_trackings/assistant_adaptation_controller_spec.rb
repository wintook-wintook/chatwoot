# frozen_string_literal: true

require 'rails_helper'

# proyecto@adaptar_prompts_publicados (F1)
RSpec.describe 'Api::V1::Accounts::ContactTrackings::AssistantAdaptationController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/adaptation" }
  let(:texto) { "Eres de <PENDIENTE: Negocio>.\nCierra con #cotizacion." }

  it 'rejects users that are not administrators' do
    post base_url, params: { text: texto }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'POST adaptation' do
    it 'returns what the text needs in this account' do
      post base_url, params: { text: texto }, headers: admin.create_new_auth_token, as: :json

      keys = response.parsed_body['items'].pluck('key')
      expect(keys).to eq(['var:negocio']) # #cotizacion es una marca del mensaje: no se pide
    end

    it 'checks files and inbox against the saved agent, and ignores agents of other accounts' do
      template = create(:tracking_template, account: account, inbox_id: nil)
      ajeno = create(:tracking_template)

      post base_url, params: { text: 'Manda {{catalogo}}', tracking_template_id: template.id },
                     headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['items'].pluck('key')).to eq(%w[attachment:catalogo inbox])

      post base_url, params: { text: 'Manda {{catalogo}}', tracking_template_id: ajeno.id },
                     headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['items'].pluck('key')).to eq(%w[attachment:catalogo])
    end
  end

  describe 'POST adaptation/apply' do
    it 'rewrites the text and returns what is left, plus the validator' do
      post "#{base_url}/apply", params: { text: texto, answers: { 'var:negocio' => 'Grúas del Norte' } },
                                headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['text']).to eq("Eres de Grúas del Norte.\nCierra con #cotizacion.")
      expect(body['applied']).to eq(['var:negocio'])
      expect(body['items']).to eq([])
      expect(body['validation']).to include('valid', 'blocking', 'degrading')
    end

    it 'does not save anything' do
      template = create(:tracking_template, account: account, complementary_prompt: texto)

      post "#{base_url}/apply", params: { text: texto, answers: { 'var:negocio' => 'X' }, tracking_template_id: template.id },
                                headers: admin.create_new_auth_token, as: :json

      expect(template.reload.complementary_prompt).to eq(texto)
    end

    # F6
    it 'remembers what was applied in the saved agent, and the inventory offers it again' do
      template = create(:tracking_template, account: account, complementary_prompt: texto)

      post "#{base_url}/apply", params: { text: texto, answers: { 'var:negocio' => 'Grúas del Norte', 'label:cotizacion' => 'no válida' },
                                          tracking_template_id: template.id },
                                headers: admin.create_new_auth_token, as: :json
      expect(template.reload.adaptation_answers).to eq('var:negocio' => 'Grúas del Norte')

      # El autor publica otra versión: vuelve la marca, y sale prellenada.
      post base_url, params: { text: "Eres de <PENDIENTE: Negocio>.\nNuevo: <PENDIENTE: Horario>", tracking_template_id: template.id },
                     headers: admin.create_new_auth_token, as: :json
      items = response.parsed_body['items'].index_by { |i| i['key'] }
      expect(items['var:negocio']).to include('remembered' => 'Grúas del Norte')
      expect(items['var:horario']).not_to have_key('remembered')
    end

    it 'without a saved agent remembers nothing' do
      expect do
        post "#{base_url}/apply", params: { text: texto, answers: { 'var:negocio' => 'X' } },
                                  headers: admin.create_new_auth_token, as: :json
      end.not_to(change { TrackingTemplate.where.not(adaptation_answers: {}).count })
    end

    it 'ignores answers that are not plain text' do
      post "#{base_url}/apply", params: { text: texto, answers: { 'var:negocio' => %w[a b] } },
                                headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('text' => texto, 'applied' => [])
    end
  end

  # F7
  describe 'POST adaptation/mark_variables' do
    let(:pegado) { "@ruta(ventas: precios): {{doc:Grúas del Norte}}\nSomos Grúas del Norte." }

    it 'turns the chosen texts into placeholders outside directives, and they show up to fill in' do
      post "#{base_url}/mark_variables", params: { text: pegado, variables: [{ text: 'Grúas del Norte', label: 'Nombre del negocio' }] },
                                         headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['text']).to eq("@ruta(ventas: precios): {{doc:Grúas del Norte}}\nSomos <PENDIENTE: Nombre del negocio>.")
      expect(body['items'].pluck('key')).to include('var:nombre del negocio')
    end

    it 'refuses a text that is not in the prose' do
      post "#{base_url}/mark_variables", params: { text: pegado, variables: [{ text: 'Monterrey', label: 'Ciudad' }] },
                                         headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to include('Monterrey')
    end
  end

  describe 'POST adaptation/suggest_variables' do
    it 'returns what the model proposes, filtered' do
      sugerencias = ContactTrackings::Assistant::VariableSuggestions::Result.new(
        variables: [{ 'text' => 'Grúas', 'label' => 'Nombre', 'count' => 1 }]
      )
      servicio = instance_double(ContactTrackings::Assistant::VariableSuggestions, call: sugerencias)
      allow(ContactTrackings::Assistant::VariableSuggestions).to receive(:new).and_return(servicio)

      post "#{base_url}/suggest_variables", params: { text: 'Somos Grúas' }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('variables' => [{ 'text' => 'Grúas', 'label' => 'Nombre', 'count' => 1 }])
    end
  end
end
