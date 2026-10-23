# frozen_string_literal: true

require 'rails_helper'

# proyecto@automatizacion_campanas — Fase 2: envío de un seguimiento tomado por el despachador.
# Meta se simula con webmock (mensaje de sesión: ventana de 24 h abierta).
RSpec.describe TrackingDispatch::SendJob do
  let!(:account) { create(:account) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }
  let!(:contact) { create(:contact, account: account, phone_number: '+5215512345678') }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:claimed_at) { 1.minute.ago.floor(6) }
  let!(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation_id: conversation.id,
                              retry_interval_value: 30, retry_interval_unit: 'minutes')
      .tap { |t| t.update_columns(status: 'active', dispatched_at: claimed_at, scheduled_for: 2.minutes.ago) } # rubocop:disable Rails/SkipsModelValidations
  end
  let(:token) { TrackingDispatch.token(claimed_at) }
  let(:env) { { 'TRACKING_DISPATCHER_ACCOUNTS' => account.id.to_s } }

  before do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     content: 'hola', created_at: 1.hour.ago)
    # Explícito y no described_class: el bloque de DispatchJob de abajo también usa este before.
    allow_any_instance_of(TrackingDispatch::SendJob).to receive(:generate_message).and_return('mensaje de seguimiento') # rubocop:disable RSpec/AnyInstance, RSpec/DescribedClass
  end

  def meta_accepts
    stub_request(:post, %r{graph\.facebook\.com/.*/messages})
      .to_return(status: 200, body: { messages: [{ id: 'wamid.ok' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def run(with_token = token)
    with_modified_env(env) { described_class.perform_now(tracking.id, with_token) }
  end

  it 'envía, avanza el intento, lo reprograma y suelta la marca' do
    meta_accepts

    run

    expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 1, dispatched_at: nil)
    expect(tracking.scheduled_for).to be_within(10.seconds).of(30.minutes.from_now)
    expect(tracking.tracking_deliveries.last).to have_attributes(status: 'sent', source_id: 'wamid.ok')
  end

  # proyecto@adaptar_prompts_publicados (F5)
  it 'con <PENDIENTE:> en su Entrenamiento no envía: queda fallido con el motivo' do
    tracking.update_columns(complementary_prompt: 'Eres de <PENDIENTE: Nombre del negocio>.') # rubocop:disable Rails/SkipsModelValidations
    envio = meta_accepts

    run

    expect(envio).not_to have_been_requested
    expect(tracking.reload).to have_attributes(status: 'failed', dispatched_at: nil)
    expect(tracking.last_error).to include('Nombre del negocio')
  end

  it 'con otra marca no hace nada (otra vuelta ya lo resolvió)' do
    request = meta_accepts

    run(TrackingDispatch.token(5.minutes.ago))

    expect(request).not_to have_been_requested
    expect(tracking.reload).to have_attributes(status: 'active', attempt_count: 0)
  end

  it 'recuperación: si el envío de esta marca ya quedó registrado, no lo vuelve a mandar' do
    request = meta_accepts
    TrackingDelivery.create!(account: account, contact_tracking: tracking, kind: 'session', attempt_number: 1,
                             status: 'sent', sent_at: Time.current)

    run

    expect(request).not_to have_been_requested
    expect(tracking.reload).to have_attributes(status: 'scheduled', attempt_count: 1, dispatched_at: nil)
  end

  it 'si lo pausaron mientras se enviaba, respeta la pausa y solo cuenta el intento' do
    meta_accepts
    allow_any_instance_of(described_class).to receive(:generate_message) do # rubocop:disable RSpec/AnyInstance
      ContactTracking.where(id: tracking.id).update_all(status: 'paused') # rubocop:disable Rails/SkipsModelValidations
      'mensaje de seguimiento'
    end

    run

    expect(tracking.reload).to have_attributes(status: 'paused', attempt_count: 1, dispatched_at: nil)
  end

  it 'si la campaña se pausó después de tomarlo, lo regresa a la fila sin enviar' do
    request = meta_accepts
    campaign = create(:tracking_campaign, account: account, inbox: inbox, status: 'paused')
    tracking.update_columns(tracking_campaign_id: campaign.id) # rubocop:disable Rails/SkipsModelValidations

    run

    expect(request).not_to have_been_requested
    expect(tracking.reload).to have_attributes(status: 'scheduled', dispatched_at: nil)
  end

  describe 'cuenta con despachador' do
    it 'el seguimiento no programa job propio ni recorre las colas de Sidekiq' do
      with_modified_env(env) do
        expect { tracking.update!(status: 'scheduled', scheduled_for: 1.hour.from_now) }.not_to have_enqueued_job(ContactTrackingJob)
        expect(tracking.send(:cancel_existing_jobs)).to eq(0)
      end
    end

    it 'un ContactTrackingJob viejo que quedó en Sidekiq no envía' do
      request = meta_accepts
      tracking.update_columns(status: 'scheduled', dispatched_at: nil) # rubocop:disable Rails/SkipsModelValidations

      with_modified_env(env) { ContactTrackingJob.perform_now(tracking.id) }

      expect(request).not_to have_been_requested
    end
  end

  describe TrackingDispatch::DispatchJob do
    it 'toma los vencidos y encola su envío con la marca' do
      tracking.update_columns(status: 'scheduled', dispatched_at: nil) # rubocop:disable Rails/SkipsModelValidations
      allow(TrackingDispatch::MessagingTier).to receive(:daily_limit).and_return(nil)

      with_modified_env(env) do
        expect { described_class.perform_now }.to have_enqueued_job(TrackingDispatch::SendJob).with(tracking.id, String)
      end
      expect(tracking.reload.status).to eq('active')
    end

    it 'reencola una sola vez lo que quedó tomado demasiado tiempo' do
      stale = 15.minutes.ago.floor(6)
      tracking.update_columns(dispatched_at: stale) # rubocop:disable Rails/SkipsModelValidations
      Redis::Alfred.delete("tracking_dispatch:recovered:#{tracking.id}:#{TrackingDispatch.token(stale)}")

      with_modified_env(env) do
        expect { described_class.perform_now }.to have_enqueued_job(TrackingDispatch::SendJob).with(tracking.id, TrackingDispatch.token(stale))
        expect { described_class.perform_now }.not_to have_enqueued_job(TrackingDispatch::SendJob)
      end
    end
  end
end
