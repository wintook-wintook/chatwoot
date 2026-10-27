# frozen_string_literal: true

require 'rails_helper'

# Embudo de contactos — lo que el tablero de conversaciones ya hacía sigue igual
# para los tableros existentes (todo lo nuevo viene apagado).
RSpec.describe 'Tablero de conversaciones (compatibilidad)', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:board) { create(:kanban_type_process, account: account) }
  let!(:first_column) { create(:kanban_process, kanban_type_process: board, position: 0, default: true) }
  let!(:second_column) { create(:kanban_process, kanban_type_process: board, position: 1) }
  let(:base) { "/api/v1/accounts/#{account.id}" }

  it 'lista los tableros con sus columnas' do
    get "#{base}/kanban_type_processes", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    row = response.parsed_body.find { |b| b['id'] == board.id }
    expect(row['auto_move']).to be(false)
    expect(row['kanban_processes'].pluck('id')).to contain_exactly(first_column.id, second_column.id)
  end

  it 'con blank: true crea el tablero vacío, como antes' do
    post "#{base}/kanban_type_processes", params: { kanban_type_process: { process_name: 'Viejo' }, blank: true },
                                          headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    created = KanbanTypeProcess.find(response.parsed_body['id'])
    expect(created.kanban_processes).to be_empty
    expect(created.auto_move).to be(false)
  end

  it 'mover la tarjeta a mano la cambia de columna y lo anota como manual' do
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: first_column.id)

    patch "#{base}/conversations/#{conversation.display_id}/update_kanban_process",
          params: { conversation: { kanban_type_process_id: board.id, kanban_process_id: second_column.id } },
          headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.kanban_process_id).to eq(second_column.id)
    expect(conversation.kanban_move_source).to eq('manual')
    expect(conversation.kanban_moved_by_id).to eq(admin.id)
    expect(KanbanMove.where(conversation: conversation).last).to have_attributes(
      from_process_id: first_column.id, to_process_id: second_column.id, source: 'manual', user_id: admin.id
    )
  end

  it 'el filtro del tablero devuelve las tarjetas con quién las movió y su caso' do
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: first_column.id)

    get "#{base}/conversations/kanban/filter_by_both_kanban",
        params: { kanban_type_process_id: board.id, kanban_process_id: first_column.id }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:success)
    card = response.parsed_body['data'].first
    expect(card['id']).to eq(conversation.display_id)
    expect(card['kanban_move']).to include('source' => 'automation')
    expect(card).to have_key('case_ticket')
  end

  it 'en Convertido/Descartado con closed_days solo trae lo reciente y cuenta lo demás' do
    second_column.update!(stage_kind: :converted)
    old_one = create(:conversation, account: account, inbox: inbox)
    [conversation, old_one].each { |c| c.update!(kanban_type_process_id: board.id, kanban_process_id: second_column.id) }
    old_one.update_columns(kanban_moved_at: 40.days.ago) # rubocop:disable Rails/SkipsModelValidations
    params = { kanban_type_process_id: board.id, kanban_process_id: second_column.id, closed_days: 30 }

    get "#{base}/conversations/kanban/filter_by_both_kanban", params: params, headers: admin.create_new_auth_token

    expect(response.parsed_body['data'].pluck('id')).to eq([conversation.display_id])
    expect(response.parsed_body['meta']['older_count']).to eq(1)

    second_column.update!(stage_kind: :open)
    get "#{base}/conversations/kanban/filter_by_both_kanban", params: params, headers: admin.create_new_auth_token
    expect(response.parsed_body['data'].size).to eq(2)
    expect(response.parsed_body['meta']['older_count']).to eq(0)
  end

  it 'marca «Frío» la tarjeta cuyo cliente no escribe en los días del embudo' do
    board.update!(cold_after_days: 3)
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: first_column.id)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, created_at: 5.days.ago)

    get "#{base}/conversations/kanban/filter_by_both_kanban",
        params: { kanban_type_process_id: board.id, kanban_process_id: first_column.id }, headers: admin.create_new_auth_token

    expect(response.parsed_body['data'].first['kanban_cold']).to be(true)
  end

  it 'devuelve las métricas del embudo' do
    get "#{base}/kanban_type_processes/#{board.id}/funnel_metrics", params: { days: 7 }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('days' => 7, 'entries' => 0)
  end

  it 'la acción de automatización mete la conversación a la columna predeterminada' do
    ActionService.new(conversation).assign_kanban_type_process([board.id])

    expect(conversation.reload).to have_attributes(kanban_type_process_id: board.id, kanban_process_id: first_column.id,
                                                   kanban_move_source: 'automation')
  end

  it 'un tablero existente no mueve nada solo' do
    conversation.update!(kanban_type_process_id: board.id, kanban_process_id: first_column.id)
    second_column.update!(entry_triggers: [{ 'type' => 'label_added', 'labels' => ['interesado'] }])

    Kanban::FunnelMover.new(conversation.reload).trigger!(:label_added, labels: ['interesado'])

    expect(conversation.reload.kanban_process_id).to eq(first_column.id)
  end

  it 'guarda las reglas de una columna y rechaza un disparador desconocido' do
    url = "#{base}/kanban_type_processes/#{board.id}/kanban_processes/#{second_column.id}"
    patch url, params: { kanban_process: { entry_triggers: [{ type: 'label_added', labels: ['vip'] }], ai_criteria: 'Pidió precio' } },
               headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(second_column.reload.entry_triggers).to eq([{ 'type' => 'label_added', 'labels' => ['vip'] }])

    patch url, params: { kanban_process: { entry_triggers: [{ type: 'magia' }] } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
