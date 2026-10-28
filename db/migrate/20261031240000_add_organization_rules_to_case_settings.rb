# Plan-Organizaciones O3 — qué pasa a una organización a prospecto o a cliente sola.
# Las cuentas que ya existen quedan con todo apagado ({}); las nuevas nacen con lo de
# Organizations::StageRules::NEW_ACCOUNT_DEFAULTS encendido (default de la columna).
class AddOrganizationRulesToCaseSettings < ActiveRecord::Migration[7.0]
  NEW_ACCOUNT_DEFAULTS = {
    prospect_on_opportunity: true, prospect_on_quote_sent: false,
    customer_on_won: true, customer_on_contract: true, customer_on_quote_accepted: false
  }.freeze

  def up
    add_column :case_settings, :organization_rules, :jsonb, null: false, default: {}
    # Las cuentas sin fila todavía: se crea con todo apagado, como las demás existentes.
    execute <<~SQL.squish
      INSERT INTO case_settings (account_id, created_at, updated_at)
      SELECT accounts.id, NOW(), NOW() FROM accounts
      WHERE NOT EXISTS (SELECT 1 FROM case_settings WHERE case_settings.account_id = accounts.id)
    SQL
    change_column_default :case_settings, :organization_rules, from: {}, to: NEW_ACCOUNT_DEFAULTS
  end

  def down
    remove_column :case_settings, :organization_rules
  end
end
