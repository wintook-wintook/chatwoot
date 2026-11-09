# frozen_string_literal: true

require 'rails_helper'

# Portal del cliente (/cliente/:token): la organización ve sus casos y proyectos y trabaja
# las tareas que le tocan.
RSpec.describe 'Client portal' do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :administrator) }
  let(:organization) { Organization.create!(account: account, name: 'Acme') }
  let(:ana) { create(:contact, account: account, name: 'Ana Acme', organization_id: organization.id) }
  let(:type) { CaseType.create!(account: account, name: 'Implementación', color: '#3b82f6', case_class: :project) }
  let(:project) do
    CaseTicket.create!(account: account, title: 'Implementar facturación', contact: ana, organization: organization,
                       case_type: type, assignee: owner)
  end
  let!(:theirs) { project.case_tasks.create!(account: account, title: 'Probar el timbrado', audience: :client, requires_file: true) }
  let!(:ours) { project.case_tasks.create!(account: account, title: 'Configurar series', audience: :visible) }
  let(:link) { ClientPortalLink.for!(account: account, organization: organization) }
  let(:base) { "/cliente/#{link.token}" }

  def act(task, action, extra = {})
    post "#{base}/tareas/#{task.id}", params: { do: action }.merge(extra)
  end

  it 'muestra lo que le toca, lo nuestro visible y nada de lo interno' do
    project.case_tasks.create!(account: account, title: 'Revisión interna')
    get base
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Probar el timbrado', 'Configurar series', 'Implementar facturación')
    expect(response.body).not_to include('Revisión interna')
  end

  it 'pide elegir quién es antes de trabajar una tarea' do
    ana
    act(theirs, 'start')
    expect(theirs.reload.client_status).to be_nil
    expect(flash[:client_portal_error]).to be_present
  end

  it 'empieza, comenta, sube archivo y completa; queda quién lo hizo y se avisa al responsable' do
    post "#{base}/quien", params: { contact_id: ana.id }
    act(theirs, 'start')
    expect(theirs.reload.client_status).to eq('in_progress')

    act(theirs, 'finish')
    expect(theirs.reload).to be_pending # pide archivo antes

    act(theirs, 'comment', content: 'Ya lo probé, adjunto la evidencia')
    file = Rack::Test::UploadedFile.new(StringIO.new('pdf'), 'application/pdf', original_filename: 'evidencia.pdf')
    act(theirs, 'attach', file: file)
    act(theirs, 'finish', content: 'Listo')

    expect(theirs.reload).to have_attributes(status: 'done', completed_by_contact: ana)
    expect(theirs.client_entries.pluck(:kind)).to eq(%w[started comment file done])
    expect(project.case_events.where(event_type: :task_client_update).count).to eq(4)
    expect(Notification.where(user: owner, notification_type: 'client_task_update')).to exist
  end

  it 'no deja trabajar una tarea nuestra ni de otro cliente' do
    post "#{base}/quien", params: { contact_id: ana.id }
    act(ours, 'start')
    expect(ours.reload.client_status).to be_nil

    other = CaseTicket.create!(account: account, title: 'Otro', contact: create(:contact, account: account), case_type: type)
    alien = other.case_tasks.create!(account: account, title: 'Ajena', audience: :client)
    act(alien, 'start')
    expect(response).to have_http_status(:not_found)
  end

  it 'un enlace desactivado o renovado ya no sirve' do
    old = link.token
    link.renew!
    get "/cliente/#{old}"
    expect(response).to have_http_status(:not_found)
  end
end
