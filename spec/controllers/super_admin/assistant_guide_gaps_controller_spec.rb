# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Super Admin Preguntas sin respuesta', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, name: 'Acme') }
  let!(:gap) { AssistantGuideGap.record!(account: account, reason: 'no_guide', question: '¿Cómo conecto CONTPAQi?') }

  it 'pide iniciar sesión' do
    get '/super_admin/assistant_guide_gaps'
    expect(response).to have_http_status(:redirect)
  end

  it 'lista las pendientes de todas las empresas' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/assistant_guide_gaps'
    expect(response).to have_http_status(:success)
    expect(response.body).to include('¿Cómo conecto CONTPAQi?', 'Acme')
  end

  it 'marca una como resuelta con nota' do
    sign_in(super_admin, scope: :super_admin)
    patch "/super_admin/assistant_guide_gaps/#{gap.id}", params: { status: 'resolved', note: 'guía nueva' }
    expect(gap.reload).to have_attributes(status: 'resolved', resolution_note: 'guía nueva')
  end
end
