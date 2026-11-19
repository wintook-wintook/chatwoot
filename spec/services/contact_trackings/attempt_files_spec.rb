# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — intentos del seguimiento y archivos por intento.
RSpec.describe ContactTrackings::AttemptFiles do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:bot) { create(:user, account: account) }

  def adjuntar(nombre)
    archivo = template.ai_agent_attachments.new(name: nombre, account: account)
    archivo.file.attach(io: StringIO.new('pdf'), filename: "#{nombre}.pdf", content_type: 'application/pdf')
    archivo.save!
  end

  describe 'TrackingTemplate#follow_up_attempts' do
    it 'con plantillas, una por intento; sin plantillas, los de la ficha o 3' do
      expect(template.follow_up_attempts).to eq(3)
      template.follow_up_attempts = 5
      expect(template.follow_up_attempts).to eq(5)
      template.whatsapp_templates = %w[uno dos]
      expect(template.follow_up_attempts).to eq(2)
    end
  end

  it 'manda en un mensaje aparte los archivos de ESE intento' do
    adjuntar('catalogo')
    adjuntar('garantia')
    template.update!(resources: { 'files' => { 'catalogo' => { 'attempts' => [2] }, 'garantia' => { 'attempts' => [3] } } })
    tracking = instance_double(ContactTracking, tracking_template: template, conversation: conversation, conversation_id: conversation.id)

    expect(described_class.send_for(tracking, 1, sender: bot)).to be_nil
    mensaje = described_class.send_for(tracking, 2, sender: bot)
    expect(mensaje.attachments.size).to eq(1)
    expect(mensaje.attachments.first.file.filename.to_s).to eq('catalogo.pdf')
  end

  it 'al agendar y al levantar un ticket de ese tipo (o cualquiera) manda sus archivos' do
    adjuntar('mapa')
    adjuntar('formato')
    template.update!(resources: { 'files' => { 'mapa' => { 'booking' => true },
                                               'formato' => { 'tickets' => ['Soporte'] } } })
    tracking = instance_double(ContactTracking, tracking_template: template)

    cita = ContactTrackings::EventFiles.send_for(tracking, :booking, conversation: conversation, sender: bot)
    expect(cita.attachments.first.file.filename.to_s).to eq('mapa.pdf')
    expect(ContactTrackings::EventFiles.send_for(tracking, :ticket, conversation: conversation, sender: bot, case_type: 'Ventas')).to be_nil
    ticket = ContactTrackings::EventFiles.send_for(tracking, :ticket, conversation: conversation, sender: bot, case_type: 'soporte')
    expect(ticket.attachments.first.file.filename.to_s).to eq('formato.pdf')

    template.update!(resources: { 'files' => { 'formato' => { 'tickets' => ['*'] } } })
    expect(template.files_for_ticket('Ventas')).to eq(['formato'])
  end

  # fix/campanas: en correo el archivo del intento va adjunto al MISMO correo del intento.
  describe 'en un canal de correo' do
    let(:email_channel) { create(:channel_email, account: account) }
    let(:email_inbox) { email_channel.inbox }
    let(:template) { create(:tracking_template, account: account, inbox: email_inbox) }
    let(:conversation) { create(:conversation, account: account, inbox: email_inbox) }
    let(:tracking) do
      create(:contact_tracking, account: account, inbox: email_inbox, contact: conversation.contact,
                                conversation: conversation, tracking_template: template, status: 'active', attempt_count: 0)
    end

    before do
      adjuntar('flyer')
      template.update!(resources: { 'files' => { 'flyer' => { 'attempts' => [1, 2] } } })
    end

    it 'signed_ids_for da los archivos de ese intento' do
      expect(described_class.signed_ids_for(tracking, 1).size).to eq(1)
      expect(described_class.signed_ids_for(tracking, 3)).to eq([])
    end

    it 'el intento sale en un solo correo con el texto y el flyer' do
      expect do
        expect(ContactTrackingJob.new.send(:send_attempt_with_files, tracking, 'Te comparto la promoción')).to be(true)
      end.to change(conversation.messages, :count).by(1)

      mensaje = conversation.messages.last
      expect(mensaje.content).to eq('Te comparto la promoción')
      expect(mensaje.attachments.map { |a| a.file.filename.to_s }).to eq(['flyer.pdf'])
    end
  end
end
