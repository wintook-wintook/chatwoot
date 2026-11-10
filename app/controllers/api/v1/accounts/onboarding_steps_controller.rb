# frozen_string_literal: true

# «Primeros pasos» (Inicio): GET …/onboarding_steps → { steps: [{ key, done }], done, total }
class Api::V1::Accounts::OnboardingStepsController < Api::V1::Accounts::BaseController
  def index
    steps = Onboarding::Steps.new(account: Current.account, user: current_user, grant: access_grant).call
    render json: { steps: steps, done: steps.count { |s| s[:done] }, total: steps.size }
  end
end
