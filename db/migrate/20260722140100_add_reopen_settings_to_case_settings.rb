# @tickets_cases — Ajustes de reapertura por cuenta.
# `reopen_window_days`: días desde el cierre en los que un agente asignado puede
# reabrir. Pasada la ventana solo el admin. `reopen_on_customer_reply` lo
# consume el listener de la Fase 5 (todavía no implementado).
class AddReopenSettingsToCaseSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :case_settings, :reopen_window_days, :integer, default: 30, null: false
    add_column :case_settings, :reopen_on_customer_reply, :boolean, default: true, null: false
  end
end
