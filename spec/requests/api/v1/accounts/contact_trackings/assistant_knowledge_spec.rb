# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — conocimiento sugerido (respuestas predefinidas)
RSpec.describe 'Asistente de Agentes IA — respuestas predefinidas del encargo' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:base)    { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/briefs" }
  let(:ficha) do
    { 'identidad' => { 'texto' => 'el asistente de Patitas' },
      'temas' => [{ 'nombre' => 'Precios', 'que_hace' => 'da precios', 'fuente' => 'predefinidas' }],
      'conocimiento' => [{ 'tema' => 'Horario', 'resumen' => 'lunes a sábado de 9:00 a 19:00' }] }
  end
  let(:brief) do
    TrackingAgentBrief.create!(account: account, user: admin, filename: 'instrucciones_patitas.md',
                               content: 'Horario lunes a sábado de 9:00 a 19:00', sha256: SecureRandom.hex(32),
                               status: 'ready', digest: { 'ficha' => ficha })
  end
  let(:modelo) do
    { grupo: 'Patitas', respuestas: [{ titulo: 'Precio vacunas', contenido: 'Cuesta <PENDIENTE: precio>.' },
                                     { titulo: 'Esterilización', contenido: 'Ayuno de 8 horas.' },
                                     { titulo: 'Horario', contenido: 'repetida' }] }
  end

  before do
    account.hooks.create!(app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    stub_request(:post, ContactTrackings::Assistant::OpenaiChat::API_URL).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { choices: [{ message: { content: modelo.to_json } }] }.to_json
    )
  end

  it 'no deja entrar a un agente' do
    post "#{base}/#{brief.id}/knowledge", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'proponer' do
    it 'junta los datos de la ficha y lo que falta, con el grupo y su estado' do
      post "#{base}/#{brief.id}/knowledge", headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['group']).to eq('PATITAS')
      expect(body['items'].map { |i| [i['short_code'], i['status']] }).to eq(
        [['PATITAS HORARIO', 'ready'], ['PATITAS PRECIO VACUNAS', 'missing'], ['PATITAS ESTERILIZACIÓN', 'unverified']]
      )
      # «8» no estaba en las instrucciones: se marca, no se da por bueno.
      expect(body['items'].last['unverified']).to eq(['8'])
    end

    it 'marca la que ya existe en la cuenta' do
      account.canned_responses.create!(short_code: 'PATITAS HORARIO', content: 'de 9 a 7')
      post "#{base}/#{brief.id}/knowledge", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['items'].first).to include('status' => 'existing', 'content' => 'de 9 a 7')
    end
  end

  describe 'crear' do
    def crear(items, group: 'PATITAS')
      post "#{base}/#{brief.id}/knowledge/create", params: { group: group, items: items },
                                                   headers: admin.create_new_auth_token, as: :json
    end

    it 'crea con el prefijo del grupo, no pisa la que existe y nunca crea una con <PENDIENTE:>' do
      account.canned_responses.create!(short_code: 'PATITAS DIRECCION', content: 'x')
      crear([{ short_code: 'PATITAS HORARIO', content: 'lunes a sábado' },
             { short_code: 'precio consulta', content: '$350' },
             { short_code: 'PATITAS DIRECCION', content: 'otra' },
             { short_code: 'PATITAS VACUNAS', content: 'Cuesta <PENDIENTE: precio>' }])

      body = response.parsed_body
      expect(body['created']).to eq(['PATITAS HORARIO', 'PATITAS PRECIO CONSULTA'])
      expect(body['skipped']).to eq(['PATITAS DIRECCION'])
      expect(body['failed']).to eq([{ 'short_code' => 'PATITAS VACUNAS', 'error' => 'pending' }])
      expect(account.canned_responses.find_by(short_code: 'PATITAS DIRECCION').content).to eq('x')
    end

    it 'rechaza un grupo que no sirve de prefijo' do
      crear([{ short_code: 'x', content: 'y' }], group: 'dos palabras')

      expect(response.parsed_body['error']).to eq('invalid_group')
    end
  end

  it 'con el grupo creado, el mensaje pide buscar solo ahí y saca los datos del Contexto' do
    post "#{base}/#{brief.id}/compose",
         params: { answers: { predefinidas_grupo: 'PATITAS', conocimiento_movido: true } },
         headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['message']).to include('@buscar_predefinidas(PATITAS)')
    expect(response.parsed_body['proposal']['ai_context']).to eq('')
  end
end
