# frozen_string_literal: true

# Asistente (Dali) — «Arma tu cuenta con Dali»: con el giro del negocio propone los tipos de caso,
# sus etapas y los motivos de cierre (Cases::QuickSetup). Solo administradores. Se incluye en
# Assistant::Tools; lo confirmado lo hace Assistant::SetupRunner.
module Assistant::SetupTools
  SETUP_PROPOSAL_TOOLS = %w[propose_account_setup].freeze
  CLASS_NAMES = { 'commercial' => 'ventas', 'support' => 'servicio', 'work_order' => 'orden de trabajo',
                  'project' => 'proyecto' }.freeze

  def prepare_account_setup(args)
    raise ArgumentError, 'Armar los tipos de caso y sus etapas lo hace un administrador de la cuenta.' unless @grant.admin?

    setup = quick_setup(args)
    raise ArgumentError, setup.problems.first if setup.problems.any?

    payload = { 'types' => setup.types.map(&:stringify_keys), 'reasons' => setup.reasons,
                'retire_defaults' => args['retire_defaults'] == true }
    [payload, { 'rows' => setup_rows(setup) }]
  end

  private

  def quick_setup(args)
    Cases::QuickSetup.new(@account, types: args['case_types'], reasons: { 'won' => args['won_reasons'], 'lost' => args['lost_reasons'] },
                                    retire_defaults: args['retire_defaults'] == true)
  end

  def setup_rows(setup)
    rows = setup.types.map { |t| ["#{t[:name]} (#{CLASS_NAMES[t[:case_class]]})", t[:stages].join(' → ')] }
    rows << ['Motivos de venta ganada', setup.reasons['won'].join(', ')] if setup.reasons['won'].present?
    rows << ['Motivos de venta perdida', setup.reasons['lost'].join(', ')] if setup.reasons['lost'].present?
    retire = setup.defaults_to_retire
    rows << ['Se retiran (sin casos)', retire.join(', ')] if retire.any?
    rows
  end
end
