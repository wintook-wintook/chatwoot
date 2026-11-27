# frozen_string_literal: true

# Cobranza — el cobrador revisa un «ya pagué» (Cobranza › Comprobantes):
#   validado  → sus facturas siguen sin cobrarse hasta que el corte las traiga pagadas
#   rechazado → se vuelven a cobrar y queda una nota en la conversación
module Receivables::Claims
  module_function

  def review!(claim, user, valid, note: nil)
    claim.update!(status: valid ? 'validated' : 'rejected', reviewed_by: user, reviewed_at: Time.current,
                  note: [claim.note, note.presence].compact.join(' · ').first(250))
    return if valid

    claim.receivable_customer.receivables.where(status: 'open').update_all(claimed_at: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    conversation = Conversation.find_by(id: claim.conversation_id)
    return unless conversation

    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                                  content: "🧾 #{user.name} rechazó el comprobante#{": #{note}" if note.present?}. Se le vuelve a cobrar.")
  end
end
