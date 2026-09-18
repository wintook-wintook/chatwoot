# frozen_string_literal: true

# proyecto@predefinidas_prompt — docs/predefinidas_prompt_plan.md
require 'rails_helper'

RSpec.describe 'Respuestas predefinidas con prompt propio' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/canned_responses" }

  it 'guarda el prompt de contenido al crear' do
    post base, params: { short_code: 'COTIZACION EQUIPO', content: 'Cotización de equipo de cómputo.',
                         content_prompts: '1. Pedí el tipo de equipo y la cantidad.' },
               headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(account.canned_responses.last.content_prompts).to eq('1. Pedí el tipo de equipo y la cantidad.')
  end

  it 'actualiza y vacía el prompt al editar' do
    canned = create(:canned_response, account: account, content_prompts: 'viejo')

    put "#{base}/#{canned.id}", params: { content_prompts: 'nuevo' }, headers: agent.create_new_auth_token, as: :json
    expect(canned.reload.content_prompts).to eq('nuevo')

    put "#{base}/#{canned.id}", params: { content_prompts: '' }, headers: agent.create_new_auth_token, as: :json
    expect(canned.reload.content_prompts).to eq('')
  end

  # Lo que rompía el formulario: los campos del bot viejo no tienen columna en todas las
  # bases, y el modelo reventaba con UnknownAttributeError.
  it 'no revienta si llegan los campos del bot viejo' do
    post base, params: { short_code: 'CON CAMPOS VIEJOS', content: 'algo', menu: true, opcion: 3,
                         content_full: true, url_content: true, url_short_code: 'https://x.test' },
               headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(account.canned_responses.find_by(short_code: 'CON CAMPOS VIEJOS').content).to eq('algo')
  end

  it 'devuelve el prompt en la lista' do
    create(:canned_response, account: account, short_code: 'CON PROMPT', content_prompts: 'instrucciones')

    get base, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.find { |c| c['short_code'] == 'CON PROMPT' }['content_prompts']).to eq('instrucciones')
  end
end
