# frozen_string_literal: true

# @tickets_cases — Modo simple (osTicket) vs ITIL
# Ajustes generales del módulo por cuenta. `itil_enabled = false` (default) = modo
# simple estilo osTicket: la UI oculta estados/campos ITIL. El backend sigue
# permitiendo todo; el modo es una capa de presentación.
class CreateCaseSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :case_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :itil_enabled, null: false, default: false

      t.timestamps
    end
  end
end
