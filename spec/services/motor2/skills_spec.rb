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
end
