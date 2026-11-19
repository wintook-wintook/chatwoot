# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261119120000_agent_functions.rb')

# La migración que pasa los agentes listos de antes a la lista de agentes (motor 2.0, función
# «Atención a prospectos») sin perder nombre, bandejas, respuestas ni pláticas vivas.
RSpec.describe AgentFunctions do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:old) do
    ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: true, inbox_ids: [inbox.id], created_by: admin,
                       settings: { 'objective' => 'appointment', 'appointment_minutes' => '45', 'instructions' => 'Sé breve',
                                   'qualify' => [{ 'key' => 'budget', 'on' => true, 'text' => '' }] })
  end

  def move = described_class.new.tap { |m| m.verbose = false }.send(:move_ready_agents)

  it 'cada agente listo queda como agente 2.0 de la lista, con sus respuestas, y el de antes se apaga' do
    conversation = create(:conversation, account: account, inbox: inbox)
    ReadyAgentSession.create!(account: account, ready_agent: old, conversation: conversation, contact: conversation.contact,
                              answers: { 'Presupuesto' => '20 mil' })

    move

    template = account.tracking_templates.find(old.reload.settings['moved_to'])
    expect(template).to have_attributes(name: 'Sofi', customer_display_name: 'Sofi', engine: '2', agent_function: 'prospects',
                                        attending: true, attend_inbox_ids: [inbox.id], user_id: admin.id, calendar_event_duration: 45)
    expect(template.motor2['answers']).to include('objective' => 'appointment', 'qualify' => [include('key' => 'budget')])
    expect(template.motor2['instructions']).to eq('Sé breve')
    expect(old.enabled).to be(false)

    tracking = ContactTracking.find_by(conversation_id: conversation.id)
    expect(tracking).to have_attributes(tracking_template_id: template.id, status: 'active')
    expect(tracking.motor2_state['answers']).to eq('Presupuesto' => '20 mil')
  end

  it 'si ya hay un agente con ese nombre, le agrega la función; y no se pasa dos veces' do
    create(:tracking_template, account: account, name: 'Sofi')
    move
    move

    expect(account.tracking_templates.where(agent_function: 'prospects').pluck(:name)).to eq(['Sofi (Atención a prospectos)'])
  end
end
