require 'rails_helper'

RSpec.describe ContactTrackings::SheetCalendars do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:agenda) do
    UserCalendarIntegration.create!(account: account, user: create(:user, account: account),
                                    google_email: 'camion@gruas.com', tokens: {})
  end
  let(:prompt) do
    "@ruta(solicitud #solicita_servicio: quiero un servicio): {{hoja:Servicio Gruas}} -> " \
      "{{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar\n\n[ROL]\nAgente de grúas."
  end
  let(:template) do
    create(:tracking_template, account: account, complementary_prompt: prompt,
                               calendar_integration_ids: [agenda.id],
                               booking_calendar_ids: { agenda.id.to_s => %w[c64@group.calendar.google.com c63@group.calendar.google.com] })
  end
  let(:tracking) do
    ContactTracking.create!(account: account, contact: contact, inbox: inbox, conversation: conversation,
                            objective: 'Grúas', scheduled_for: 1.hour.from_now, tracking_template: template,
                            complementary_prompt: prompt)
  end
  let(:source) { create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Servicio Gruas') }

  before do
    { 'TP-64' => 'c64', 'TP-63' => 'c63', 'TP-99' => 'c99' }.each_with_index do |(remolque, cal), i|
      embed = "https://calendar.google.com/calendar/embed?src=#{cal}%40group.calendar.google.com&ctz=America%2FMexico_City"
      GoogleSheetRow.create!(account: account, knowledge_source: source, row_index: i,
                             data: { 'remolque' => remolque, 'Calendar_ID' => embed })
    end
  end

  def say(content, type = :incoming)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: type, content: content)
  end

  def outcome
    described_class.for(tracking, say('sí, agéndalo'), nil)
  end

  it 'deja solo el calendario del remolque que se nombró' do
    say('Te recomiendo la TP-64 o la TP-63', :outgoing)
    say('La TP-63')

    expect(outcome.to_h.slice(:status, :integration_ids, :booking_calendars))
      .to eq(status: :ok, integration_ids: [agenda.id], booking_calendars: { agenda.id.to_s => ['c63@group.calendar.google.com'] })
  end

  it 'si no se nombró ninguno, hay que preguntar cuál' do
    expect(outcome.to_h.slice(:status, :asked)).to eq(status: :needs_value, asked: 'remolque')
  end

  it 'un remolque cuyo calendario no está marcado en el agente no se ofrece' do
    say('Quiero la TP-99')

    expect(outcome.status).to eq(:unavailable)
  end

  it 'una agenda que no está en «Calendarios» del agente no cuenta aunque tenga el calendario marcado' do
    template.update!(calendar_integration_ids: [])
    tracking.update!(calendar_integration_ids: [])
    say('Quiero la TP-64')

    expect(outcome.status).to eq(:unavailable)
  end

  it 'sin {{hoja_buscar:}} en el Entrenamiento la agenda sigue como siempre' do
    tracking.update!(complementary_prompt: '@ruta(solicitud: servicio): - -> @agendar_calendar')

    expect(outcome).to be_nil
  end
end
