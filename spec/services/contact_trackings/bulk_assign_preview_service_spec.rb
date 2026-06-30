# frozen_string_literal: true

require 'rails_helper'

# @campanas_vendedor / proyecto@bulk_tracking_assign
RSpec.describe ContactTrackings::BulkAssignPreviewService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }

  # Canal basado en teléfono (mismo criterio de contactabilidad que WhatsApp).
  let(:sms_channel) { create(:channel_sms, account: account) }
  let(:inbox) { sms_channel.inbox }
  let(:template) { create(:tracking_template, account: account, inbox: inbox) }

  # Filtro que resuelve a todos los contactos no bloqueados de la cuenta.
  let(:match_all_payload) do
    [{ 'attribute_key' => 'blocked', 'filter_operator' => 'equal_to', 'values' => [false], 'query_operator' => nil }]
  end

  def preview(excluded: [], skip_active: true)
    described_class.new(
      account: account,
      current_user: user,
      filter_payload: match_all_payload,
      template_id: template.id,
      skip_active: skip_active,
      excluded_contact_ids: excluded
    ).call
  end

  describe '#call validaciones' do
    it 'devuelve error si la plantilla no existe' do
      result = described_class.new(
        account: account, current_user: user, filter_payload: match_all_payload, template_id: 0
      ).call

      expect(result[:error]).to eq('Plantilla no encontrada')
    end

    it 'devuelve error si la plantilla no tiene inbox' do
      template_without_inbox = create(:tracking_template, account: account, inbox: nil)
      result = described_class.new(
        account: account, current_user: user, filter_payload: match_all_payload, template_id: template_without_inbox.id
      ).call

      expect(result[:error]).to match(/no tiene un inbox configurado/)
    end
  end

  describe '#call clasificación en buckets' do
    let!(:ready_contact) { create(:contact, :with_phone_number, account: account) }
    let!(:unreachable_contact) { create(:contact, account: account) } # sin teléfono
    let!(:in_tracking_contact) { create(:contact, :with_phone_number, account: account) }
    let!(:excluded_contact) { create(:contact, :with_phone_number, account: account) }

    before do
      create(:contact_tracking, account: account, contact: in_tracking_contact, inbox: inbox, status: 'active')
    end

    it 'devuelve la info del canal' do
      result = preview(excluded: [excluded_contact.id])

      expect(result[:channel]).to include(
        inbox_id: inbox.id,
        inbox_name: inbox.name,
        channel_type: 'Channel::Sms'
      )
    end

    it 'clasifica cada contacto en su bucket' do
      result = preview(excluded: [excluded_contact.id])
      buckets = result[:contacts].index_by { |c| c[:id] }

      expect(buckets[ready_contact.id][:bucket]).to eq(:ready)
      expect(buckets[in_tracking_contact.id][:bucket]).to eq(:in_tracking)
      expect(buckets[unreachable_contact.id][:bucket]).to eq(:unreachable)
      expect(buckets[excluded_contact.id][:bucket]).to eq(:excluded)
    end

    it 'marca el motivo NO_PHONE en los no contactables' do
      result = preview(excluded: [excluded_contact.id])
      unreachable = result[:contacts].find { |c| c[:id] == unreachable_contact.id }

      expect(unreachable[:reason]).to eq('NO_PHONE')
    end

    it 'devuelve los conteos por bucket + total' do
      result = preview(excluded: [excluded_contact.id])

      expect(result[:counts]).to eq(
        ready: 1, in_tracking: 1, unreachable: 1, excluded: 1, total: 4
      )
      expect(result[:truncated]).to be(false)
    end

    it 'con skip_active=false, el contacto en seguimiento pasa a ready (fiel al create)' do
      result = preview(excluded: [excluded_contact.id], skip_active: false)
      buckets = result[:contacts].index_by { |c| c[:id] }

      expect(buckets[in_tracking_contact.id][:bucket]).to eq(:ready)
      expect(result[:counts][:in_tracking]).to eq(0)
      expect(result[:counts][:ready]).to eq(2)
    end
  end
end
