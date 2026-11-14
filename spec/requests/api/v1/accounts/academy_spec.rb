# frozen_string_literal: true

require 'rails_helper'

# Academia Kontrolya — «Mi capacitación»: cada quien ve y mueve solo su avance.
RSpec.describe 'Academia (Mi capacitación)' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/academy" }

  def as(user) = { headers: user.create_new_auth_token, as: :json }

  it 'lista sus módulos y lee la guía de una lección' do
    get base, **as(agent)
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['modules'].pluck('key')).to include('conversaciones', 'casos')

    get "#{base}/guides/conversaciones", **as(agent)
    expect(response.parsed_body['content']).to include('Nota privada')
  end

  it '«Leer» deja la lección leída y «Revisar» un ejercicio responde si lo encontró' do
    post "#{base}/steps/conversaciones/leer/start", **as(agent)
    expect(response.parsed_body.dig('step', 'status')).to eq('done')

    post "#{base}/steps/contactos/practica/check", **as(agent)
    expect(response.parsed_body).to include('found' => false)

    post "#{base}/practice", **as(agent)
    expect(response.parsed_body.dig('practice', 'contact_id')).to be_present

    post "#{base}/steps/contactos/practica/check", **as(agent)
    expect(response.parsed_body).to include('found' => true)
  end

  it 'el avance y la práctica son de cada quien' do
    post "#{base}/practice", **as(agent)
    post "#{base}/steps/conversaciones/leer/start", **as(agent)

    get base, **as(other)
    body = response.parsed_body
    expect(body['done']).to eq(0)
    expect(body.dig('practice', 'contact_id')).to be_nil
  end

  it 'borrar la práctica' do
    post "#{base}/practice", **as(agent)
    contact_id = response.parsed_body.dig('practice', 'contact_id')

    delete "#{base}/practice", **as(agent)
    expect(response.parsed_body.dig('practice', 'contact_id')).to be_nil
    expect(Contact.exists?(contact_id)).to be(false)
  end

  it '«Configura tu cuenta» es de administradores y lo que acepta uno vale para todos' do
    admin = create(:user, account: account, role: :administrator)
    admin2 = create(:user, account: account, role: :administrator)

    get base, **as(agent)
    expect(response.parsed_body['modules'].pluck('key')).not_to include('cuenta')
    post "#{base}/steps/cuenta/etapas/confirm", **as(agent)
    expect(response).to have_http_status(:not_found)

    post "#{base}/steps/cuenta/etapas/confirm", **as(admin)
    expect(response.parsed_body['step']).to include('status' => 'done', 'confirmed_by' => admin.name)

    get base, **as(admin2)
    etapas = response.parsed_body['modules'].first['steps'].find { |s| s['key'] == 'etapas' }
    expect(etapas).to include('status' => 'done', 'confirmed_by' => admin.name)

    post "#{base}/steps/cuenta/etapas/confirm", params: { undo: true }, **as(admin2)
    expect(response.parsed_body.dig('step', 'status')).not_to eq('done')
  end

  it 'un paso que no existe da 404' do
    post "#{base}/steps/contactos/inventado/check", **as(agent)
    expect(response).to have_http_status(:not_found)
  end
end
