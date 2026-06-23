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

  describe '#classify_appointment (appointment-aware, no eager)' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'quiero una cita')
    end
    let(:tracking) { ContactTracking.new(account: account, tracking_template: tracking_template, inbox: inbox) }

    before { allow(job).to receive(:get_api_key).and_return({ key: 'sk-test' }) }

    context 'cuando ya hay route_result con appointment_action (DETECT_INTENT activo)' do
      it 'reutiliza el route_result y NO vuelve a clasificar' do
        route_result = { route: :tracking, appointment_action: nil }
        expect(ContactTrackings::RouterService).not_to receive(:new)
        expect(job.send(:classify_appointment, tracking, message, route_result)).to eq(route_result)
      end
    end

    context 'cuando el route_result no trae appointment_action (DETECT_INTENT apagado)' do
      it 'clasifica pasando el estado de la cita al router' do
        disabled = { route: :tracking, confidence: 1.0, method: 'disabled' }
        expect(ContactTrackings::RouterService).to receive(:new)
          .with(tracking, message, 'sk-test', hash_including(:appointment_state))
          .and_return(double(classify: { route: :book_appointment, appointment_action: :book_new }))
        result = job.send(:classify_appointment, tracking, message, disabled)
        expect(result[:appointment_action]).to eq(:book_new)
      end

      it 'no es eager: appointment_action nil en un mensaje normal' do
        allow(ContactTrackings::RouterService).to receive(:new)
          .and_return(double(classify: { route: :tracking, appointment_action: nil }))
        result = job.send(:classify_appointment, tracking, message, nil)
        expect(result[:appointment_action]).to be_nil
      end
    end
  end

  describe '#dispatch_appointment_action' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'sobre mi cita')
    end

    context 'con una cita activa' do
      let(:tracking) do
        ContactTracking.create!(
          account: account, contact: contact, inbox: inbox, objective: 'Vender',
          scheduled_for: 1.hour.from_now, status: 'active', tracking_template_id: tracking_template.id,
          appointment_at: 1.day.from_now, appointment_event_id: 'evt_1', appointment_calendar_id: 123
        )
      end

      it ':query recuerda la cita existente (no re-ofrece)' do
        expect(job).to receive(:inform_existing_appointment).with(tracking, message)
        expect(job).not_to receive(:handle_book_appointment)
        job.send(:dispatch_appointment_action, tracking, message, { appointment_action: :query })
      end

      it ':move enruta a reagendar (mover la cita) pasando el payload' do
        appt = { appointment_action: :move, reschedule_data: { specific_date: '2026-06-16' } }
        expect(job).to receive(:handle_reschedule).with(tracking, message, appt)
        job.send(:dispatch_appointment_action, tracking, message, appt)
      end

      it ':cancel cancela la cita' do
        expect(job).to receive(:handle_cancel_appointment).with(tracking, message)
        job.send(:dispatch_appointment_action, tracking, message, { appointment_action: :cancel })
      end
    end

    context 'sin cita activa' do
      let(:tracking) do
        ContactTracking.create!(
          account: account, contact: contact, inbox: inbox, objective: 'Vender',
          scheduled_for: 1.hour.from_now, status: 'active', tracking_template_id: tracking_template.id
        )
      end

      it ':query degrada a ofrecer agendar una nueva' do
        expect(job).to receive(:handle_book_appointment).with(tracking, message)
        job.send(:dispatch_appointment_action, tracking, message, { appointment_action: :query })
      end

      it ':book_new ofrece agendar' do
        expect(job).to receive(:handle_book_appointment).with(tracking, message)
        job.send(:dispatch_appointment_action, tracking, message, { appointment_action: :book_new })
      end
    end
  end

  describe '#appointment_state_summary' do
    let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City') }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'hola')
    end

    it 'describe la cita cuando existe' do
      tracking = ContactTracking.create!(
        account: account, contact: contact, inbox: inbox, objective: 'Vender',
        scheduled_for: 1.hour.from_now, status: 'active', tracking_template_id: tracking_template.id,
        appointment_at: Time.find_zone('America/Mexico_City').local(2026, 6, 15, 9, 0),
        appointment_event_id: 'evt_1', appointment_calendar_id: 123
      )
      expect(job.send(:appointment_state_summary, tracking, message)).to match(/YA tiene.*lunes 15 de junio a las 09:00/)
    end

    it 'indica que no hay cita cuando no existe' do
      tracking = ContactTracking.create!(
        account: account, contact: contact, inbox: inbox, objective: 'Vender',
        scheduled_for: 1.hour.from_now, status: 'active', tracking_template_id: tracking_template.id
      )
      expect(job.send(:appointment_state_summary, tracking, message)).to match(/NO tiene ninguna cita/)
    end
  end

  describe '#handle_book_appointment sin calendarios vinculados' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'quiero una cita')
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender', scheduled_for: 1.hour.from_now, status: 'active',
        tracking_template_id: tracking_template.id
      )
    end

    before do
      tracking_template.update!(calendar_integration_ids: [])
      allow(job).to receive(:notify_admin_interested)
      allow(job).to receive(:create_private_note)
    end

    it 'no busca slots y envía un mensaje específico (no el genérico de interés)' do
      expect(ContactTrackings::AvailabilitySlotService).not_to receive(:new)
      expect(job).to receive(:send_auto_reply).with(tracking, message, /no puedo confirmar el horario de forma automática/i)
      job.send(:handle_book_appointment, tracking, message)
    end

    it 'escala a un humano y pausa el seguimiento' do
      allow(job).to receive(:send_auto_reply)
      expect(job).to receive(:notify_admin_interested).with(tracking, message)
      expect(job).to receive(:create_private_note).with(tracking, message, /atención humana/i)
      job.send(:handle_book_appointment, tracking, message)
      expect(tracking.reload.outcome).to eq('interested')
      expect(tracking.status).to eq('paused')
    end
  end

  describe '#handle_book_appointment cuando el contacto YA tiene una cita activa' do
    let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City') }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: '¿cuándo es mi cita?')
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender', scheduled_for: 1.hour.from_now, status: 'active',
        tracking_template_id: tracking_template.id,
        appointment_at: Time.zone.parse('2026-06-15 09:00').in_time_zone('America/Mexico_City'),
        appointment_event_id: 'evt_existente', appointment_calendar_id: 123, outcome: 'appointment'
      )
    end

    before do
      tracking_template.update!(calendar_integration_ids: [123])
      allow(job).to receive(:send_auto_reply)
    end

    it 'NO vuelve a ofrecer slots nuevos' do
      expect(ContactTrackings::AvailabilitySlotService).not_to receive(:new)
      job.send(:handle_book_appointment, tracking, message)
    end

    it 'le recuerda al cliente la cita existente y le ofrece moverla o cancelarla' do
      expect(job).to receive(:send_auto_reply)
        .with(tracking, message, /ya tenés una cita agendada para el .*moverla.*cancelarla/im)
      job.send(:handle_book_appointment, tracking, message)
    end

    it 'no toca el outcome ni los datos de la cita existente' do
      job.send(:handle_book_appointment, tracking, message)
      expect(tracking.reload.outcome).to eq('appointment')
      expect(tracking.appointment_event_id).to eq('evt_existente')
    end
  end

  describe '#handle_reschedule con cita activa enruta a mover la cita (no el recordatorio)' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'quiero mover mi cita')
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender', scheduled_for: 1.hour.from_now, status: 'active',
        tracking_template_id: tracking_template.id,
        appointment_at: 1.day.from_now, appointment_event_id: 'evt_1', appointment_calendar_id: 123
      )
    end

    it 'con appointment_event_id presente llama a handle_move_appointment' do
      action_data = { route: :reschedule, reschedule_data: { specific_date: '2026-06-16' } }
      expect(job).to receive(:handle_move_appointment).with(tracking, message, action_data)
      expect(job).not_to receive(:handle_followup_reschedule)
      job.send(:handle_reschedule, tracking, message, action_data)
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

      context 'cuando propone una hora (un dígito dentro de una frase de fecha/hora)' do
        let(:contact) { create(:contact, account: account, email: 'ya@mail.com') }
        let(:content) { 'a la 1 de la tarde' }

        it 'no elige el slot 1: deriva a la negociación' do
          expect(job).to receive(:handle_slot_negotiation).with(tracking, message, anything)
          expect(job).not_to receive(:confirm_and_create_appointment)
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

  describe '#handle_slot_negotiation' do
    let(:inbox) { create(:inbox, account: account, timezone: 'America/Mexico_City') }
    let(:contact) { create(:contact, account: account, email: 'cli@mail.com') }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'mejor el jueves a las 5')
    end
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox,
        objective: 'Vender', scheduled_for: 1.hour.from_now, status: 'active',
        tracking_template_id: tracking_template.id,
        ai_context: "📅 [PENDING_SLOT] Esperando.\nSlots ofrecidos: [{}]"
      )
    end
    let(:current_slots) { [{ 'slot' => 'x', 'cal_id' => 1 }] }
    let(:slot_service) { instance_double(ContactTrackings::AvailabilitySlotService) }

    def slot_hash(hour)
      {
        slot: 2.days.from_now.change(hour: hour, min: 0),
        end_time: 2.days.from_now.change(hour: hour + 1, min: 0),
        agent_name: 'Ana', calendar_integration_id: 123
      }
    end

    before do
      tracking_template.update!(calendar_integration_ids: [123])
      allow(ContactTrackings::AvailabilitySlotService).to receive(:new).and_return(slot_service)
      allow(job).to receive(:send_auto_reply)
    end

    context 'cuando propone una hora exacta disponible' do
      before do
        allow(job).to receive(:parse_requested_datetime).and_return({ at: 1.day.from_now.change(hour: 17), exact: true })
        allow(slot_service).to receive(:slot_for).and_return(slot_hash(17))
        allow(job).to receive(:confirm_and_create_appointment)
      end

      it 'confirma ese horario' do
        expect(job).to receive(:confirm_and_create_appointment).with(tracking, message, hash_including('cal_id' => 123))
        job.send(:handle_slot_negotiation, tracking, message, current_slots)
      end
    end

    context 'cuando la hora exacta está ocupada' do
      before do
        allow(job).to receive(:parse_requested_datetime).and_return({ at: 1.day.from_now.change(hour: 17), exact: true })
        allow(slot_service).to receive(:slot_for).and_return(nil)
        allow(slot_service).to receive(:call).and_return([slot_hash(9)])
      end

      it 'avisa que no está disponible y vuelve a dejar PENDING_SLOT' do
        expect(job).to receive(:send_auto_reply).with(tracking, message, /no está disponible/i)
        job.send(:handle_slot_negotiation, tracking, message, current_slots)
        expect(tracking.reload.ai_context).to include('[PENDING_SLOT]')
      end
    end

    context 'cuando solo da el día (sin hora)' do
      before do
        allow(job).to receive(:parse_requested_datetime).and_return({ at: 2.days.from_now.change(hour: 10), exact: false })
        allow(slot_service).to receive(:call).and_return([slot_hash(9)])
      end

      it 'ofrece los horarios de ese día sin chequear una hora exacta' do
        expect(slot_service).not_to receive(:slot_for)
        expect(job).to receive(:send_auto_reply).with(tracking, message, /Para ese día/i)
        job.send(:handle_slot_negotiation, tracking, message, current_slots)
      end
    end

    context 'cuando no se puede interpretar la fecha' do
      before { allow(job).to receive(:parse_requested_datetime).and_return(nil) }

      it 'repregunta de forma suave manteniendo el estado' do
        expect(job).to receive(:send_auto_reply).with(tracking, message, /qué día y a qué hora/i)
        job.send(:handle_slot_negotiation, tracking, message, current_slots)
      end
    end
  end

  # Reproduce el bug de la conversación #35: jueves → "mañana" apilaba un segundo
  # [PENDING_SLOT] sin limpiar el viejo, y la limpieza no borraba bloques adyacentes,
  # con lo que se elegía/agendaba el día equivocado.
  describe 'estado de cita en ai_context (anti-apilado)' do
    let(:contact) { create(:contact, account: account) }
    let(:inbox)   { create(:inbox, account: account) }
    let(:persisted_tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox, tracking_template_id: tracking_template.id,
        objective: 'Agendar cita de prueba', scheduled_for: 1.day.from_now,
        status: 'active', max_attempts: 3, attempt_count: 0, ai_context: 'BASE'
      )
    end

    before { allow(job).to receive(:send_auto_reply) }

    def slot(time_str, cal_id: 7)
      t = Time.zone.parse(time_str)
      { slot: t, end_time: t + 30.minutes, agent_name: 'Admin', calendar_integration_id: cal_id }
    end

    def offered_slots(tracking)
      json = tracking.reload.ai_context.to_s.scan(/Slots ofrecidos: (\[.*?\])/m).flatten.last
      json ? JSON.parse(json) : []
    end

    it 'mantiene un solo PENDING_SLOT al re-ofrecer (negociación jueves → mañana)' do
      job.send(:offer_slots, persisted_tracking, nil, [slot('2026-06-18 13:00')], 'jueves')
      job.send(:offer_slots, persisted_tracking, nil, [slot('2026-06-19 09:00')], 'viernes')

      ctx = persisted_tracking.reload.ai_context
      expect(ctx.scan(/\[PENDING_SLOT\]/).size).to eq(1)
      # el bloque vigente es el del viernes (el último ofrecido), no el del jueves
      expect(offered_slots(persisted_tracking).first['slot']).to eq(slot('2026-06-19 09:00')[:slot].utc.iso8601)
    end

    it 'clear_pending_slot borra TODOS los bloques, incluso adyacentes' do
      persisted_tracking.update!(
        ai_context: "BASE\n\n📅 [PENDING_SLOT] Esperando elección de horario.\nSlots ofrecidos: [{\"slot\":\"A\"}]" \
                    "\n\n📅 [PENDING_SLOT] Esperando elección de horario.\nSlots ofrecidos: [{\"slot\":\"B\"}]"
      )
      job.send(:clear_pending_slot, persisted_tracking)
      expect(persisted_tracking.reload.ai_context.scan(/\[PENDING_SLOT\]/).size).to eq(0)
    end

    it 'clear_pending_email borra TODOS los bloques, incluso adyacentes' do
      persisted_tracking.update!(
        ai_context: "BASE\n\n📧 [PENDING_EMAIL] Esperando email para la cita.\nCita elegida: {\"slot\":\"A\"}" \
                    "\n\n📧 [PENDING_EMAIL] Esperando email para la cita.\nCita elegida: {\"slot\":\"B\"}"
      )
      job.send(:clear_pending_email, persisted_tracking)
      expect(persisted_tracking.reload.ai_context.scan(/\[PENDING_EMAIL\]/).size).to eq(0)
    end

    it 'al pasar a PENDING_EMAIL no quedan PENDING_SLOT vivos' do
      job.send(:offer_slots, persisted_tracking, nil, [slot('2026-06-19 09:00')], 'viernes')
      job.send(:prompt_for_email, persisted_tracking, nil, { 'slot' => '2026-06-19T15:00:00Z' })

      ctx = persisted_tracking.reload.ai_context
      expect(ctx.scan(/\[PENDING_SLOT\]/).size).to eq(0)
      expect(ctx.scan(/\[PENDING_EMAIL\]/).size).to eq(1)
    end
  end

  # Reproduce la conversación #35: con una cita ya agendada, "para la próxima semana el
  # mismo día a la misma hora" se clasificaba :reschedule y movía solo el recordatorio
  # (scheduled_for), dejando la cita del calendario sin tocar pero diciendo "tu cita fue
  # agendada…". Ahora reagendar con cita activa MUEVE la cita en el calendario.
  describe '#handle_reschedule con cita activa (mueve la cita, no el recordatorio)' do
    let(:inbox)   { create(:inbox, account: account, timezone: 'America/Mexico_City') }
    let(:contact) { create(:contact, account: account, email: 'cli@mail.com') }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
    let(:message) do
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       sender: contact, message_type: :incoming, content: 'cámbiala para el 25 a las 10:30')
    end
    let(:slot_service) { instance_double(ContactTrackings::AvailabilitySlotService) }
    let(:tracking) do
      ContactTracking.create!(
        account: account, contact: contact, inbox: inbox, tracking_template_id: tracking_template.id,
        objective: 'Vender', scheduled_for: 1.hour.from_now, status: 'paused',
        max_attempts: 3, attempt_count: 0,
        appointment_at: Time.zone.parse('2026-06-19 16:30'), appointment_event_id: 'evt_1',
        appointment_calendar_id: 7, outcome: 'appointment'
      )
    end

    before do
      tracking_template.update!(calendar_integration_ids: [7])
      allow(ContactTrackings::AvailabilitySlotService).to receive(:new).and_return(slot_service)
      allow(job).to receive(:send_auto_reply)
    end

    def move_slot(time_str)
      t = Time.zone.parse(time_str)
      { slot: t, end_time: t + 30.minutes, agent_name: 'Admin', calendar_integration_id: 7 }
    end

    it 'mueve la cita al horario pedido cuando está disponible (no toca el recordatorio)' do
      allow(slot_service).to receive(:slot_for).and_return(move_slot('2026-06-25 16:30'))
      expect(job).not_to receive(:handle_followup_reschedule)
      expect(job).to receive(:confirm_and_create_appointment).with(tracking, message, hash_including('cal_id' => 7))
      job.send(:handle_reschedule, tracking, message, { reschedule_data: { specific_date: '2026-06-25', specific_time: '10:30' } })
    end

    it 'ofrece horarios cuando la hora pedida está ocupada' do
      allow(slot_service).to receive(:slot_for).and_return(nil)
      allow(slot_service).to receive(:call).and_return([move_slot('2026-06-25 17:00')])
      expect(job).to receive(:offer_slots).with(tracking, message, anything, /no está disponible/i)
      job.send(:handle_reschedule, tracking, message, { reschedule_data: { specific_date: '2026-06-25', specific_time: '10:30' } })
    end

    it 'sin cita activa, reagenda el recordatorio (comportamiento original)' do
      tracking.update!(appointment_event_id: nil, appointment_calendar_id: nil, appointment_at: nil, outcome: nil)
      expect(job).to receive(:handle_followup_reschedule).with(tracking, message, anything)
      job.send(:handle_reschedule, tracking, message, { reschedule_data: { relative_days: 2 } })
    end

    it 'conserva la hora de la cita actual cuando el cliente solo da el día' do
      target = job.send(:move_target_time, tracking, { relative_days: 7 }, 'America/Mexico_City')
      expect(target.in_time_zone('America/Mexico_City').strftime('%H:%M')).to eq('10:30')
    end
  end
end
