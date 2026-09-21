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

  # Los campos que antes guardaba el bot viejo (y en chatwoot_dev reventaban el guardado):
  # ahora los guarda la API de Chatwoot, en su tabla.
  it 'guarda los campos del menú, el contenido completo y el link' do
    post base, params: { short_code: 'CON CAMPOS VIEJOS', content: 'algo', menu: true, opcion: 3,
                         content_full: true, url_content: true, url_short_code: 'https://x.test' },
               headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    guardada = account.canned_responses.find_by(short_code: 'CON CAMPOS VIEJOS')
    expect(guardada.attributes.slice('menu', 'opcion', 'content_full', 'url_content', 'url_short_code'))
      .to eq('menu' => true, 'opcion' => 3, 'content_full' => true, 'url_content' => true,
             'url_short_code' => 'https://x.test')
  end

  it 'los actualiza y los devuelve al editar' do
    canned = create(:canned_response, account: account)

    put "#{base}/#{canned.id}", params: { menu: true, opcion: 5, url_content: true, url_short_code: 'https://y.test' },
                                headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('menu' => true, 'opcion' => 5, 'url_content' => true,
                                            'url_short_code' => 'https://y.test', 'content_full' => false)
  end

  # Una respuesta sin tocar esos campos queda con los defaults de la tabla.
  it 'sin esos campos, usa los valores por defecto' do
    post base, params: { short_code: 'SIN CAMPOS', content: 'algo' }, headers: agent.create_new_auth_token, as: :json

    guardada = account.canned_responses.find_by(short_code: 'SIN CAMPOS')
    expect(guardada.attributes.slice('menu', 'opcion', 'content_full', 'url_content', 'url_short_code'))
      .to eq('menu' => false, 'opcion' => 0, 'content_full' => false, 'url_content' => false, 'url_short_code' => nil)
  end

  # La casilla "El mensaje es el prompt": aparte de content_prompts, apagada por defecto.
  it 'guarda, devuelve y apaga la casilla "El mensaje es el prompt"' do
    post base, params: { short_code: 'MENSAJE PROMPT', content: 'Pedí el equipo y la cantidad.', content_is_prompt: true },
               headers: agent.create_new_auth_token, as: :json

    guardada = account.canned_responses.find_by(short_code: 'MENSAJE PROMPT')
    expect(guardada.content_is_prompt).to be(true)
    expect(guardada.content_prompts).to be_nil

    put "#{base}/#{guardada.id}", params: { content_is_prompt: false }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body['content_is_prompt']).to be(false)
    expect(create(:canned_response, account: account).content_is_prompt).to be(false)
  end

  it 'devuelve el prompt en la lista' do
    create(:canned_response, account: account, short_code: 'CON PROMPT', content_prompts: 'instrucciones')

    get base, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.find { |c| c['short_code'] == 'CON PROMPT' }['content_prompts']).to eq('instrucciones')
  end
end
