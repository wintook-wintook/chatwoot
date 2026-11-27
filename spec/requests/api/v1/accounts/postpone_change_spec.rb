# frozen_string_literal: true

require 'rails_helper'

# Cambiar una pospuesta: el detalle trae su comentario vigente y el cambio queda en la
# actividad marcado como cambio.
RSpec.describe 'Postpone change' do
  let(:account) { create(:account, locale: 'es') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:opp) do
    CaseTicket.create!(account: account, title: 'Licencias', contact: create(:contact, account: account), case_type: venta)
  end
  let(:url) { "/api/v1/accounts/#{account.id}/case_tickets/#{opp.id}" }

  it 'el detalle trae el comentario y al cambiarla queda como cambio en la actividad' do
    patch "#{url}/postpone", params: { postponed_until: 5.days.from_now.to_date.iso8601, reason: 'Presupuesto en enero' },
                             headers: admin.create_new_auth_token, as: :json
    get url, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_ticket']).to include('is_postponed' => true, 'postpone_note' => 'Presupuesto en enero')

    patch "#{url}/postpone", params: { postponed_until: 10.days.from_now.to_date.iso8601, reason: 'Ahora en febrero' },
                             headers: admin.create_new_auth_token, as: :json
    last = opp.case_events.where(event_type: :postponed).order(:created_at).last
    expect(last.payload).to include('changed' => true, 'reason' => 'Ahora en febrero')
    get url, headers: admin.create_new_auth_token
    expect(response.parsed_body['case_ticket']).to include('postpone_note' => 'Ahora en febrero',
                                                           'postponed_until' => 10.days.from_now.to_date.iso8601)
  end
end
