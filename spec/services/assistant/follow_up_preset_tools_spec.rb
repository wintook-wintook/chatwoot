# frozen_string_literal: true

require 'rails_helper'

# Dali — plantillas de seguimiento: usarlas al delegar, cambiar el que corre y guardar una.
RSpec.describe Assistant::FollowUpPresetTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact) }

  before do
    AiFollowUpPreset.create!(account: account, name: 'Cobranza amable', objective: 'Que pague su saldo', max_attempts: 4,
                             interval_value: 2, interval_unit: 'days', instructions: 'Tono cordial')
    Current.user = user
    allow(AiFollowUps::RunJob).to receive(:perform_later)
  end

  after { Current.user = nil }

  it 'delega con la plantilla nombrada; lo que dice el usuario la ajusta' do
    proposal = tools.call('propose_follow_up', { 'conversation_id' => conversation.display_id, 'preset' => 'cobranza AMABLE',
                                                 'max_attempts' => 2 })[:proposal]
    expect(proposal['payload']).to include('objective' => 'Que pague su saldo', 'instruction' => 'Tono cordial', 'max_attempts' => 2,
                                           'interval_value' => 2, 'replace' => false)
    expect(proposal['labels']).to include('preset' => 'Cobranza amable')
    expect(proposal['labels']['presets'].pluck('name')).to eq(['Cobranza amable'])

    executor.call('follow_up', proposal['payload'])
    expect(AiFollowUp.live.sole).to have_attributes(objective: 'Que pague su saldo', max_attempts: 2)
  end

  it 'si ya corre uno, la tarjeta trae lo suyo, arranca en su siguiente intento y lo reemplaza' do
    live = AiFollowUps::Creator.new(account: account, user: user, conversation: conversation,
                                    params: { 'objective' => 'Que confirme', 'starts_at' => 2.days.from_now }).call
    proposal = tools.call('propose_follow_up', { 'conversation_id' => conversation.display_id, 'max_attempts' => 5 })[:proposal]
    expect(proposal['payload']).to include('objective' => 'Que confirme', 'max_attempts' => 5, 'replace' => true)
    expect(Time.zone.parse(proposal['payload']['starts_at'])).to be_within(1.minute).of(live.next_run_at)
    expect(proposal['labels']['replaces']).to include('objective' => 'Que confirme')

    executor.call('follow_up', proposal['payload'])
    expect(live.reload.status).to eq('cancelled')
  end

  it 'lista las plantillas y guarda una nueva' do
    expect(tools.call('follow_up_presets', {})[:result][:presets].pluck(:name)).to eq(['Cobranza amable'])

    proposal = tools.call('propose_save_follow_up_preset', { 'name' => 'Seguimiento de cotización',
                                                             'objective' => 'Que confirme la cotización' })[:proposal]
    executor.call('save_follow_up_preset', proposal['payload'])
    expect(account.ai_follow_up_presets.find_by(name: 'Seguimiento de cotización')).to have_attributes(created_by_id: user.id)
  end

  it 'no inventa: una plantilla que no existe es un error' do
    result = tools.call('propose_follow_up', { 'conversation_id' => conversation.display_id, 'preset' => 'Otra' })
    expect(result[:result][:error]).to include('No hay una plantilla')
  end
end
