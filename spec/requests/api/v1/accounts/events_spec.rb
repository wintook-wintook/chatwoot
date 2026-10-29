# frozen_string_literal: true

require 'rails_helper'

# Plan-Eventos E1 — eventos, su lista de contactos con estado, check-in y cierre.
RSpec.describe 'Events API' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:ana) { create(:contact, account: account, name: 'Ana', email: 'ana@acme.mx') }
  let!(:luis) { create(:contact, account: account, name: 'Luis', phone_number: '+525511112222') }
  let(:base) { "/api/v1/accounts/#{account.id}/events" }

  def give_role(user, key)
    role = AccessRole.for_account(account).find { |r| r.key == key }
    account.account_users.find_by(user: user).update!(access_role: role)
  end

  it 'alta, agregar confirmados, check-in y cerrar: quien no llegó queda como «no asistió»' do
    post base, params: { event: { name: 'Feria octubre', kind: 'fair', status: 'open', starts_at: 1.day.from_now } },
               headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body['event']['id']

    post "#{base}/#{id}/add_attendees", params: { contact_ids: [ana.id, luis.id], status: 'confirmed' },
                                        headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('added' => 2)

    attendee = Event.find(id).attendees.find_by(contact: ana)
    post "#{base}/#{id}/update_attendee", params: { attendee_id: attendee.id, status: 'attended' },
                                          headers: admin.create_new_auth_token, as: :json
    expect(attendee.reload).to have_attributes(status: 'attended', updated_by: admin)
    expect(attendee.attended_at).to be_present

    post "#{base}/#{id}/close", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['event']).to include('status' => 'closed')
    expect(response.parsed_body['event']['counts']).to include('attended' => 1, 'no_show' => 1, 'confirmed' => 0)
  end

  it 'no duplica a quien ya está e importa el estado por CSV' do
    event = account.events.create!(name: 'Curso', starts_at: 1.day.from_now)
    event.attendees.create!(account: account, contact: ana)
    post "#{base}/#{event.id}/add_attendees", params: { contact_ids: [ana.id] }, headers: admin.create_new_auth_token,
                                              as: :json
    expect(response.parsed_body).to include('added' => 0)

    csv = "contacto,estado\nana@acme.mx,asistió\n525511112222,confirmó\nnadie@x.mx,\n"
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv', original_filename: 'asistentes.csv')
    post "#{base}/#{event.id}/import", params: { file: file }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('added' => 1, 'updated' => 1)
    expect(response.parsed_body['errors'].first).to include('line' => 4)
    expect(event.attendees.find_by(contact: luis)).to have_attributes(status: 'confirmed', source: 'csv')
  end

  it 'agrega los contactos de un segmento (con la condición «Evento»)' do
    feria = account.events.create!(name: 'Feria', starts_at: 3.days.ago)
    feria.attendees.create!(account: account, contact: ana, status: :attended)
    segment = account.custom_filters.create!(
      user: admin, name: 'Asistieron', filter_type: :contact,
      query: { payload: [{ attribute_key: 'event', filter_operator: 'equal_to', values: ["#{feria.id}:attended"],
                           query_operator: nil }] }
    )
    curso = account.events.create!(name: 'Curso', starts_at: 5.days.from_now)
    post "#{base}/#{curso.id}/add_segment", params: { segment_id: segment.id, status: 'invited' },
                                            headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('added' => 1)
    expect(curso.attendees.pluck(:contact_id, :source)).to eq([[ana.id, 'segment']])
  end

  it 'la página del evento lista sus campañas' do
    event = account.events.create!(name: 'Feria', starts_at: 1.day.from_now)
    account.tracking_campaigns.create!(name: 'Recordatorio', mode: 'continuous', status: 'saved', event: event,
                                       event_status: 'invited')
    get "#{base}/#{event.id}", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['event']['campaigns'].first).to include('name' => 'Recordatorio',
                                                                        'event_status' => 'invited')
  end

  it 'el historial del contacto y sin el área de Campañas no entra' do
    event = account.events.create!(name: 'Demo', starts_at: 2.days.ago)
    event.attendees.create!(account: account, contact: ana, status: :attended)
    get "#{base}/for_contact", params: { contact_id: ana.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['attendances'].first).to include('status' => 'attended')
    expect(response.parsed_body['attendances'].first['event']).to include('name' => 'Demo')

    give_role(agent, 'technician')
    get base, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
