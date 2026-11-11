# frozen_string_literal: true

require 'rails_helper'

# Agentes listos — lo que el agente sabe de la empresa: su negocio, sus preguntas, objeciones y datos.
RSpec.describe ReadyAgents::Prompt do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:settings) { {} }
  let(:agent) do
    ReadyAgent.create!(account: account, kind: 'prospects', name: 'Sofi', enabled: false, inbox_ids: [inbox.id], settings: settings)
  end
  let(:system) { described_class.new(agent, conversation).system }

  it 'sin configurar (agentes de antes): pregunta qué necesita y explica la temperatura' do
    expect(system).to include('Qué necesita y para qué: «¿Qué necesitas y para qué lo quieres?»', 'TEMPERATURA')
    expect(system).not_to include('EL NEGOCIO', 'OBJECIONES FRECUENTES (', 'DATOS OBLIGATORIOS')
  end

  it 'con horario de atención en la bandeja, lo trae (para «¿abren el domingo?»)' do
    inbox.update!(working_hours_enabled: true, timezone: 'America/Mexico_City')
    inbox.working_hours.find_by(day_of_week: 0).update!(closed_all_day: true)
    inbox.working_hours.find_by(day_of_week: 1).update!(open_hour: 9, open_minutes: 0, close_hour: 18, close_minutes: 0)

    expect(system).to include('HORARIO DE ATENCIÓN', 'lunes 09:00 a 18:00', 'domingo cerrado')
    expect(system.index('lunes 09:00')).to be < system.index('domingo cerrado')
  end

  context 'with todo configurado' do
    let(:settings) do
      { 'business_what' => 'Paneles solares', 'business_coverage' => 'Monterrey', 'business_use_catalog' => true,
        'qualify' => [{ 'key' => 'need', 'on' => false }, { 'key' => 'budget', 'on' => true, 'text' => '¿Cuánto pagas de luz?' },
                      { 'key' => 'when', 'on' => true }],
        'questions' => '¿Techo de lámina o concreto?',
        'objections' => [{ 'objection' => 'Está caro', 'answer' => 'Se paga solo en 4 años' }, { 'objection' => '', 'answer' => 'x' }],
        'required_contact' => %w[email company] }
    end

    it 'trae el negocio, las preguntas prendidas en orden, las objeciones y los datos a juntar' do
      expect(system).to include('Qué vende: Paneles solares', 'Dónde da servicio: Monterrey', 'buscar_en_catalogo')
      expect(system).to include('Para cuándo: «¿Para cuándo lo necesitas?»', 'Presupuesto: «¿Cuánto pagas de luz?»',
                                'Preguntas propias de la empresa: ¿Techo de lámina o concreto?')
      expect(system.index('Para cuándo:')).to be < system.index('Presupuesto:')
      expect(system).not_to include('Qué necesita y para qué:')
      expect(system).to include('«Está caro» → Se paga solo en 4 años', 'falta su correo y empresa')
      expect(system.scan('→').size).to eq(1)
    end
  end
end
