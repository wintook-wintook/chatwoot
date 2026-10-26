# frozen_string_literal: true

require 'rails_helper'

# diag/llamadas_whatsapp (F8) — lo que pasa con una llamada que nadie contestó.
RSpec.describe Calls::MissedCallService do
  let(:channel) { calling_channel }
  let(:account) { channel.account }
  let(:agente) { create(:user, account: account, name: 'Ana', display_name: 'Ana') }
  let(:contact) { create(:contact, account: account, name: 'Juan Pérez', phone_number: '+5215512345678') }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, contact: contact) }
  let(:call) do
    create(:call, account: account, inbox: channel.inbox, conversation: conversation, contact: contact, status: 'no_answer',
                  ring_state: { 'ring_recipient_ids' => [agente.id] })
  end
  let(:tipo) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }

  before do
    account.update!(locale: 'es')
    allow(ActionCable.server).to receive(:broadcast)
  end

  def configurar(**valores)
    channel.update_columns(provider_config: channel.provider_config.merge(valores.stringify_keys)) # rubocop:disable Rails/SkipsModelValidations
  end

  def perdida!
    described_class.new(call: call.reload).perform
  end

  def lineas
    conversation.messages.where(message_type: :activity).pluck(:content)
  end

  it 'siempre avisa (campana) a quien le sonó, aunque no haya acciones; y solo una vez' do
    perdida!
    perdida!

    notificacion = Notification.where(user: agente, notification_type: :missed_call)
    expect(notificacion.count).to eq(1)
    expect(notificacion.first.push_message_title).to include('Juan Pérez')
    expect(lineas).to be_empty
  end

  it 'una contestada no es perdida: no hace nada' do
    call.update_columns(status: 'completed', accepted_by_agent_id: agente.id) # rubocop:disable Rails/SkipsModelValidations
    perdida!
    expect(Notification.where(notification_type: :missed_call)).to be_empty
  end

  it 'nota y etiqueta (la crea si no existe)' do
    configurar(missed_call_actions: %w[note label])
    perdida!

    expect(lineas).to eq(['Llamada perdida de Juan Pérez. Sonó a: Ana.'])
    expect(conversation.reload.label_list).to eq(['llamada-perdida'])
    expect(account.labels.where(title: 'llamada-perdida')).to exist
  end

  describe 'ticket (P2)' do
    before { configurar(missed_call_actions: %w[ticket], missed_call_case_type_id: tipo.id) }

    it 'sin ticket abierto de ese tipo, crea uno ligado a la conversación' do
      perdida!

      ticket = CaseTicket.find_by!(contact: contact, case_type: tipo)
      expect(ticket).to have_attributes(conversation_id: conversation.id, title: 'Llamada perdida de Juan Pérez')
      expect(lineas.last).to include('se creó el ticket')
    end

    it 'con uno abierto del mismo tipo, le agrega una nota' do
      abierto = CaseTicket.create!(account: account, contact: contact, case_type: tipo, origin: :whatsapp,
                                   assignee_type: :bot, title: 'Ya estaba')
      perdida!

      expect(CaseTicket.where(contact: contact).count).to eq(1)
      expect(abierto.case_events.where(event_type: :internal_note).last.payload['content']).to include('Juan Pérez')
      expect(lineas.last).to include('se agregó una nota')
    end
  end

  describe 'seguimiento (P3)' do
    let(:template) { create(:tracking_template, account: account, inbox_id: channel.inbox.id) }
    let(:campana) do
      create(:tracking_campaign, account: account, inbox: channel.inbox, tracking_template: template, mode: 'continuous',
                                 scheduled_for: 1.hour.ago, respect_working_hours: false)
    end

    before do
      create(:user, account: account, role: :administrator)
      configurar(missed_call_actions: %w[tracking], missed_call_campaign_id: campana.id)
    end

    it 'lo inscribe en la campaña elegida' do
      perdida!

      expect(campana.entries.find_by!(contact: contact)).to have_attributes(status: 'enrolled', source: 'missed_call')
      expect(lineas.last).to include('se inscribió')
    end

    it 'si ya tiene un seguimiento activo en la bandeja, se omite y queda dicho' do
      create(:contact_tracking, account: account, contact: contact, inbox: channel.inbox, status: 'active')
      perdida!

      expect(lineas.last).to include('ya tiene un seguimiento activo')
    end
  end

  describe 'mensaje al cliente' do
    before { configurar(missed_call_actions: %w[auto_reply]) }

    it 'con la ventana de 24 h abierta, se le manda' do
      create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :incoming, content: 'hola')
      perdida!

      expect(conversation.messages.outgoing.pluck(:content))
        .to eq([I18n.t('conversations.messages.whatsapp.missed_call_auto_reply', locale: :es)])
    end

    it 'con la ventana cerrada, no se manda y queda dicho' do
      perdida!

      expect(conversation.messages.outgoing).to be_empty
      expect(lineas.last).to include('ventana de 24 h')
    end
  end

  it 'si una acción falla, las demás siguen' do
    configurar(missed_call_actions: %w[ticket note], missed_call_case_type_id: tipo.id)
    allow(CaseTicket).to receive(:create!).and_raise(StandardError, 'falló')
    perdida!

    expect(lineas).to include('Llamada perdida de Juan Pérez. Sonó a: Ana.')
  end
end
