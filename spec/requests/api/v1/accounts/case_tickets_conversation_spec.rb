# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — el ticket abierto desde una conversacion tiene que quedarse
# con el hilo. El dashboard manda el `display_id` (la API de Chatwoot publica
# display_id bajo el nombre `id`), asi que el controlador tiene que buscar por
# ahi: buscando por llave primaria el ticket nacia sin conversacion, en silencio.
RSpec.describe 'Case Tickets API — conversacion de origen' do
  let(:account)      { create(:account) }
  let(:admin)        { create(:user, account: account, role: :administrator) }
  let(:contact)      { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:case_type)    { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  def crear_ticket(conversation_id)
    post "/api/v1/accounts/#{account.id}/case_tickets",
         params: { case_ticket: { contact_id: contact.id, case_type_id: case_type.id,
                                  title: 'No puedo timbrar', conversation_id: conversation_id } },
         headers: admin.create_new_auth_token,
         as: :json
  end

  it 'la conversacion de prueba tiene display_id distinto de su llave primaria' do
    # Si estos dos numeros coincidieran, el resto de las pruebas no probaria nada.
    expect(conversation.display_id).not_to eq(conversation.id)
  end

  it 'liga la conversacion cuando llega el display_id, que es lo que manda el dashboard' do
    crear_ticket(conversation.display_id)

    expect(response).to have_http_status(:created)
    ticket = CaseTicket.find(response.parsed_body['case_ticket']['id'])
    expect(ticket.conversation).to eq(conversation)
  end

  it 'devuelve el display_id en la ficha, que es lo que la pantalla usa para pintar el hilo' do
    crear_ticket(conversation.display_id)

    expect(response.parsed_body['case_ticket']['conversation_display_id']).to eq(conversation.display_id)
  end

  it 'deja el ticket sin conversacion si no se manda ninguna' do
    crear_ticket(nil)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_ticket']['conversation_id']).to be_nil
  end

  it 'no engancha conversaciones de otra cuenta' do
    ajena = create(:conversation)

    crear_ticket(ajena.display_id)

    expect(response).to have_http_status(:created)
    ticket = CaseTicket.find(response.parsed_body['case_ticket']['id'])
    expect(ticket.conversation).to be_nil
  end
end
