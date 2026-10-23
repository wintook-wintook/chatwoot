# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases F2 — vistas compartidas: quien las ve y quien puede tocarlas.
RSpec.describe 'Custom Filters API — vistas compartidas' do
  let(:account) { create(:account) }
  let(:duenio)  { create(:user, account: account, role: :agent) }
  let(:otro)    { create(:user, account: account, role: :agent) }
  let(:admin)   { create(:user, account: account, role: :administrator) }

  def crear(user, shared:, filter_type: :case_ticket, name: 'Vista')
    create(:custom_filter, user: user, account: account, filter_type: filter_type, shared: shared, name: name)
  end

  describe 'GET /custom_filters' do
    it 'trae las propias y las compartidas por otros, no las personales ajenas' do
      mia        = crear(duenio, shared: false, name: 'Mi cola')
      compartida = crear(otro,   shared: true,  name: 'Escalados')
      ajena      = crear(otro,   shared: false, name: 'La de el')

      get "/api/v1/accounts/#{account.id}/custom_filters",
          params: { filter_type: 'case_ticket' }, headers: duenio.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      ids = response.parsed_body.pluck('id')
      expect(ids).to contain_exactly(mia.id, compartida.id)
      expect(ids).not_to include(ajena.id)
    end

    it 'expone shared y el nombre del dueno' do
      crear(otro, shared: true, name: 'Escalados')

      get "/api/v1/accounts/#{account.id}/custom_filters",
          params: { filter_type: 'case_ticket' }, headers: duenio.create_new_auth_token, as: :json

      fila = response.parsed_body.first
      expect(fila['shared']).to be(true)
      expect(fila['user_id']).to eq(otro.id)
      expect(fila['owner_name']).to eq(otro.available_name)
    end

    # La regresion que importa: las carpetas de Conversaciones no deben empezar
    # a verse entre agentes por culpa del scope nuevo.
    it 'no mezcla las carpetas de conversaciones de otros agentes' do
      mia = crear(duenio, shared: false, filter_type: :conversation, name: 'Mis abiertas')
      crear(otro, shared: false, filter_type: :conversation, name: 'Las de el')

      get "/api/v1/accounts/#{account.id}/custom_filters",
          headers: duenio.create_new_auth_token, as: :json

      expect(response.parsed_body.pluck('id')).to eq([mia.id])
    end
  end

  describe 'PATCH /custom_filters/:id' do
    it 'deja al dueno editar la suya' do
      mia = crear(duenio, shared: true)

      patch "/api/v1/accounts/#{account.id}/custom_filters/#{mia.id}",
            params: { custom_filter: { name: 'Renombrada' } },
            headers: duenio.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(mia.reload.name).to eq('Renombrada')
    end

    it 'no deja a un agente editar la compartida de otro' do
      compartida = crear(otro, shared: true, name: 'Escalados')

      patch "/api/v1/accounts/#{account.id}/custom_filters/#{compartida.id}",
            params: { custom_filter: { name: 'Secuestrada' } },
            headers: duenio.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(compartida.reload.name).to eq('Escalados')
    end

    it 'deja a un administrador editar una compartida ajena' do
      compartida = crear(otro, shared: true, name: 'Escalados')

      patch "/api/v1/accounts/#{account.id}/custom_filters/#{compartida.id}",
            params: { custom_filter: { name: 'Escalados del equipo' } },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(compartida.reload.name).to eq('Escalados del equipo')
    end

    it 'permite compartir una vista propia' do
      mia = crear(duenio, shared: false)

      patch "/api/v1/accounts/#{account.id}/custom_filters/#{mia.id}",
            params: { custom_filter: { shared: true } },
            headers: duenio.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(mia.reload.shared).to be(true)
    end
  end

  describe 'DELETE /custom_filters/:id' do
    it 'no deja a un agente borrar la compartida de otro' do
      compartida = crear(otro, shared: true)

      delete "/api/v1/accounts/#{account.id}/custom_filters/#{compartida.id}",
             headers: duenio.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(CustomFilter.exists?(compartida.id)).to be(true)
    end

    # Un administrador manda sobre lo compartido, pero no sobre la vista
    # personal de un agente: esa no es suya para tocarla.
    it 'no deja a un administrador borrar la personal de un agente' do
      personal = crear(otro, shared: false)

      delete "/api/v1/accounts/#{account.id}/custom_filters/#{personal.id}",
             headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(CustomFilter.exists?(personal.id)).to be(true)
    end
  end
end
