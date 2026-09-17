# frozen_string_literal: true

# proyecto@asistente_agentes_ia — plan: docs/formulario_entrenamiento_plan.md
require 'rails_helper'

RSpec.describe 'Agentes IA — Entrenamiento por secciones' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base) { "/api/v1/accounts/#{account.id}/tracking_templates" }
  let!(:template) do
    account.tracking_templates.create!(name: 'Citas', objective: 'Agendar citas', complementary_prompt: "[ROL]\nSos amable.\n")
  end

  it 'devuelve la estructura por bloques con el agente' do
    get "#{base}/#{template.id}", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['training_structure']['blocks'].first).to include('type' => 'section', 'title' => 'ROL')
  end

  it 'guarda los bloques que manda el formulario y arma el texto' do
    bloques = [{ type: 'section', title: 'ROL', header: '[ROL]', body: 'Sos el asistente del consultorio.', gap: 1 },
               { type: 'section', title: 'NO SIMULAR', body: 'Nunca confirmes sin confirmar.' }]

    patch "#{base}/#{template.id}", params: { tracking_template: { training_structure: { blocks: bloques } } },
                                    headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(template.reload.complementary_prompt)
      .to eq("[ROL]\nSos el asistente del consultorio.\n\n[NO SIMULAR]\nNunca confirmes sin confirmar.")
  end

  # Si llegan los dos, manda lo que editó el formulario.
  it 'con bloques y texto a la vez, usa los bloques' do
    patch "#{base}/#{template.id}",
          params: { tracking_template: { complementary_prompt: 'ignorado',
                                         training_structure: { blocks: [{ type: 'preamble', text: 'Desde bloques' }] } } },
          headers: admin.create_new_auth_token, as: :json

    expect(template.reload.complementary_prompt).to eq('Desde bloques')
  end

  it 'sigue aceptando el texto solo, y separa la estructura' do
    patch "#{base}/#{template.id}", params: { tracking_template: { complementary_prompt: "## ESTILO\nBreve." } },
                                    headers: admin.create_new_auth_token, as: :json

    expect(template.reload.training_structure['blocks'].first).to include('title' => 'ESTILO', 'style' => 'markdown2')
  end

  it 'sugiere las secciones del contrato y las que usa la cuenta' do
    account.tracking_templates.create!(name: 'Otro', objective: 'Otro objetivo', complementary_prompt: "[REGLA DE EVIDENCIA]\nx")

    get "#{base}/section_titles", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['suggested']).to include('ROL', 'ESTILO', 'NO SIMULAR')
    expect(response.parsed_body['from_account']).to include('REGLA DE EVIDENCIA')
    expect(response.parsed_body['from_account']).not_to include('ROL')
  end
end
