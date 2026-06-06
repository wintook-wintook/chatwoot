# frozen_string_literal: true

# @tickets_cases 2H — enlace ticket → artículo de la base de conocimiento.
class AddKbArticleToCaseTickets < ActiveRecord::Migration[7.0]
  def change
    add_column :case_tickets, :kb_article_id, :bigint
    add_index  :case_tickets, :kb_article_id
  end
end
