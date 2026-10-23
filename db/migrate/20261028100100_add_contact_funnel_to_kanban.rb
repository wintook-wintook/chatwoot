# frozen_string_literal: true

# Embudo de contactos — todo lo nuevo se agrega apagado o vacío: los tableros que
# ya existen se siguen viendo y comportando igual.
class AddContactFunnelToKanban < ActiveRecord::Migration[7.0]
  def change
    change_table :kanban_type_processes, bulk: true do |t|
      t.boolean :auto_move, default: false, null: false
      t.boolean :ai_move, default: false, null: false
      t.jsonb :entry_inbox_ids, default: [], null: false
      t.integer :cold_after_days
      t.integer :discard_after_days
    end

    change_table :kanban_processes, bulk: true do |t|
      t.jsonb :entry_triggers, default: [], null: false
      t.text :ai_criteria
      t.integer :stage_kind, default: 0, null: false
      t.bigint :convert_case_type_id
    end

    change_table :conversations, bulk: true do |t|
      t.datetime :kanban_moved_at
      t.bigint :kanban_moved_by_id
      t.string :kanban_move_source
      t.string :kanban_move_reason
    end

    create_table :kanban_moves do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :kanban_type_process_id, null: false
      t.bigint :from_process_id
      t.bigint :to_process_id
      t.string :source, null: false
      t.string :reason
      t.bigint :user_id
      t.datetime :created_at, null: false
      t.index %i[account_id kanban_type_process_id created_at], name: 'index_kanban_moves_on_account_board_created'
      t.index :conversation_id
    end
  end
end
