# frozen_string_literal: true

require 'rails_helper'

# feat/licencias F6.4 — el registro de cambios de una cuenta, en eventos
RSpec.describe Licenses::AccountChangeLog do
  let(:account) { create(:account) }
  let(:gestor) { create(:user, name: 'Ana Ruiz') }

  def eventos(**filtros)
    described_class.new(account: account, **filtros).perform[:events]
  end

  def como(usuario, &)
    Audited.audit_class.as_user(usuario, &)
  end

  it 'traduce licencias: asignar, subir el tope con motivo y vencer por el sistema' do
    licencia = como(gestor) { create(:account_license, account: account, name: 'Profesional', max_agents: 5) }
    como(gestor) { Licenses::AgentIncrease.new(license: licencia, add: 2, reason: 'pidió dos más').perform }
    licencia.update!(status: :expired)

    ultimo, tope, alta = eventos.first(3)
    expect(alta).to include(kind: 'licenses', event: 'license_created', user: gestor.available_name,
                            params: include(name: 'Profesional', max_agents: 5, status: 'active'))
    expect(tope).to include(event: 'license_agents', comment: 'pidió dos más', params: include(from: 5, to: 7))
    expect(ultimo).to include(event: 'license_status', user: nil, params: include(from: 'active', to: 'expired'))
  end

  it 'agentes: entra, cambia de rol y sale; la disponibilidad no cuenta' do
    agente = create(:user, name: 'Luis Gómez')
    miembro = como(gestor) { create(:account_user, account: account, user: agente, role: :agent) }
    miembro.update!(availability: :busy)
    como(gestor) { miembro.update!(role: :administrator) }
    como(gestor) { miembro.destroy! }

    expect(eventos(kind: 'agents').pluck(:event)).to eq(%w[agent_removed agent_role agent_added])
    expect(eventos(kind: 'agents').second[:params]).to include(name: agente.available_name, from: 'agent', to: 'administrator')
  end

  it 'funciones: dice cuáles se encendieron y cuáles se apagaron' do
    account.enable_features!('channel_email')
    account.disable_features!('macros')
    como(gestor) do
      account.enable_features('macros')
      account.disable_features('channel_email')
      account.save!
    end

    evento = eventos(kind: 'features').first
    expect(evento).to include(event: 'features_changed', user: gestor.available_name)
    expect(evento[:params]).to eq(on: ['macros'], off: ['channel_email'])
  end

  it 'la cuenta: suspender, reactivar y cambiar el nombre' do
    como(gestor) { account.update!(status: :suspended) }
    como(gestor) { account.update!(status: :active) }
    como(gestor) { account.update!(name: 'Grúas del Norte') }

    nombre, reactivar, suspender = eventos(kind: 'account').first(3)
    expect(suspender).to include(event: 'account_status', params: { to: 'suspended' })
    expect(reactivar).to include(event: 'account_status', params: { to: 'active' })
    expect(nombre).to include(event: 'account_changed', params: include(fields: ['name'], to: 'Grúas del Norte'))
  end

  it 'deja fuera la sincronización de plantillas; los accesos solo si se piden' do
    inbox = create(:inbox, account: account)
    inbox.update!(name: 'Ventas')
    Enterprise::AuditLog.create!(auditable: inbox, associated: account, action: 'update',
                                 audited_changes: { 'message_templates' => [[], [{ 'name' => 'x' }]] })
    Enterprise::AuditLog.create!(auditable: gestor, associated: account, action: 'sign_in', user: gestor)

    expect(eventos(kind: 'inboxes').pluck(:event)).to eq(%w[inbox_changed inbox_created])
    expect(eventos(kind: 'inboxes').first[:params]).to include(name: 'Ventas', fields: ['name'])
    expect(eventos.pluck(:kind)).not_to include('access')
    expect(eventos(kind: 'access').first).to include(event: 'sign_in')
  end

  it 'un agente que entra a una bandeja dice quién y a cuál' do
    inbox = create(:inbox, account: account, name: 'Ventas')
    agente = create(:user, account: account)
    como(gestor) { create(:inbox_member, inbox: inbox, user: agente) }

    evento = eventos(kind: 'inboxes').first
    expect(evento).to include(event: 'inbox_member_added', params: { name: agente.available_name, inbox: 'Ventas' })
  end

  it 'pagina hacia atrás de 50 en 50 y filtra por fecha' do
    licencia = create(:account_license, account: account, max_agents: 1)
    55.times { Licenses::AgentIncrease.new(license: licencia, add: 1).perform }

    primera = described_class.new(account: account).perform
    expect(primera[:events].size).to eq(50)
    segunda = described_class.new(account: account, before: primera[:next_before]).perform
    expect(segunda[:events].size).to eq(6)
    expect(segunda[:next_before]).to be_nil
    expect(eventos(from: 1.day.from_now.to_date.iso8601)).to be_empty
  end
end
