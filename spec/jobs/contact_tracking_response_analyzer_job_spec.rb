# frozen_string_literal: true

require 'rails_helper'

# proyecto@ai_agent_attachments
RSpec.describe ContactTrackingResponseAnalyzerJob do
  subject(:job) { described_class.new }

  let(:account) { create(:account) }
  let(:tracking_template) { create(:tracking_template, account: account) }
  let(:tracking) { ContactTracking.new(account: account, tracking_template: tracking_template) }

  describe '#resolve_attachment_directives' do
    let!(:attachment) do
      create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'catalogo')
    end

    it 'resolves an existing directive and strips the token from the text' do
      content = 'Aquí tienes @adjunto:catalogo y nada más.'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(clean).to eq('Aquí tienes y nada más.')
      expect(signed_ids.size).to eq(1)
    end

    it 'returns the signed_id of the existing blob (reuses storage)' do
      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:catalogo')
      expect(signed_ids.first).to eq(attachment.file.blob.signed_id)
    end

    it 'ignores unknown directives without breaking the rest' do
      content = 'Mira @adjunto:catalogo pero no @adjunto:inexistente.'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(signed_ids.size).to eq(1)
      expect(clean).to eq('Mira pero no.')
    end

    it 'is case-insensitive when resolving the name' do
      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:CATALOGO')
      expect(signed_ids.size).to eq(1)
    end

    it 'resolves the name and strips a trailing extension the IA may append' do
      content = 'Te envío la ficha. @adjunto:catalogo.svg'
      clean, signed_ids = job.send(:resolve_attachment_directives, tracking, content)

      expect(signed_ids.size).to eq(1)
      expect(clean).to eq('Te envío la ficha.')
    end

    it 'returns the content unchanged when the agent has no template' do
      orphan = ContactTracking.new(account: account, tracking_template: nil)
      clean, signed_ids = job.send(:resolve_attachment_directives, orphan, 'texto @adjunto:catalogo')

      expect(clean).to eq('texto @adjunto:catalogo')
      expect(signed_ids).to be_empty
    end

    it 'caps the number of attachments at MAX_DIRECTIVE_ATTACHMENTS' do
      stub_const("#{described_class}::MAX_DIRECTIVE_ATTACHMENTS", 1)
      create(:ai_agent_attachment, tracking_template: tracking_template, account: account, name: 'precios')

      _clean, signed_ids = job.send(:resolve_attachment_directives, tracking, '@adjunto:catalogo @adjunto:precios')
      expect(signed_ids.size).to eq(1)
    end
  end

  describe '#confirm_and_create_appointment' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, message_type: :incoming)
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender producto', scheduled_for: 1.hour.from_now,
        status: 'scheduled', tracking_template_id: tracking_template.id,
        ai_context: '[PENDING_SLOT] Esperando elección.'
      )
    end
    let(:selected_slot) do
      {
        'slot' => 1.day.from_now.change(hour: 15).utc.iso8601,
        'end_time' => 1.day.from_now.change(hour: 15, min: 30).utc.iso8601,
        'agent_name' => 'Ana',
        'cal_id' => 123
      }
    end

    before do
      allow(job).to receive(:create_private_note)
      allow(job).to receive(:notify_admin_interested)
      allow(tracking).to receive(:pause!).and_return(true)
      allow(UserCalendarIntegration).to receive(:find_by).and_return(instance_double(UserCalendarIntegration))
    end

    context 'cuando el evento se crea en el calendario' do
      before do
        allow(GoogleCalendarService).to receive(:new).and_return(double(create_event: { 'id' => 'evt_abc123' }))
      end

      it 'confirma la cita al cliente y marca el outcome appointment' do
        expect(job).to receive(:send_auto_reply) do |_t, _m, reply|
          expect(reply).to include('agendada')
        end
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
        expect(tracking.reload.outcome).to eq('appointment')
        expect(tracking.appointment_at).to be_present
      end

      it 'guarda la referencia del evento para poder moverlo/cancelarlo' do
        allow(job).to receive(:send_auto_reply)
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
        expect(tracking.reload.appointment_event_id).to eq('evt_abc123')
        expect(tracking.appointment_calendar_id).to eq(123)
      end
    end

    context 'cuando el seguimiento ya tenía una cita en la misma agenda' do
      let(:calendar_service) { instance_double(GoogleCalendarService) }

      before do
        tracking.update!(appointment_event_id: 'evt_old', appointment_calendar_id: 123)
        allow(GoogleCalendarService).to receive(:new).and_return(calendar_service)
        allow(calendar_service).to receive(:update_event).and_return('id' => 'evt_old')
        allow(calendar_service).to receive(:create_event)
        allow(job).to receive(:send_auto_reply)
      end

      it 'mueve el evento existente en vez de crear uno nuevo' do
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
        expect(calendar_service).to have_received(:update_event).with('evt_old', any_args)
        expect(calendar_service).not_to have_received(:create_event)
      end

      it 'conserva el mismo appointment_event_id' do
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
        expect(tracking.reload.appointment_event_id).to eq('evt_old')
      end
    end

    context 'cuando el evento NO se puede crear (calendario desconfigurado)' do
      before do
        failing = instance_double(GoogleCalendarService)
        allow(failing).to receive(:create_event).and_raise(StandardError, 'calendar gone')
        allow(GoogleCalendarService).to receive(:new).and_return(failing)
      end

      it 'NO confirma la cita al cliente y le avisa que un asesor confirmará' do
        expect(job).to receive(:send_auto_reply) do |_t, _m, reply|
          expect(reply).not_to include('agendada')
          expect(reply).to include('asesor')
        end
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
      end

      it 'no marca el seguimiento como appointment (no contamina el KPI)' do
        allow(job).to receive(:send_auto_reply)
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
        expect(tracking.reload.outcome).not_to eq('appointment')
        expect(tracking.appointment_at).to be_nil
      end

      it 'deja una nota privada que requiere atención humana' do
        allow(job).to receive(:send_auto_reply)
        expect(job).to receive(:create_private_note).with(tracking, message, /atención humana/i)
        job.send(:confirm_and_create_appointment, tracking, message, selected_slot)
      end
    end
  end

  describe '#handle_cancel_appointment' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, message_type: :incoming)
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender producto', scheduled_for: 1.hour.from_now,
        status: 'paused', tracking_template_id: tracking_template.id
      )
    end
    let(:calendar_service) { instance_double(GoogleCalendarService) }

    before do
      allow(job).to receive(:create_private_note)
      allow(job).to receive(:notify_admin_interested)
      allow(job).to receive(:send_auto_reply)
    end

    context 'cuando hay una cita activa' do
      before do
        tracking.update!(appointment_at: 1.day.from_now, appointment_event_id: 'evt_1',
                         appointment_calendar_id: 123, outcome: 'appointment')
        allow(UserCalendarIntegration).to receive(:find_by).and_return(instance_double(UserCalendarIntegration))
        allow(GoogleCalendarService).to receive(:new).and_return(calendar_service)
        allow(calendar_service).to receive(:delete_event).and_return(true)
      end

      it 'borra el evento del calendario' do
        job.send(:handle_cancel_appointment, tracking, message)
        expect(calendar_service).to have_received(:delete_event).with('evt_1')
      end

      it 'limpia los campos de cita y marca el outcome cancelled' do
        job.send(:handle_cancel_appointment, tracking, message)
        tracking.reload
        expect(tracking.appointment_event_id).to be_nil
        expect(tracking.appointment_calendar_id).to be_nil
        expect(tracking.appointment_at).to be_nil
        expect(tracking.outcome).to eq('cancelled')
      end

      it 'avisa al cliente que la cita fue cancelada' do
        expect(job).to receive(:send_auto_reply).with(tracking, message, /cancel/i)
        job.send(:handle_cancel_appointment, tracking, message)
      end
    end

    context 'cuando NO hay una cita activa' do
      it 'lo trata como un rechazo y no intenta borrar nada del calendario' do
        expect(job).to receive(:handle_rejected).with(tracking, message, anything)
        expect(GoogleCalendarService).not_to receive(:new)
        job.send(:handle_cancel_appointment, tracking, message)
      end
    end
  end

  describe '#appointment_timezone' do
    let(:inbox) { create(:inbox, account: account, timezone: 'America/New_York') }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact, message_type: :incoming)
    end
    let(:tracking) { ContactTracking.new(account: account, tracking_template: tracking_template, inbox: inbox) }

    it 'usa la zona horaria del Agente IA cuando está definida' do
      tracking_template.update!(timezone: 'America/Mexico_City')
      expect(job.send(:appointment_timezone, tracking, message)).to eq('America/Mexico_City')
    end

    it 'cae a la zona del inbox cuando el Agente IA no tiene zona' do
      tracking_template.update!(timezone: nil)
      expect(job.send(:appointment_timezone, tracking, message)).to eq('America/New_York')
    end

    it 'usa el default cuando no hay zona ni en el agente ni en el inbox' do
      expect(job.send(:appointment_timezone, nil, nil)).to eq('America/Mexico_City')
    end
  end

  describe 'email opcional del invitado al agendar' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: content)
    end
    let(:slot) do
      {
        'slot' => 1.day.from_now.change(hour: 15).utc.iso8601,
        'end_time' => 1.day.from_now.change(hour: 15, min: 30).utc.iso8601,
        'agent_name' => 'Ana', 'cal_id' => 123
      }
    end

    before { allow(job).to receive(:send_auto_reply) }

    describe '#handle_slot_selection con el slot ya elegido' do
      let(:content) { '1' }
      let(:tracking) do
        ContactTracking.create!(
          account: account, contact: contact, inbox: inbox,
          objective: 'Vender', scheduled_for: 1.hour.from_now,
          status: 'active', tracking_template_id: tracking_template.id,
          ai_context: "📅 [PENDING_SLOT] Esperando elección.\nSlots ofrecidos: #{[slot].to_json}"
        )
      end

      context 'cuando el contacto NO tiene email' do
        let(:contact) { create(:contact, account: account, email: nil) }

        it 'no confirma todavía: pide el email y deja el estado PENDING_EMAIL' do
          expect(job).not_to receive(:confirm_and_create_appointment)
          job.send(:handle_slot_selection, tracking, message)
          expect(tracking.reload.ai_context).to include('[PENDING_EMAIL]')
        end
      end

      context 'cuando el contacto YA tiene email' do
        let(:contact) { create(:contact, account: account, email: 'ya@mail.com') }

        it 'confirma directo sin pedir email' do
          expect(job).to receive(:confirm_and_create_appointment).with(tracking, message, hash_including('cal_id' => 123))
          job.send(:handle_slot_selection, tracking, message)
        end
      end
    end

    describe '#handle_pending_email' do
      let(:contact) { create(:contact, account: account, email: nil) }
      let(:tracking) do
        ContactTracking.create!(
          account: account, contact: contact, inbox: inbox,
          objective: 'Vender', scheduled_for: 1.hour.from_now,
          status: 'active', tracking_template_id: tracking_template.id,
          ai_context: "📧 [PENDING_EMAIL] Esperando email para la cita.\nCita elegida: #{slot.to_json}"
        )
      end

      before { allow(job).to receive(:confirm_and_create_appointment) }

      context 'cuando el cliente envía un email válido' do
        let(:content) { 'mi correo es ana@mail.com, gracias' }

        it 'guarda el email en el contacto y confirma la cita' do
          job.send(:handle_pending_email, tracking, message)
          expect(contact.reload.email).to eq('ana@mail.com')
          expect(job).to have_received(:confirm_and_create_appointment).with(tracking, message, hash_including('cal_id' => 123))
        end
      end

      context 'cuando el cliente omite el email' do
        let(:content) { 'sin correo' }

        it 'no guarda email pero agenda igual' do
          job.send(:handle_pending_email, tracking, message)
          expect(contact.reload.email).to be_blank
          expect(job).to have_received(:confirm_and_create_appointment)
        end
      end

      context 'cuando la respuesta no es un email ni un "sin correo"' do
        let(:content) { 'y a qué hora exactamente?' }

        it 'repregunta y mantiene el estado sin confirmar' do
          job.send(:handle_pending_email, tracking, message)
          expect(job).not_to have_received(:confirm_and_create_appointment)
          expect(tracking.reload.ai_context).to include('[PENDING_EMAIL]')
        end
      end
    end
  end
end
