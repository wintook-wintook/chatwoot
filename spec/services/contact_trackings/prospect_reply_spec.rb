# frozen_string_literal: true

require 'rails_helper'

# prospeccion V2 (docs/prospeccion_estudio.md §9 F4, §10 V2) — el prospecto respondió: ya no hay toques.
RSpec.describe ContactTrackings::ProspectReply do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City') }
  let(:tracking) do
    create(:contact_tracking, account: account, inbox: inbox, status: 'scheduled',
                              scheduled_for: 5.minutes.from_now, max_attempts: 3, attempt_count: 1)
  end

  # jueves 29/10/2026 10:00 en CDMX
  let(:thursday) { Time.find_zone('America/Mexico_City').local(2026, 10, 29, 10, 0) }

  it 'mueve el siguiente toque a 3 días hábiles, saltando el fin de semana, a la misma hora' do
    travel_to(thursday) do
      expect(described_class.call(tracking, at: thursday)).to be(true)
      # vie 30 (1) · sáb y dom no cuentan · lun 2 (2) · mar 3 (3)
      expect(tracking.reload.scheduled_for).to eq(Time.find_zone('America/Mexico_City').local(2026, 11, 3, 10, 0))
    end
  end

  it 'deja como mucho un toque más: el de recuperación' do
    travel_to(thursday) { described_class.call(tracking, at: thursday) }

    expect(tracking.reload.max_attempts).to eq(2)
  end

  it 'cada respuesta nueva vuelve a empujar la fecha y no regala más toques' do
    travel_to(thursday) { described_class.call(tracking, at: thursday) }
    later = thursday + 1.day
    travel_to(later) { described_class.call(tracking.reload, at: later) }

    expect(tracking.reload).to have_attributes(max_attempts: 2)
    expect(tracking.scheduled_for).to eq(Time.find_zone('America/Mexico_City').local(2026, 11, 4, 10, 0))
  end

  it 'no toca un seguimiento pausado, en ejecución o terminado' do
    %w[paused active completed cancelled].each do |status|
      tracking.update_columns(status: status) # rubocop:disable Rails/SkipsModelValidations
      expect { described_class.call(tracking.reload, at: thursday) }.not_to(change { tracking.reload.scheduled_for })
    end
  end

  describe 'desde el analizador de respuestas' do
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

    it 'al entrar la respuesta del prospecto, su toque programado se aleja' do
      tracking.update!(contact: contact, conversation: conversation)
      message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 message_type: :incoming, sender: contact, content: 'Claro que me interesa')
      job = ContactTrackingResponseAnalyzerJob.new
      allow(job).to receive(:process_message_for_tracking).and_return(true)

      job.perform(message.id)

      expect(tracking.reload.scheduled_for).to be > 2.days.from_now
      expect(tracking.max_attempts).to eq(2)
    end
  end
end
