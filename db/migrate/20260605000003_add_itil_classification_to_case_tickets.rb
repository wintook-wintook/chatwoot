# frozen_string_literal: true

# @tickets_cases 2B — Clasificación ITIL en el ticket:
#   ticket_kind (Incidente/Solicitud/Problema/Cambio/Consulta), impact, urgency,
#   y FKs a servicio afectado y categoría. Columnas al final (no se reordena nada).
class AddItilClassificationToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :ticket_kind,         :integer, null: false, default: 1 # service_request
    add_column :case_tickets, :impact,              :integer
    add_column :case_tickets, :urgency,             :integer
    add_column :case_tickets, :affected_service_id, :bigint
    add_column :case_tickets, :category_id,         :bigint

    add_index :case_tickets, [:account_id, :ticket_kind]
    add_index :case_tickets, :affected_service_id
    add_index :case_tickets, :category_id
  end
end
