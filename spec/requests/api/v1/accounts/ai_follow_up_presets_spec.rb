# frozen_string_literal: true

require 'rails_helper'

# Plantillas de seguimiento y cambiar el seguimiento que corre (reemplazar).
RSpec.describe 'AI follow-up presets' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket) { CaseTicket.create!(account: account, title: 'Cobro', contact: contact, case_type: soporte, conversation: conversation) }
  let(:presets) { "/api/v1/accounts/#{account.id}/ai_follow_up_presets" }
  let(:follow_ups) { "/api/v1/accounts/#{account.id}/ai_follow_ups" }

  before { allow(AiFollowUps::RunJob).to receive(:perform_later) }

  it 'guarda, lista y usa una plantilla; solo quien la creó o un admin la cambia' do
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    post presets, params: { name: 'Cobranza amable', objective: 'Que pague su saldo', max_attempts: 3, interval_value: 2,
                            interval_unit: 'days' }, headers: agent.create_new_auth_token, as: :json
    preset = response.parsed_body['payload']
    expect(preset).to include('name' => 'Cobranza amable', 'interval_value' => 2, 'editable' => true)

    post presets, params: { name: 'cobranza AMABLE', objective: 'x' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    get presets, headers: admin.create_new_auth_token
    expect(response.parsed_body['payload'].sole).to include('editable' => true, 'summary' => include('Que pague su saldo'))

    other = AiFollowUpPreset.create!(account: account, name: 'Del admin', objective: 'Algo', created_by: admin)
    patch "#{presets}/#{other.id}", params: { name: 'Cambiado' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
    delete "#{presets}/#{preset['id']}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:no_content)
  end

  it 'cambiar el seguimiento que corre: cancela el vivo y arranca el nuevo' do
    post follow_ups, params: { case_id: ticket.id, conversation_id: conversation.display_id, objective: 'Que pague' },
                     headers: admin.create_new_auth_token, as: :json
    old_id = response.parsed_body.dig('payload', 'id')

    post follow_ups, params: { case_id: ticket.id, conversation_id: conversation.display_id, objective: 'Que pague hoy' },
                     headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['error']).to include('ya tiene')

    post follow_ups, params: { case_id: ticket.id, conversation_id: conversation.display_id, objective: 'Que pague hoy',
                               max_attempts: 5, replace: true }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('payload', 'objective')).to eq('Que pague hoy')
    expect(AiFollowUp.find(old_id)).to have_attributes(status: 'cancelled')
    expect(AiFollowUp.live.where(conversation_id: conversation.id).sole.max_attempts).to eq(5)
    expect(ticket.case_events.where(event_type: :internal_note).last.payload['content']).to include('Se cambió')
  end
end
