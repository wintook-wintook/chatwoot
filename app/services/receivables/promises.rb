# frozen_string_literal: true

# Cobranza — las promesas de pago contra la cartera (después de cada corte y cada día):
#   cumplida (kept)    ya no debe nada vencido a la fecha prometida
#   incumplida (broken) pasó la fecha y sigue debiendo → el agente lo vuelve a buscar
module Receivables::Promises
  module_function

  def reconcile(account, today: Date.current)
    account_promises(account).find_each do |promise|
      owing = promise.receivable_customer.receivables.collectable.exists?(['due_on <= ?', promise.promised_on])
      next promise.update!(status: 'kept') unless owing

      promise.update!(status: 'broken') if promise.promised_on < today
    end
  end

  def account_promises(account) = PaymentPromise.pending.where(account_id: account.id).includes(:receivable_customer)

  # ¿Tiene una promesa vigente (no se le cobra hasta el día siguiente a la fecha)?
  def active?(customer, today: Date.current)
    customer.payment_promises.pending.exists?(['promised_on >= ?', today])
  end
end
