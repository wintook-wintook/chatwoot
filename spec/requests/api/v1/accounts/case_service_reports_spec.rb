# frozen_string_literal: true

require 'rails_helper'

# Plan-Trabajo-Campo R1 — reporte de servicio de la orden de trabajo.
RSpec.describe 'Service report API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Jane') }
  let(:orden)   { CaseType.create!(account: account, name: 'Mantenimiento A/C', color: '#0d9488', case_class: :work_order) }
  let(:order)   { CaseTicket.create!(account: account, title: 'Mantenimiento', contact: contact, case_type: orden) }
  let(:url)     { "/api/v1/accounts/#{account.id}/case_tickets/#{order.id}/service_report" }
  let(:photo)   { Rack::Test::UploadedFile.new(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  def report
    response.parsed_body['service_report']
  end

  it 'en campo viene del tipo y se cambia por orden' do
    get url, headers: admin.create_new_auth_token, as: :json
    expect(report['on_site']).to be(true)

    patch url, params: { on_site: false }, headers: admin.create_new_auth_token, as: :json
    expect(report['on_site']).to be(false)
    expect(order.reload.on_site).to be(false)
  end

  it 'bitácora: notas y fotos con etiqueta antes/después' do
    post "#{url}/logs", params: { kind: 'note', content: 'Se cambió el capacitor' }, headers: admin.create_new_auth_token
    post "#{url}/logs", params: { kind: 'photo', tag: 'before', file: photo }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:created)
    logs = report['logs']
    expect(logs.pluck('kind')).to eq(%w[note photo])
    expect(logs.last['tag']).to eq('before')
    expect(logs.last['file_url']).to be_present
  end

  it 'horas: el botón Iniciar/Terminar y la captura manual suman las horas reales' do
    travel_to(Time.zone.parse('2026-10-30 10:00')) do
      post "#{url}/timer", params: { timer_action: 'start' }, headers: admin.create_new_auth_token, as: :json
      expect(report['running_entry']).to be_present
    end
    travel_to(Time.zone.parse('2026-10-30 11:30')) do
      post "#{url}/timer", params: { timer_action: 'stop' }, headers: admin.create_new_auth_token, as: :json
    end
    post "#{url}/time_entries", params: { minutes: 30, note: 'Traslado' }, headers: admin.create_new_auth_token, as: :json
    expect(report['actual_hours']).to eq(2.0)
    expect(order.reload.actual_hours.to_f).to eq(2.0)
  end

  it 'no se termina sin las tareas obligatorias, las fotos ni la conformidad que pide el tipo' do
    orden.update!(field_settings: { require_photos: true, require_conformity: true })
    order.case_tasks.create!(account: account, title: 'Revisar presión', required: true)
    expect do
      order.transition!('resolved', force: true)
    end.to raise_error(ServiceReports::Incomplete, /#{I18n.t('service_reports.missing.required_tasks')}/)

    get url, headers: admin.create_new_auth_token, as: :json
    expect(report['missing']).to match_array(%w[required_tasks photo_before photo_after conformity])

    order.case_tasks.each { |task| task.update!(status: :done) }
    %w[before after].each { |tag| order.work_logs.create!(account: account, kind: :photo, tag: tag, file: photo) }
    order.update!(received_by: 'Jane')
    expect { order.transition!('resolved', force: true) }.not_to raise_error
  end

  it 'al terminarse, manda solo el reporte al cliente por su conversación' do
    inbox = create(:inbox, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    order.transition!('resolved', force: true)
    expect(order.reload.report_sent_at).to be_present
    expect(conversation.messages.last.content).to include("/reporte/#{order.report_token}")
  end

  it 'con «revisar antes» no se manda solo; se manda con el botón' do
    orden.update!(field_settings: { report_delivery: 'review' })
    inbox = create(:inbox, account: account)
    create(:conversation, account: account, inbox: inbox, contact: contact)
    order.transition!('resolved', force: true)
    expect(order.reload.report_sent_at).to be_nil

    post "#{url}/deliver", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(order.reload.report_sent_at).to be_present
  end

  it 'la página del reporte para el cliente' do
    order.work_logs.create!(account: account, kind: :note, content: 'Se limpiaron filtros')
    order.update!(received_by: 'Jane', received_at: Time.current)
    get "/reporte/#{order.ensure_report_token!}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Se limpiaron filtros')
    expect(response.body).to include('Jane')
  end

  it 'solo órdenes de trabajo' do
    soporte = CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
    ticket = CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)
    get "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}/service_report", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
