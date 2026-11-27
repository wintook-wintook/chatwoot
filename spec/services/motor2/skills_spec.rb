# frozen_string_literal: true

require 'rails_helper'

# Motor 2.0 — las habilidades de M2: ofertas escalonadas, archivos, casos y citas. Se prueban
# llamando sus herramientas como lo haría el modelo.
RSpec.describe Motor2::Skills do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:motor2) { {} }
  let(:template) { create(:tracking_template, account: account, inbox_id: inbox.id, engine: '2', motor2: motor2) }
  let(:tracking) do
    create(:contact_tracking, account: account, contact: contact, inbox: inbox, conversation: conversation, tracking_template: template)
  end
  let(:state) { Motor2::State.new }
  let(:runner) { Motor2::Runner.new(Motor2::Config.new(template), state: state, conversation: conversation, tracking: tracking) }

  def tool(name, args = {}) = runner.send(:tool, name, args.stringify_keys)

  before do
    create(:user, account: account, role: :administrator)
    runner.instance_variable_set(:@skills, described_class.for(runner))
  end

  describe 'qué sabe' do
    it 'las respuestas predefinidas van siempre, sin marcarlas en la ficha' do
      create(:canned_response, account: account, short_code: 'horario', content: 'Abrimos de 9 a 18')
      expect(Motor2::Search.new(account, []).names).to eq(['Respuestas predefinidas'])
      expect(Motor2::Search.new(account, %w[canned_response]).names).to eq(['Respuestas predefinidas'])
    end

    it 'un agente marcado «sin predefinidas» no las consulta (y los demás sí)' do
      create(:canned_response, account: account, short_code: 'horario', content: 'Abrimos de 9 a 18')
      expect(Motor2::Search.new(account, [Motor2::Search::NO_CANNED]).names).to eq([])
      expect(Motor2::Search.new(account, %w[catalog]).ordered_keys).to include('canned_response')
    end
  end

  describe 'ofertas escalonadas' do
    let(:motor2) do
      { 'skills' => { 'offers' => { 'on' => true, 'steps' => [{ 'text' => 'Beca de 20%: $3,360' }, { 'text' => 'Beca de 35%: $2,730' }] } } }
    end

    it 'da una sola oferta por mensaje y avanza el escalón en la memoria' do
      expect(tool('siguiente_oferta', objecion: 'está caro')).to include(escalon: 1, oferta: 'Beca de 20%: $3,360')
      expect(tool('siguiente_oferta', objecion: 'sigue caro')[:error]).to include('Ya diste una oferta')
      expect(state['offer_step']).to eq(1)
    end

    it 'el modelo no ve los escalones que siguen; en el siguiente turno da el 2 y después ya no hay más' do
      tool('siguiente_oferta', objecion: 'caro')
      next_turn = Motor2::Runner.new(Motor2::Config.new(template), state: state, conversation: conversation, tracking: tracking)
      next_turn.instance_variable_set(:@skills, described_class.for(next_turn))
      prompt = Motor2::Prompt.new(next_turn, described_class.for(next_turn)).system
      expect(prompt).to include('Beca de 20%')
      expect(prompt).not_to include('35%')
      expect(next_turn.send(:tool, 'siguiente_oferta', { 'objecion' => 'caro' })).to include(escalon: 2)
      expect(next_turn.send(:tool, 'siguiente_oferta', { 'objecion' => 'caro' })[:error]).to be_present
    end

    it 'cuando se acaban dice que no invente otra' do
      state['offer_step'] = 2
      expect(tool('siguiente_oferta', objecion: 'caro')).to include(fin: true)
    end
  end

  describe 'archivos' do
    let!(:brochure) { create(:ai_agent_attachment, tracking_template: template, name: 'brochure') }

    before do
      template.update!(resources: { 'files' => { 'brochure' => { 'ask' => true } } })
      runner.instance_variable_set(:@skills, described_class.for(runner))
    end

    it 'lo adjunta a la respuesta y no lo repite si ya se mandó' do
      expect(tool('enviar_archivo', nombre: 'brochure')).to include(ok: true)
      expect(runner.instance_variable_get(:@attachments).pluck(:id)).to eq([brochure.id])

      state.files_sent << brochure.id
      expect(tool('enviar_archivo', nombre: 'brochure')).to include(ya_enviado: true)
      expect(tool('enviar_archivo', nombre: 'brochure', reenviar: true)).to include(ok: true)
    end
  end

  describe 'casos' do
    let(:case_type) { account.case_types.create!(name: 'Soporte técnico', case_class: 'support') }
    let(:motor2) { { 'skills' => { 'tickets' => { 'on' => true, 'types' => [{ 'case_type_id' => case_type.id, 'when' => 'reporta falla' }] } } } }

    before do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'No prende')
      runner.instance_variable_set(:@skills, described_class.for(runner))
    end

    it 'levanta el caso con su tipo y no repite uno abierto de la misma clase' do
      result = tool('crear_caso', tipo: 'Soporte técnico', titulo: 'No prende el equipo', descripcion: 'Desde ayer')
      expect(result).to include(ok: true)
      ticket = CaseTicket.find(state['case_id'])
      expect(ticket).to have_attributes(title: 'No prende el equipo', case_type_id: case_type.id, contact_tracking_id: tracking.id)

      expect(tool('crear_caso', tipo: 'Soporte técnico', titulo: 'Otra vez', descripcion: 'x')).to include(ya_existe: true)
    end
  end

  describe 'citas' do
    let(:user) { create(:user, account: account, name: 'Ana') }
    let!(:integration) { UserCalendarIntegration.create!(account: account, user: user, google_email: 'ana@x.com', tokens: {}) }
    let(:motor2) { { 'skills' => { 'appointments' => { 'on' => true, 'kind' => 'visita' } } } }
    let(:slot_at) { 2.days.from_now.change(hour: 10) }
    let(:slot) { { slot: slot_at, end_time: slot_at + 30.minutes, agent_name: 'Ana', calendar_integration_id: integration.id } }

    before do
      template.update!(calendar_integration_ids: [integration.id])
      runner.instance_variable_set(:@skills, described_class.for(runner))
    end

    it 'los días de la semana los da el código' do
      prompt = Motor2::Prompt.new(runner, described_class.for(runner)).system
      expect(prompt).to include("DÍAS: #{Motor2::Skills::Appointments::DAYS[Time.current.in_time_zone(Time.zone).wday]}")
    end

    it 'ofrece horarios libres de la agenda' do
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:call).and_return([slot]) # rubocop:disable RSpec/AnyInstance
      expect(tool('ver_horarios')[:horarios].first).to include(con: 'Ana')
    end

    it 'sin agenda legible lo pasa a una persona con el motivo' do
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive_messages(call: [], calendars_unreadable?: true, # rubocop:disable RSpec/AnyInstance
                                                                                           unreadable_users: ['Ana'])
      expect(tool('ver_horarios')[:error]).to include('No pude revisar la agenda')
      expect(runner.instance_variable_get(:@decision).first).to eq('handoff')
    end
  end

  describe 'su cuenta (cotizar)' do
    let(:motor2) do
      { 'answers' => { 'quote' => { 'mode' => 'send', 'cart' => true }, 'areas' => { 'sales' => { 'on' => true } } },
        'skills' => { 'quote' => { 'on' => true } } }
    end
    let(:test_runner) { Motor2::Runner.new(Motor2::Config.new(template), state: state, history: []) }

    def cart_tool(name, args = {}) = test_runner.send(:tool, name, args.stringify_keys)

    def iva16 = account.tax_rates.find_by(percent: 16, kind: :transfer)

    before do
      template.update_columns(agent_function: 'customers') # rubocop:disable Rails/SkipsModelValidations
      CatalogParameters.ensure!(account)
      CatalogItem.create!(account: account, name: 'Manicure gelish', kind: :service, price: 350, price_includes_tax: true, tax_rate: iva16)
      CatalogItem.create!(account: account, name: 'Mechas / balayage', kind: :service, price: 2200, price_includes_tax: true, tax_rate: iva16)
      test_runner.instance_variable_set(:@skills, described_class.for(test_runner))
    end

    it 'agrega, quita y suma el código; la cotización sale de la cuenta' do
      expect(cart_tool('agregar_a_cuenta', partidas: [{ 'producto' => 'balayage' }, { 'producto' => 'manicure', 'cantidad' => 2 }]))
        .to include(total: 2900.0, iva_incluido: true)
      result = cart_tool('quitar_de_cuenta', producto: 'manicure', cantidad: 1)
      expect(result[:texto]).to include('Mechas / balayage ×1 — $2,200', 'Manicure gelish ×1 — $350', 'IVA (16 %)', 'Total: $2,550')
      expect(cart_tool('cotizar')).to include(ok: true, prueba: true, total: 2550.0)
    end

    it 'si le ofreció agregarlo y dijo que no, ya no se lo ofrece' do
      quote = described_class.for(test_runner).find { |sk| sk.key == 'quote' }
      quote.prepare([{ role: 'assistant', content: 'Cuesta $350. ¿Te lo agrego a tu cuenta?' }, { role: 'user', content: 'no, gracias' }])
      expect(state['cart_declined']).to be(true)
      expect(quote.instructions).to include('no se lo vuelvas a ofrecer')
    end
  end

  describe 'saludo y nombre' do
    it 'después de la bienvenida no repite «¡Hola Mario!»' do
      expect(runner.send(:greeting_only?, '¡Hola Mario!')).to be(true)
      expect(runner.send(:greeting_only?, '¡Hola Mario! El corte cuesta $200.')).to be(false)
    end

    it 'con la bienvenida: si ya pidió algo, se queda la pregunta de la respuesta (no solo la bienvenida)' do
      runner.instance_variable_set(:@welcome, '¡Hola! Soy Luz. ¿Qué se te antoja hoy?')
      runner.instance_variable_set(:@last_customer, 'hola quiero un corte de pelo')
      expect(runner.send(:with_welcome, '¿Es para dama o caballero?')).to eq("¡Hola! Soy Luz.\n\n¿Es para dama o caballero?")
      runner.instance_variable_set(:@last_customer, 'hola')
      expect(runner.send(:with_welcome, '¡Hola! ¿En qué te ayudo?')).to eq('¡Hola! Soy Luz. ¿Qué se te antoja hoy?')
    end

    it 'si se presenta, le pide guardar su nombre (no «soy cliente»)' do
      data = described_class.for(runner).find { |sk| sk.key == 'data' }
      runner.instance_variable_set(:@last_customer, 'hola soy lucía')
      expect(data.turn_note).to include('«lucía»', 'actualizar_contacto')
      runner.instance_variable_set(:@last_customer, 'soy cliente de ustedes')
      expect(data.turn_note).to eq('')
    end
  end

  describe 'objetivo (agendar la cita)' do
    let(:motor2) { { 'skills' => { 'goal' => { 'on' => true, 'goal' => 'appointment', 'mode' => 'active' } } } }
    let(:goal) { described_class.for(runner).find { |sk| sk.key == 'goal' } }

    it 'cierra el mensaje de información con la invitación y la deja pendiente' do
      expect(goal.polish('El corte cuesta $200.')).to eq("El corte cuesta $200.\n\n¿Te busco un horario?")
      expect(goal.polish('El corte cuesta $200. ¿Te aparto lugar?')).to eq('El corte cuesta $200. ¿Te aparto lugar?')
      expect(goal.labels).to eq(['objetivo-pendiente'])
    end

    it 'si le invitó y dijo que no, ya no lo vuelve a invitar' do
      goal.prepare([{ role: 'assistant', content: 'Cuesta $200. ¿Te busco un horario?' }, { role: 'user', content: 'no, ahorita no' }])
      expect(state['goal_declined']).to be(true)
      expect(goal.polish('El manicure cuesta $350.')).to eq('El manicure cuesta $350.')
      expect(goal.turn_note).to include('no lo vuelvas a invitar')
    end

    it 'un «no» a otra cosa no cuenta como que no quiere la cita' do
      goal.prepare([{ role: 'assistant', content: '¿Algo más?' }, { role: 'user', content: 'no' }])
      expect(state['goal_declined']).to be_nil
    end

    it 'con la cita agendada ya no invita y la plática queda como lograda' do
      meeting = instance_double(CaseMeeting, id: 1)
      state['appointments'] = [{ 'meeting_id' => meeting.id }]
      allow(CaseMeeting).to receive(:exists?).with(id: [1], status: :scheduled).and_return(true)
      expect(goal.polish('Listo.')).to eq('Listo.')
      expect(goal.labels).to eq(['objetivo-logrado'])
    end

    it 'en la conversación, «objetivo-logrado» quita «objetivo-pendiente»' do
      expect(Motor2::Labels.merged(%w[informacion objetivo-pendiente], %w[objetivo-logrado])).to eq(%w[informacion objetivo-logrado])
      expect(Motor2::Labels.merged(%w[objetivo-logrado], %w[objetivo-pendiente])).to eq(%w[objetivo-logrado])
    end
  end

  describe 'citas de servicio' do
    let(:ana) { create(:user, account: account, name: 'Ana López') }
    let(:karla) { create(:user, account: account, name: 'Karla Ruiz') }
    let!(:karla_cal) { UserCalendarIntegration.create!(account: account, user: karla, google_email: 'karla@x.com', tokens: {}) }
    let(:motor2) do
      { 'skills' => { 'appointments' => { 'on' => true, 'kind' => 'oficina', 'services' => true, 'user_ids' => [ana.id, karla.id] } } }
    end
    let(:slot_at) { 2.days.from_now.change(hour: 10) }
    let(:built) { [] }

    before do
      UserCalendarIntegration.create!(account: account, user: ana, google_email: 'ana@x.com', tokens: {})
      CatalogItem.create!(account: account, name: 'Corte de dama', kind: :service, price: 350, duration_minutes: 45)
      CatalogItem.create!(account: account, name: 'Tinte completo', kind: :service, price: 1100, duration_minutes: 120)
      runner.instance_variable_set(:@skills, described_class.for(runner))
      allow(ContactTrackings::AvailabilitySlotService).to receive(:new).and_wrap_original do |original, **kwargs|
        built << kwargs
        original.call(**kwargs).tap do |svc|
          allow(svc).to receive(:call).and_return([{ slot: slot_at, end_time: slot_at + kwargs[:slot_duration].minutes,
                                                     agent_name: 'Karla Ruiz', calendar_integration_id: kwargs[:calendar_integration_ids].first }])
        end
      end
    end

    it 'sin servicio pide cuál antes de ver horarios' do
      expect(tool('ver_horarios')[:error]).to include('qué servicio quiere')
    end

    it 'la cita dura la suma de los servicios y busca solo en la agenda de quien pidió' do
      result = tool('ver_horarios', servicios: ['Corte de dama', 'Tinte completo'], con: 'karla')
      expect(result).to include(duracion_minutos: 165, total: 1450.0)
      expect(result[:servicios]).to eq([{ nombre: 'Corte de dama', precio: 350.0, minutos: 45 },
                                        { nombre: 'Tinte completo', precio: 1100.0, minutos: 120 }])
      expect(built.last).to include(slot_duration: 165, calendar_integration_ids: [karla_cal.id])
    end

    it 'varias citas en la plática (también para otra persona) y cancela la que dice' do
      allow_any_instance_of(ContactTrackings::AvailabilitySlotService).to receive(:slot_for) do |_svc, start| # rubocop:disable RSpec/AnyInstance
        { slot: start, end_time: start + 45.minutes, agent_name: 'Karla Ruiz', calendar_integration_id: karla_cal.id }
      end
      test_runner = Motor2::Runner.new(Motor2::Config.new(template), state: state, history: [])
      test_runner.instance_variable_set(:@skills, described_class.for(test_runner))
      first = test_runner.send(:tool, 'agendar_cita', { 'inicio' => slot_at.strftime('%Y-%m-%dT%H:%M'), 'servicios' => ['Corte de dama'] })
      second = test_runner.send(:tool, 'agendar_cita', { 'inicio' => (slot_at + 1.hour).strftime('%Y-%m-%dT%H:%M'),
                                                         'servicios' => ['Corte de dama'], 'para' => 'Laura, su esposa' })
      expect(first).to include(ok: true)
      expect(first[:desglose]).to include('Corte de dama ×1 — $350', 'Total: $350')
      expect(second).to include(ok: true, para: 'Laura, su esposa')
      expect(state['appointments'].size).to eq(2)
      expect(test_runner.send(:tool, 'cancelar_cita', { 'motivo' => 'no puede' })[:error]).to include('varias citas')
      expect(test_runner.send(:tool, 'cancelar_cita', { 'motivo' => 'no puede', 'cita' => 'la de laura' })).to include(ok: true)
      expect(state['appointments'].count { |e| e['cancelled'] }).to eq(1)
    end

    it 'si contesta «10» de los horarios que se le dieron, el código ya sabe cuál' do
      tool('ver_horarios', servicios: ['Corte de dama'])
      skill = described_class.for(runner).find { |sk| sk.key == 'appointments' }
      skill.prepare([{ role: 'user', content: '10' }])
      expect(skill.turn_note).to include('ELIGIÓ EL HORARIO', slot_at.strftime('%Y-%m-%dT10:00'), 'Corte de dama')
    end

    it 'si pide con alguien que no atiende, lo dice' do
      expect(tool('ver_horarios', servicios: ['Corte de dama'], con: 'Lupita')[:error]).to include('No hay agenda de Lupita', 'Ana López')
    end

    it 'un servicio que no está en el Catálogo no se agenda' do
      expect(tool('ver_horarios', servicios: ['Masaje con piedras volcánicas'])[:error]).to include('No están en el Catálogo')
    end
  end
end
