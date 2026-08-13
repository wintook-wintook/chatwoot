# frozen_string_literal: true

# proyecto@ai_agent_assistant — ramificar un Agente IA.
#
# Ramificar NO es versionar: para mejorar el mismo agente está el historial (§13.4
# del plan: la 778 tiene seis agentes que en realidad son uno). Esto sirve para el
# mismo texto en otro canal o para un caso vecino que arranca de aquí.
#
# Lo que se prueba es lo que rompería la copia en silencio: el nombre es único por
# cuenta, los adjuntos son parte del agente, y el original no se puede tocar.
require 'rails_helper'

RSpec.describe 'Tracking Template duplicate API', type: :request do
  let!(:account) { create(:account) }
  let(:agent)    { create(:user, account: account, role: :agent) }
  let(:inbox)    { create(:inbox, account: account) }
  let!(:template) do
    create(:tracking_template, account: account, inbox: inbox, name: 'Cobranza',
                               objective: 'Confirmar el pago de la factura vencida.',
                               complementary_prompt: "Eres cobranza.\nNo prometas descuentos.")
  end
  let(:url) { "/api/v1/accounts/#{account.id}/tracking_templates/#{template.id}/duplicate" }

  def duplicate(params = {})
    post url, params: params, headers: agent.create_new_auth_token, as: :json
  end

  it 'returns unauthorized for an unauthenticated user' do
    post url
    expect(response).to have_http_status(:unauthorized)
  end

  it 'copia el contenido del agente en uno nuevo' do
    duplicate(name: 'Cobranza · Telegram')

    expect(response).to have_http_status(:created)
    copia = account.tracking_templates.find(response.parsed_body['id'])
    expect(copia.complementary_prompt).to eq(template.complementary_prompt)
    expect(copia.objective).to eq(template.objective)
    expect(copia.name).to eq('Cobranza · Telegram')
  end

  it 'deja el original intacto' do
    expect { duplicate }.not_to(change { template.reload.attributes })
  end

  # El nombre es único por cuenta: sin resolver la colisión, duplicar dos veces
  # revienta con un error de base de datos en vez de dar el segundo agente.
  it 'no choca al duplicar dos veces seguidas' do
    duplicate
    primera = response.parsed_body['name']
    duplicate
    segunda = response.parsed_body['name']

    expect(response).to have_http_status(:created)
    expect(primera).to eq('Cobranza (copia)')
    expect(segunda).to eq('Cobranza (copia) 2')
  end

  it 'tampoco choca contra un nombre que ya existía a mano' do
    create(:tracking_template, account: account, name: 'Cobranza (copia)')

    duplicate

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['name']).to eq('Cobranza (copia) 2')
  end

  # Una v1 marcada `create` diría que el agente nació en blanco. Nació de otro, y
  # quien lo abra dentro de un mes necesita saber de cuál.
  it 'nace con una versión que dice de dónde salió' do
    duplicate

    copia = account.tracking_templates.find(response.parsed_body['id'])
    version = copia.versions.first
    expect(version.source).to eq('fork')
    expect(version.note).to include('Cobranza', template.id.to_s)
  end

  it 'la copia no nace archivada aunque el original lo esté' do
    template.update!(archived_at: Time.current)

    duplicate

    copia = account.tracking_templates.find(response.parsed_body['id'])
    expect(copia.archived_at).to be_nil
  end

  # Un {{nombre}} sin su archivo deja la copia rota y sin decirlo.
  it 'se lleva los adjuntos del agente' do
    adjunto = template.ai_agent_attachments.new(account: account, name: 'catalogo')
    adjunto.file.attach(io: StringIO.new('contenido'), filename: 'catalogo.pdf',
                        content_type: 'application/pdf')
    adjunto.save!

    duplicate

    copia = account.tracking_templates.find(response.parsed_body['id'])
    expect(copia.ai_agent_attachments.pluck(:name)).to eq(['catalogo'])
    expect(copia.ai_agent_attachments.first.file).to be_attached
  end

  it 'no duplica un agente de otra cuenta' do
    ajeno = create(:tracking_template, account: create(:account), name: 'Ajeno')

    post "/api/v1/accounts/#{account.id}/tracking_templates/#{ajeno.id}/duplicate",
         headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
