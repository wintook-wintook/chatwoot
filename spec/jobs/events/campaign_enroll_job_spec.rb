# frozen_string_literal: true

require 'rails_helper'

# Plan-Eventos E3 — quien llega a un estado entra solo a las campañas continuas de ese evento.
RSpec.describe Events::CampaignEnrollJob do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:event) { account.events.create!(name: 'Feria', starts_at: 1.day.ago) }

  def campaign(attrs = {})
    account.tracking_campaigns.create!({ name: 'Gracias por venir', mode: 'continuous', status: 'running',
                                         event: event, event_status: 'attended' }.merge(attrs))
  end

  it 'inscribe a quien llega al estado en las continuas en curso de ese evento, no en las demás' do
    gracias = campaign
    pausada = campaign(name: 'Pausada', status: 'paused')
    otra = campaign(name: 'Confirmados', event_status: 'confirmed')
    attendee = event.attendees.create!(account: account, contact: contact, status: :attended)
    enrolled = []
    enroll = instance_double(TrackingCampaigns::Enroll, call: true)
    allow(TrackingCampaigns::Enroll).to receive(:new) do |c, *|
      enrolled << c.id
      enroll
    end

    described_class.perform_now(attendee.id)
    expect(enrolled).to eq([gracias.id])
    expect(enrolled).not_to include(pausada.id, otra.id)
  end

  it 'se encola al cambiar de estado' do
    attendee = event.attendees.create!(account: account, contact: contact, status: :invited)
    expect { attendee.change_status!(:attended, nil) }.to have_enqueued_job(described_class).with(attendee.id)
  end
end
