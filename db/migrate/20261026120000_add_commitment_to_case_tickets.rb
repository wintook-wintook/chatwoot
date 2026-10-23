# @tickets_cases — Plan-Metricas-Comercial: oportunidad «comprometida por el
# cliente» («esta semana te pago»). `committed_at` = cuándo se marcó (nil = no
# comprometida); la fecha comprometida es la misma `expected_close_at` (una sola
# fecha: marcada, deja de ser estimado y pasa a ser la promesa del cliente).
class AddCommitmentToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :committed_at, :datetime
    add_column :case_tickets, :commit_note, :text
    add_index :case_tickets, %i[account_id committed_at], where: 'committed_at IS NOT NULL',
                                                          name: 'index_case_tickets_on_account_committed'
  end
end
