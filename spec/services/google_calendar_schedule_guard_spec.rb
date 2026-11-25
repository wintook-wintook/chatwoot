# frozen_string_literal: true

require 'rails_helper'

# fix/calendario_google F3b — ¿puedo agendarle a este compañero en su Google Calendar?
RSpec.describe GoogleCalendarScheduleGuard do
  let(:account) { create(:account) }
  let(:ana) { create(:user, account: account, role: :agent) }
  let(:beto) { create(:user, account: account, role: :agent) }
  let(:coworker_service) { instance_double(GoogleCalendarCoworkerService) }

  def connect(user, email)
    UserCalendarIntegration.create!(user: user, account: account, google_email: email, tokens: { 'access_token' => 't' })
  end

  def guard(agent_id, **opts)
    described_class.new(account: account, viewer: ana, agent_id: agent_id, **opts).call
  end

  before do
    allow(GoogleCalendarService).to receive(:new).and_return(instance_double(GoogleCalendarService))
    allow(GoogleCalendarCoworkerService).to receive(:new).and_return(coworker_service)
  end

  it 'agente de otra cuenta → agent_not_found' do
    expect(guard(create(:user).id).reason).to eq('agent_not_found')
  end

  it 'compañero sin Google → agent_not_connected (o pasa si se permite)' do
    expect(guard(beto.id).reason).to eq('agent_not_connected')
    expect(guard(beto.id, allow_without_google: true)).to be_ok
  end

  context 'when el compañero tiene Google' do
    let!(:beto_integration) { connect(beto, 'beto@gmail.com') }

    it 'yo sin Google → viewer_not_connected' do
      expect(guard(beto.id).reason).to eq('viewer_not_connected')
    end

    it 'mismo Google → same_google' do
      connect(ana, 'BETO@gmail.com')
      expect(guard(beto.id).reason).to eq('same_google')
    end

    it 'sin «Hacer cambios» → no_permission con mensaje claro' do
      connect(ana, 'ana@gmail.com')
      allow(coworker_service).to receive(:can_schedule?).with(beto_integration).and_return(false)
      result = guard(beto.id)
      expect(result.reason).to eq('no_permission')
      expect(result.error).to eq(I18n.t('google_calendar_schedule.no_permission'))
    end

    it 'con «Hacer cambios» → ok' do
      connect(ana, 'ana@gmail.com')
      allow(coworker_service).to receive(:can_schedule?).with(beto_integration).and_return(true)
      result = guard(beto.id)
      expect(result).to be_ok
      expect(result.coworker_integration).to eq(beto_integration)
    end
  end
end
