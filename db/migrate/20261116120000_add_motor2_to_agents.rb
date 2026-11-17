# frozen_string_literal: true

# Motor 2.0 de Agentes a medida (docs/vault-tickets/implementacion/Plan-Motor-Agentes.md §11.11).
# Comparte las tablas del 1.0: solo columnas nuevas. «1» = motor de siempre (por omisión).
# Tablas propias: pruebas guardadas, reportes a Kontrolya y versiones de la ficha 2.0 (aparte de
# tracking_template_versions, que versiona los campos del 1.0 con su propio callback).
class AddMotor2ToAgents < ActiveRecord::Migration[7.0]
  def change
    add_column :tracking_templates, :engine, :string, default: '1', null: false
    add_column :tracking_templates, :motor2, :jsonb, default: {}, null: false
    add_column :contact_trackings, :motor2_state, :jsonb, default: {}, null: false
    create_tests
    create_reports
    create_versions
  end

  private

  def create_tests
    create_table :motor2_tests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_template, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :turns, default: [], null: false # [{role: 'user'|'assistant', content:}]
      t.text :expected # lo que debe (o no debe) hacer
      t.string :origin, default: 'manual', null: false # manual | correction
      t.jsonb :last_run, default: {}, null: false # { ok:, reply:, reason:, at: }
      t.timestamps
    end
  end

  def create_reports
    create_table :motor2_reports do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_template, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false # missing_skill | ignored
      t.string :status, default: 'new', null: false # new | reviewing | fixed | rejected
      t.jsonb :turns, default: [], null: false
      t.text :reply
      t.text :expected
      t.text :diagnosis
      t.jsonb :trace, default: {}, null: false
      t.datetime :fixed_at
      t.timestamps
    end
    add_index :motor2_reports, :status
  end

  def create_versions
    create_table :motor2_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tracking_template, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :version, null: false
      t.string :source, default: 'manual', null: false # manual | trainer | restore | create | convert
      t.string :note
      t.jsonb :snapshot, default: {}, null: false
      t.datetime :created_at, null: false
    end
    add_index :motor2_versions, [:tracking_template_id, :version], unique: true
  end
end
