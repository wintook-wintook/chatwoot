# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Mi resumen» (página Inicio)
# ================================================================================
# GET /api/v1/accounts/:account_id/my_summary → conversaciones, casos y números de
# la semana del agente (Cases::MySummary). Mi día y los avisos tienen su propia API.
# ================================================================================

class Api::V1::Accounts::MySummaryController < Api::V1::Accounts::BaseController
  def show
    render json: Cases::MySummary.new(user: current_user, account: Current.account).call
  end
end
