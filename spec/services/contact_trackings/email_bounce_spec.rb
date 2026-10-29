# frozen_string_literal: true

require 'rails_helper'

# prospeccion V7b (docs/prospeccion_estudio.md §10.8) — el correo rebotó.
RSpec.describe ContactTrackings::EmailBounce do
  let(:account) { create(:account) }
  let(:email_inbox) { create(:channel_email, account: account).inbox }
  let(:whatsapp_inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account, email: 'noexiste@gmail.com') }
  let(:gmail_bounce) { Mail.read(file_fixture('gmail_bounce.eml')) }

  it 'rebote definitivo: marca el correo, cancela el seguimiento por correo y deja nota' do
    conversation = create(:conversation, account: account, inbox: email_inbox, contact: contact)
    tracking = create(:contact_tracking, account: account, inbox: email_inbox, contact: contact,
                                         conversation: conversation, status: 'active')

    expect(described_class.handle(gmail_bounce, email_inbox)).to be(true)

    expect(contact.reload).to be_email_bounced
    expect(contact.email_bounce_reason).to start_with('5.1.1 smtp; 550-5.1.1')
    expect(tracking.reload).to have_attributes(status: 'cancelled', prospect_exit: 'bounced')
    expect(conversation.messages.activity.last.content).to include('noexiste@gmail.com rebotó')
  end

  it 'su WhatsApp sigue: solo se detienen los seguimientos en bandejas de correo' do
    whatsapp = create(:contact_tracking, account: account, inbox: whatsapp_inbox, contact: contact, status: 'scheduled')

    described_class.handle(gmail_bounce, email_inbox)

    expect(whatsapp.reload.status).to eq('scheduled')
    expect(contact.reload).not_to be_opted_out
  end

  it 'rebote temporal (4.x.x, delayed): no hace nada y sigue el camino de siempre' do
    delayed = Mail.read_from_string(file_fixture('gmail_bounce.eml').read
                                    .sub('Action: failed', 'Action: delayed').sub('Status: 5.1.1', 'Status: 4.4.7'))

    expect(described_class.handle(delayed, email_inbox)).to be(false)
    expect(contact.reload).not_to be_email_bounced
  end

  it 'un correo normal no es rebote' do
    normal = Mail.read(file_fixture('in_reply_to.eml'))
    expect(described_class.handle(normal, email_inbox)).to be(false)
  end

  it 'rebote de alguien que no es contacto de la cuenta: se descarta sin marcar a nadie' do
    other = create(:contact, account: create(:account), email: 'noexiste@gmail.com')

    expect(described_class.handle(gmail_bounce, email_inbox)).to be(true)
    expect(other.reload).not_to be_email_bounced
  end

  it 'el rebote real de los fixtures de Chatwoot también se reconoce' do
    expect(described_class.hard_bounce?(Mail.read(file_fixture('bounced_with_no_from.eml')))).to be(true)
  end

  it 'si le cambian el correo, se le quita la marca' do
    described_class.handle(gmail_bounce, email_inbox)
    expect(contact.reload).to be_email_bounced
    contact.update!(email: 'juan@empresa.mx')

    expect(contact.reload).not_to be_email_bounced
    expect(contact.email_bounce_reason).to be_nil
  end

  it 'ya rebotado: ninguna campaña por correo lo vuelve a inscribir' do
    described_class.handle(gmail_bounce, email_inbox)
    host = Class.new { include ContactTrackings::Eligibility }.new

    expect(host.channel_contactability(contact.reload, 'Channel::Email', reusable: true)).to eq([false, 'INVALID_EMAIL'])
  end

  describe 'en la bandeja IMAP' do
    it 'el rebote ya no se vuelve conversación ni mensaje' do
      expect { Imap::ImapMailbox.new.process(gmail_bounce, email_inbox.channel) }
        .not_to change(Message.where.not(message_type: :activity), :count)
      expect(contact.reload).to be_email_bounced
    end
  end
end
