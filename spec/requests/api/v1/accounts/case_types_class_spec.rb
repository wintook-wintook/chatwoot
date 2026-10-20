# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — Plan-Clase-Comercial F1: clase de caso por tipo.
# Hoja de ruta E1.4: la clase es fija (ni el tipo ni el caso cambian de clase).
RSpec.describe 'Case Types API — case_class' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_types" }

  def enable_commercial!
    account.enable_features!('case_commercial')
  end

  it 'un tipo nuevo nace como support' do
    post url, params: { case_type: { name: 'Soporte', color: '#3b82f6' } },
              headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_type']['case_class']).to eq('support')
  end

  it 'rechaza commercial si la cuenta no tiene el flag' do
    post url, params: { case_type: { name: 'Venta', color: '#3b82f6', case_class: 'commercial' } },
              headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'crea commercial con el flag activo' do
    enable_commercial!
    post url, params: { case_type: { name: 'Venta', color: '#3b82f6', case_class: 'commercial' } },
              headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['case_type']['case_class']).to eq('commercial')
  end

  it 'rechaza clases reservadas que aún no se ofrecen' do
    post url, params: { case_type: { name: 'OT', color: '#3b82f6', case_class: 'work_order' } },
              headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'filtra el listado por clase' do
    enable_commercial!
    CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    CaseType.create!(account: account, name: 'Venta', color: '#3b82f6', case_class: :commercial)

    get url, params: { case_class: 'commercial' }, headers: admin.create_new_auth_token

    expect(response.parsed_body['case_types'].pluck('name')).to eq(['Venta'])
  end

  context 'with clase fija (E1.4)' do
    let!(:type)   { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
    let!(:venta)  { CaseType.create!(account: account, name: 'Venta', color: '#3b82f6', case_class: :commercial) }
    let!(:ticket) { CaseTicket.create!(account: account, case_type: type, title: 'Falla', contact: contact) }
    let(:ticket_url) { "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}" }

    before { enable_commercial! }

    it 'rechaza cambiar la clase de un tipo (422) y no cambia nada' do
      patch "#{url}/#{type.id}", params: { case_type: { case_class: 'commercial' } },
                                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(type.reload.case_class).to eq('support')
    end

    it 'deja editar el resto del tipo si la clase no cambia' do
      patch "#{url}/#{type.id}", params: { case_type: { name: 'Soporte N1', case_class: 'support' } },
                                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(type.reload.name).to eq('Soporte N1')
    end

    it 'con casos el prefijo queda fijo (422) y el JSON lo indica' do
      patch "#{url}/#{type.id}", params: { case_type: { prefix: 'NEW' } },
                                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(type.reload.prefix).to eq('SOP')
      get url, headers: admin.create_new_auth_token
      expect(response.parsed_body['case_types'].find { |t| t['id'] == type.id }['prefix_locked']).to be(true)
    end

    it 'sin casos el prefijo se puede corregir' do
      patch "#{url}/#{venta.id}", params: { case_type: { prefix: 'OPO' } },
                                  headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(venta.reload.prefix).to eq('OPO')
    end

    it 'el modelo tampoco deja cambiar la clase' do
      expect(type.update(case_class: :commercial)).to be(false)
      expect(type.errors[:case_class]).to be_present
    end

    it 'rechaza mover el caso a un tipo de otra clase (422)' do
      patch ticket_url, params: { case_ticket: { case_type_id: venta.id } },
                        headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.reload.case_type_id).to eq(type.id)
    end

    it 'deja mover el caso a otro tipo de la misma clase' do
      otro = CaseType.create!(account: account, name: 'Incidente', color: '#ef4444')

      patch ticket_url, params: { case_ticket: { case_type_id: otro.id } },
                        headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(ticket.reload.case_type_id).to eq(otro.id)
    end

    it 'a una oportunidad no se le puede quitar el tipo' do
      opp = CaseTicket.create!(account: account, case_type: venta, title: 'Cotización', contact: contact)

      expect(opp.update(case_type_id: nil)).to be(false)
      expect(opp.reload.case_type_id).to eq(venta.id)
    end

    it 'una automatización que quita el tipo no toca una oportunidad' do
      conversation = create(:conversation, account: account, contact: contact)
      opp = CaseTicket.create!(account: account, case_type: venta, title: 'Cotización', contact: contact,
                               conversation: conversation)

      ActionService.new(conversation).send(:assign_case_type, ['nil'])
      expect(opp.reload.case_type_id).to eq(venta.id)
    end
  end
end
