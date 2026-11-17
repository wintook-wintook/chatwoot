# frozen_string_literal: true

# Probador de agentes (Agentes IA › Probador): lotes de pruebas, sus corridas y la bitácora de
# correcciones. Sirve a los agentes del Motor 1.0 y 2.0 (Plan-Motor-Agentes.md §11.13).
# Las correcciones de cada 👎 van en un lote por agente y por día (tracking_template_id + day); una
# corrida puede juntar las pruebas de varios lotes (case_ids, label).
class CreateAgentTester < ActiveRecord::Migration[7.0]
  def change
    create_table :agent_test_batches do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :tracking_template, foreign_key: true
      t.date :day
      t.string :name, null: false
      t.timestamps
    end
    add_index :agent_test_batches, [:tracking_template_id, :day]

    create_table :agent_test_cases do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent_test_batch, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :messages, default: [], null: false # lo que escribe el cliente, en orden
      t.text :expected
      t.timestamps
    end

    create_runs
    create_logs
  end

  private

  def create_runs
    create_table :agent_test_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent_test_batch, null: false, foreign_key: true
      t.references :tracking_template, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status, default: 'queued', null: false # queued | running | done | failed
      t.integer :total, default: 0, null: false
      t.integer :passed, default: 0, null: false
      t.jsonb :results, default: [], null: false
      t.jsonb :case_ids, default: [], null: false # vacío = las del lote
      t.string :label
      t.datetime :finished_at
      t.timestamps
    end
  end

  def create_logs
    create_table :agent_test_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_template, foreign_key: true
      t.references :user, foreign_key: true
      t.bigint :conversation_id
      t.bigint :message_id
      t.string :engine, null: false
      t.string :kind, null: false # prompt | content | model | engine | question
      t.text :feedback
      t.text :reply
      t.jsonb :diagnosis, default: {}, null: false
      t.bigint :motor2_report_id
      t.timestamps
    end
    add_index :agent_test_logs, [:account_id, :created_at]
  end
end
