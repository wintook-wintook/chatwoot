# CrmZeus Q3.1 — parámetros de CrmZeus por cuenta (en CRMZeus eran preferencias de la empresa).
# Un solo renglón por cuenta; se crea la primera vez que se guarda.
class CreateCrmSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      # VALIDAR_FECHA_ENTREGA de master2: si la cotización exige fecha de entrega (apagado por omisión).
      t.boolean :require_delivery_date, null: false, default: false
      t.timestamps
    end
  end
end
