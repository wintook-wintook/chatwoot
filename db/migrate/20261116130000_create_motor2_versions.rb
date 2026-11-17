# frozen_string_literal: true

# Motor 2.0 — versiones de la ficha 2.0 (aparte de tracking_template_versions, que versiona los
# campos del 1.0 con su propio callback).
class CreateMotor2Versions < ActiveRecord::Migration[7.0]
  def change
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
