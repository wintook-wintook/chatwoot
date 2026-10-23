require 'rails_helper'

RSpec.describe DeleteObjectJob do
  subject(:job) { described_class.perform_later(account) }

  let(:account) { create(:account) }

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(account)
      .on_queue('low')
  end

  context 'when an object is passed to the job' do
    it 'is deleted' do
      described_class.perform_now(account)
      expect { account.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  # Las llaves foráneas a users sin ON DELETE impedían borrar al usuario (PG::ForeignKeyViolation).
  context 'when the user has records in custom tables' do
    let(:user) { create(:user, account: account) }
    let!(:calendar) { UserCalendarIntegration.create!(user: user, account: account, google_email: 'agente@example.com') }
    let!(:template) { create(:tracking_template, account: account, user: user) }

    it 'deletes the user, drops its calendar and keeps the account template' do
      described_class.perform_now(user)

      expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(UserCalendarIntegration.exists?(calendar.id)).to be(false)
      expect(template.reload.user_id).to be_nil
    end
  end
end
