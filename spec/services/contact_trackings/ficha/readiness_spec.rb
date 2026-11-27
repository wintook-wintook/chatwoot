# frozen_string_literal: true

require 'rails_helper'

# feat/ficha_agente_ia — ¿listo para atender? y activar en su canal.
RSpec.describe ContactTrackings::Ficha::Readiness do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:template) { create(:tracking_template, account: account, inbox: inbox, ai_context: nil) }
  let(:ofertas) { [{ key: 'canned_response:PATITAS', kind: 'canned', name: 'PATITAS', warning: '2 sin vectorizar' }] }

  it 'dice qué falta, cada cosa con su arreglo' do
    lista = described_class.new(account, offers: ofertas, template: template).call.index_by { |i| i[:key] }

    expect(lista['openai']).to include(status: 'error', fix: 'integrations')
    expect(lista['channel']).to include(status: 'ok')
    expect(lista['resource:canned_response:PATITAS']).to include(status: 'warn', fix: 'canned')
    expect(lista['context']).to include(status: 'warn', fix: 'context')
    expect(lista['assignment']).to include(status: 'warn', fix: 'activate')
  end

  it 'activar crea UNA automatización que lo asigna en su canal' do
    servicio = described_class.new(account, offers: [], template: template)

    expect { servicio.activate! }.to change(account.automation_rules, :count).by(1)
    regla = account.automation_rules.last
    expect(regla.event_name).to eq('conversation_created')
    expect(regla.conditions.first).to include('attribute_key' => 'inbox_id', 'values' => [inbox.id])
    expect(regla.actions.first).to eq('action_name' => 'assign_tracking_template', 'action_params' => [template.id])

    expect { described_class.new(account, offers: [], template: template).activate! }.not_to change(account.automation_rules, :count)
    expect(described_class.new(account, offers: [], template: template).call.find { |i| i[:key] == 'assignment' }[:status]).to eq('ok')
  end

  it 'sin canal no se puede activar' do
    sin_canal = create(:tracking_template, account: account, inbox: nil)
    expect { described_class.new(account, offers: [], template: sin_canal).activate! }.to raise_error(ArgumentError)
  end
end
