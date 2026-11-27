# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentTester::CleanupJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:sandbox) { AgentTester::Sandbox.new(account) }
  let(:template) { create(:tracking_template, account: account) }

  def aged(conversation, ago)
    conversation.update_columns(last_activity_at: ago.ago) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  it 'cierra las pláticas abiertas sin actividad de un día' do
    idle = aged(sandbox.start(template, user: user), 2.days)
    fresh = sandbox.start(template, user: user)
    described_class.perform_now
    expect(idle.reload).to be_resolved
    expect(fresh.reload).to be_open
  end

  it 'borra las de más de 7 días con su contacto, salvo las que cita la bitácora' do
    old = aged(sandbox.start(template, user: user), 8.days)
    logged = aged(sandbox.start(template, user: user), 8.days)
    AgentTestLog.create!(account: account, tracking_template: template, kind: 'prompt', engine: '1', conversation_id: logged.id)

    described_class.perform_now
    expect(Conversation.exists?(old.id)).to be(false)
    expect(Contact.exists?(old.contact_id)).to be(false)
    expect(Conversation.exists?(logged.id)).to be(true)
  end

  it 'no toca pláticas de bandejas que no son del probador' do
    other = aged(create(:conversation, account: account), 30.days)
    described_class.perform_now
    expect(Conversation.exists?(other.id)).to be(true)
  end
end
