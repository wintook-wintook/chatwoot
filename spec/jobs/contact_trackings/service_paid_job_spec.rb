require 'rails_helper'

RSpec.describe ContactTrackings::ServicePaidJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:case_type) { CaseType.create!(account: account, name: 'Solicitud de transporte', color: '#3b82f6') }
  let(:pagado) do
    CaseTypeColumn.create!(account: account, case_type: case_type, label: 'Pagado', color: '#16a34a', statuses: %w[in_progress], position: 3)
  end
  let(:pagador) { instance_double(ContactTrackings::ServiceRequests::PaidService, confirm!: true) }

  before { allow(ContactTrackings::ServiceRequests::PaidService).to receive(:new).and_return(pagador) }

  def caso(estado)
    CaseTicket.create!(account: account, conversation: conversation, contact: conversation.contact, case_type: case_type, title: 'Plana',
                       metadata: { 'servicio' => { 'label' => 'Plana' }, 'estado' => estado })
  end

  it 'un servicio esperando pago movido a «Pagado» queda en firme (solo ese)' do
    uno = caso('esperando_pago')
    uno.update_columns(case_type_column_id: pagado.id) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now(uno.id)
    expect(pagador).to have_received(:confirm!).with([uno])
  end

  it 'otra columna, o un servicio ya confirmado, no hace nada' do
    otro = caso('confirmado')
    otro.update_columns(case_type_column_id: pagado.id) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now(otro.id)
    expect(pagador).not_to have_received(:confirm!)
  end
end
