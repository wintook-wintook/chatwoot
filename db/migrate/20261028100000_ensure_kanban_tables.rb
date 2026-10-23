# frozen_string_literal: true

# KANBAN0725 — Las tablas del tablero de conversaciones están en schema.rb pero su
# migración nunca se versionó. Esta las crea donde falten (desarrollo, pruebas,
# instalaciones nuevas) y no toca nada donde ya existen (producción).
class EnsureKanbanTables < ActiveRecord::Migration[7.0]
  def up
    create_table :kanban_type_processes, if_not_exists: true do |t|
      t.string :process_name, null: false
      t.boolean :default, default: false
      t.boolean :is_system, default: false
      t.bigint :account_id, null: false
      t.datetime :created_at
      t.datetime :updated_at
      t.index :account_id, name: 'index_kanban_type_processes_on_account_id'
      t.index :account_id, name: 'unique_default_kanban_type_process_per_account', unique: true, where: '("default" = true)'
    end

    create_table :kanban_processes, if_not_exists: true do |t|
      t.string :type_process_name, null: false
      t.boolean :default, default: false
      t.boolean :is_system, default: false
      t.integer :position, default: 0
      t.bigint :account_id, null: false
      t.bigint :kanban_type_process_id, null: false
      t.timestamps
      t.index :account_id, name: 'index_kanban_processes_on_account_id'
      t.index :kanban_type_process_id, name: 'index_kanban_processes_on_kanban_type_process_id'
    end

    add_column :conversations, :kanban_type_process_id, :bigint, if_not_exists: true
    add_column :conversations, :kanban_process_id, :bigint, if_not_exists: true
    add_index :conversations, :kanban_type_process_id, if_not_exists: true
    add_index :conversations, :kanban_process_id, if_not_exists: true

    add_foreign_key :kanban_type_processes, :accounts, if_not_exists: true
    add_foreign_key :kanban_processes, :accounts, if_not_exists: true
    add_foreign_key :kanban_processes, :kanban_type_processes, if_not_exists: true
    add_foreign_key :conversations, :kanban_type_processes, if_not_exists: true
    add_foreign_key :conversations, :kanban_processes, if_not_exists: true
  end

  # Son tablas de clientes en uso: nunca se borran desde aquí.
  def down; end
end
