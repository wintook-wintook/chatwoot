# frozen_string_literal: true

require 'rails_helper'

# «Arma tu cuenta con Dali»: tipos de caso con las etapas del negocio y motivos de cierre.
RSpec.describe Assistant::SetupTools do
  let(:account) { create(:account, locale: 'es') }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:tools) { Assistant::Tools.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:executor) { Assistant::Executor.new(account: account, user: user, grant: admin, zone: Time.zone) }
  let(:args) do
    { 'case_types' => [{ 'name' => 'Venta de paneles', 'case_class' => 'commercial',
                         'stages' => ['Contacto', 'Visita técnica', 'Cotización', 'Negociación', 'Cierre', 'Ganada'] },
                       { 'name' => 'Instalación', 'case_class' => 'work_order', 'stages' => ['Por agendar', 'Instalando'] }],
      'lost_reasons' => ['Precio', 'Tiempo de entrega'], 'retire_defaults' => true }
  end

  it 'propone con una tarjeta y, al confirmar, crea los tipos con sus etapas y cubre todos los estados' do # rubocop:disable RSpec/MultipleExpectations
    proposal = tools.call('propose_account_setup', args)[:proposal]
    expect(proposal['type']).to eq('account_setup')
    expect(proposal['labels']['rows'].first).to eq(['Venta de paneles (ventas)', 'Contacto → Visita técnica → Cotización → Negociación'])
    expect(CaseType.where(account: account, name: 'Venta de paneles')).to be_empty # la propuesta no hace nada

    result = executor.call('account_setup', proposal['payload'])
    expect(result['label']).to include('2 tipos de caso')

    sale = account.case_types.find_by!(name: 'Venta de paneles')
    labels = sale.case_type_columns.ordered.pluck(:label)
    expect(labels.first(4)).to eq(['Contacto', 'Visita técnica', 'Cotización', 'Negociación'])
    expect(labels).to include('Ganada', 'Perdida')
    expect(sale.case_type_columns.flat_map(&:statuses).uniq).to match_array(CaseTicket.statuses.keys)

    expect(account.case_outcome_reasons.where(outcome: 'lost').pluck(:label)).to include('Tiempo de entrega')
    expect(account.case_outcome_reasons.where(outcome: 'lost', label: 'Precio').count).to eq(1) # no repite
    expect(account.case_types.active.pluck(:name)).not_to include('Soporte') # los de fábrica sin casos se retiran
  end

  it 'la misma propuesta dos veces en un turno deja una sola tarjeta' do
    expect(tools.call('propose_account_setup', args)[:proposal]).to be_present
    second = tools.call('propose_account_setup', args)
    expect(second[:proposal]).to be_nil
    expect(second[:result]).to include(already_proposed: true)
  end

  it 'no repite un tipo que ya existe' do
    account.case_types.create!(name: 'Instalación')
    expect(tools.call('propose_account_setup', args)[:result][:error]).to include('Ya hay un tipo de caso llamado «Instalación»')
  end

  it 'solo administradores' do
    au = account.account_users.find_by(user: user)
    au.update!(role: :agent)
    agent_grant = Access::Grant.for(au)
    agent_tools = Assistant::Tools.new(account: account, user: user, grant: agent_grant, zone: Time.zone)
    expect(agent_tools.call('propose_account_setup', args)[:result][:error]).to include('administrador')

    agent_executor = Assistant::Executor.new(account: account, user: user, grant: agent_grant, zone: Time.zone)
    expect { agent_executor.call('account_setup', { 'types' => args['case_types'] }) }.to raise_error(Assistant::Executor::Refused)
  end
end
