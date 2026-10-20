# frozen_string_literal: true

# @tickets_cases — Plan-Clase-Proyecto P1: datos del proyecto en columnas reales de
# case_tickets (solo los usa la clase Proyecto). El monto usa `currency` (la moneda
# de la cuenta, como una oportunidad). `progress` es el avance capturado a mano; en
# la P2 se calcula solo con los casos hijos y los hitos.
class AddProjectToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    change_table :case_tickets, bulk: true do |t|
      t.date    :project_start_on
      t.date    :project_due_on
      t.decimal :budget_hours, precision: 8, scale: 2
      t.decimal :budget_amount, precision: 14, scale: 2
      t.integer :progress
    end
    add_index :case_tickets, :project_due_on, where: 'project_due_on IS NOT NULL'
  end
end
