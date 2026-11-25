# frozen_string_literal: true

require 'rails_helper'

# fix/calendario_google F1 — respuestas reales medidas en la F0 (docs/calendario_google_compartido_plan.md).
RSpec.describe GoogleCalendarCoworkerService do
  subject(:service) { described_class.new(viewer_integration: viewer, viewer_service: viewer_service) }

  let(:viewer) { instance_double(UserCalendarIntegration, id: 1, user_id: 1, google_email: 'a@gmail.com') }
  let(:coworker) { instance_double(UserCalendarIntegration, id: 4, user_id: 4, google_email: 'b@gmail.com') }
  let(:viewer_service) { instance_double(GoogleCalendarService) }
  let(:tmin) { Time.zone.parse('2026-11-23 00:00') }
  let(:tmax) { Time.zone.parse('2026-11-30 00:00') }

  let(:full_event) do
    { 'id' => 'e1', 'summary' => 'Visita cliente', 'location' => 'Oficina',
      'start' => { 'dateTime' => '2026-11-26T07:00:00-06:00' }, 'end' => { 'dateTime' => '2026-11-26T07:15:00-06:00' } }
  end
  let(:hidden_event) do
    { 'id' => 'e2', 'visibility' => 'private',
      'start' => { 'dateTime' => '2026-11-26T08:00:00-06:00' }, 'end' => { 'dateTime' => '2026-11-26T08:15:00-06:00' } }
  end

  def google_says(code:, role: nil, items: [])
    allow(viewer_service).to receive(:list_shared_events)
      .with(calendar_id: 'b@gmail.com', time_min: tmin, time_max: tmax)
      .and_return({ code: code, access_role: role, items: items })
  end

  def fetch
    service.fetch(coworker, time_min: tmin, time_max: tmax)
  end

  it 'no compartido (404) → none, sin eventos' do
    google_says(code: 404)
    expect(fetch).to include(agent_id: 4, access: 'none', can_schedule: false, events: [])
  end

  it 'solo libre/ocupado → free_busy con eventos sin título' do
    google_says(code: 200, role: 'freeBusyReader', items: [hidden_event])
    result = fetch
    expect(result).to include(access: 'free_busy', can_schedule: false)
    expect(result[:events].first).to include(id: 'e2', summary: nil, private: true, all_day: false)
  end

  it 'ver detalles → details; los privados llegan como ocupados' do
    google_says(code: 200, role: 'reader', items: [full_event, hidden_event])
    result = fetch
    expect(result).to include(access: 'details', can_schedule: false)
    expect(result[:events].pluck(:summary)).to eq(['Visita cliente', nil])
    expect(result[:events].first).to include(location: 'Oficina', start: '2026-11-26T07:00:00-06:00')
  end

  it 'hacer cambios (writer) → details y puede agendarle' do
    google_says(code: 200, role: 'writer', items: [full_event])
    expect(fetch).to include(access: 'details', can_schedule: true)
  end

  it 'evento de todo el día' do
    all_day = { 'id' => 'e3', 'summary' => 'Vacaciones', 'start' => { 'date' => '2026-11-27' }, 'end' => { 'date' => '2026-11-28' } }
    google_says(code: 200, role: 'reader', items: [all_day])
    expect(fetch[:events].first).to include(all_day: true, start: '2026-11-27', end: '2026-11-28')
  end

  it '403 (p. ej. cuota) es error, no «no compartido»' do
    google_says(code: 403)
    expect(fetch).to include(access: 'error', events: [])
  end

  it 'si Google truena, ese compañero sale como error y no rompe a los demás' do
    allow(viewer_service).to receive(:list_shared_events).and_raise('timeout')
    expect(fetch).to include(access: 'error', can_schedule: false)
  end

  it 'mismo Google que quien mira → same_google sin preguntar a Google' do
    twin = instance_double(UserCalendarIntegration, id: 5, user_id: 5, google_email: 'A@gmail.com')
    allow(viewer_service).to receive(:list_shared_events)
    expect(service.fetch(twin, time_min: tmin, time_max: tmax)).to include(access: 'same_google', can_schedule: false)
    expect(viewer_service).not_to have_received(:list_shared_events)
  end

  it 'consulta con el servicio de QUIEN MIRA usando el correo del compañero' do
    google_says(code: 404)
    fetch
    expect(viewer_service).to have_received(:list_shared_events).with(calendar_id: 'b@gmail.com', time_min: tmin, time_max: tmax)
  end

  describe 'caché' do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before { allow(Rails).to receive(:cache).and_return(store) }

    it 'reusa la respuesta y la invalida al cambiar un permiso del dueño' do
      google_says(code: 200, role: 'reader', items: [full_event])
      2.times { fetch }
      expect(viewer_service).to have_received(:list_shared_events).once

      described_class.clear_cache_for('B@gmail.com')
      fetch
      expect(viewer_service).to have_received(:list_shared_events).twice
    end
  end
end
