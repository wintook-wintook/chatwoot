# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Tienes avisos importantes» en Mi día
# ================================================================================
# GET /api/v1/accounts/:account_id/case_notices → avisos sin leer del agente con su
# peso (Cases::MyDayNotices). «Enterado» usa PATCH /notifications/:id (la campanita).
# ================================================================================

class Api::V1::Accounts::CaseNoticesController < Api::V1::Accounts::BaseController
  def index
    render json: { notices: Cases::MyDayNotices.new(user: current_user, account: Current.account).call }
  end
end
