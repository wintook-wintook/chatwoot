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
end
