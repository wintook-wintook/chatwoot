# frozen_string_literal: true

# @tickets_cases — motivo de la pospuesta (catálogo `case_outcome_reasons` con
# outcome = postponed). Es el motivo de la pospuesta VIGENTE: se limpia al
# retomarla; la historia queda en el evento `postponed`.
class AddPostponeReasonToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :postpone_reason_id, :bigint
    add_foreign_key :case_tickets, :case_outcome_reasons, column: :postpone_reason_id, on_delete: :nullify
  end
end
