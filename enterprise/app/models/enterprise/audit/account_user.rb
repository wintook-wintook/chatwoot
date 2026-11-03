module Enterprise::Audit::AccountUser
  extend ActiveSupport::Concern

  included do
    audited only: [
      :availability,
      :role,
      :account_id,
      :inviter_id,
      :user_id
    ], on: [:create, :update, :destroy], associated_with: :account # destroy: feat/licencias F6.4 (quitar agente)
  end
end
