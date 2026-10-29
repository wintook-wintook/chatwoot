# Plan-Trabajo-Campo R3 — despacho: habilidades y zona de cada técnico (por cuenta).
class AddFieldProfileToAccountUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :account_users, :field_profile, :jsonb, null: false, default: {}
  end
end
