# frozen_string_literal: true

# Asistente (Dali) — arma los tipos de caso confirmados («Arma tu cuenta con Dali»). Se incluye en
# Assistant::Executor; vuelve a revisar que sea administrador.
module Assistant::SetupRunner
  def run_account_setup(payload)
    raise Assistant::Executor::Refused, 'Esto lo hace un administrador de la cuenta.' unless @grant.admin?

    result = Cases::QuickSetup.new(@account, types: payload['types'], reasons: payload['reasons'],
                                             retire_defaults: payload['retire_defaults'] == true).call
    done("Listo: #{result[:created].size} tipos de caso con sus etapas (#{result[:created].join(', ')})", "#{base}/tickets/types")
  rescue Cases::QuickSetup::Invalid => e
    raise Assistant::Executor::Refused, e.message
  end
end
