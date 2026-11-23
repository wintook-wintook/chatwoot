# frozen_string_literal: true

# Cobranza (agente listo «Cobranza»): la cartera de la empresa en un solo formato, venga de un Excel/CSV subido o, más
# adelante, de la sincronización con su sistema administrativo (cualquiera: cada uno es otra «fuente» del mismo corte).
#
#   receivable_imports    cada corte aplicado (de qué fuente, quién, qué cambió)
#   receivable_customers  el cliente del sistema administrativo (clave, RFC…) ligado a su organización y contacto
#   receivables           cada factura (documento) con saldo; abierta, pagada o en aclaración
#   receivable_events     lo que pasó entre cortes: nueva, abono, pagada, reabierta
#   payment_promises      «pago el viernes»: la promesa de pago y si se cumplió
#   payment_claims        «ya pagué»: el comprobante que valida el cobrador
class CollectionsReceivables < ActiveRecord::Migration[7.0]
  def change
    imports_table
    customers_table
    receivables_table
    events_table
    promises_table
    claims_table
  end

  private

  def imports_table
    create_table :receivable_imports do |t|
      t.references :account, null: false, foreign_key: true
      t.bigint :user_id
      t.string :source, null: false, default: 'upload'
      t.string :source_ref
      t.jsonb :stats, null: false, default: {}
      t.timestamps
    end
  end

  def customers_table
    create_table :receivable_customers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :external_key, null: false
      t.string :name, null: false
      t.string :rfc
      t.string :contact_name
      t.string :phone
      t.string :email
      t.bigint :collector_id
      t.bigint :organization_id
      t.bigint :contact_id
      t.string :link_status, null: false, default: 'pending'
      t.datetime :last_contacted_at
      t.integer :touches, null: false, default: 0
      t.timestamps
    end
    add_index :receivable_customers, %i[account_id external_key], unique: true
    add_index :receivable_customers, %i[account_id link_status]
    add_index :receivable_customers, :contact_id
  end

  def receivables_table
    create_table :receivables do |t|
      t.references :account, null: false, foreign_key: true
      t.references :receivable_customer, null: false, foreign_key: { on_delete: :cascade }
      t.string :source, null: false, default: 'upload'
      t.string :folio, null: false
      t.date :issued_on
      t.date :due_on, null: false
      t.decimal :total, precision: 14, scale: 2
      t.decimal :balance, precision: 14, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: 'MXN'
      t.string :status, null: false, default: 'open'
      t.datetime :paid_at
      t.datetime :disputed_at
      t.datetime :claimed_at
      t.bigint :last_import_id
      t.timestamps
    end
    add_index :receivables, %i[account_id receivable_customer_id folio], unique: true, name: 'index_receivables_on_customer_folio'
    add_index :receivables, %i[account_id status due_on]
  end

  def events_table
    create_table :receivable_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :receivable, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :receivable_import_id
      t.string :kind, null: false
      t.decimal :amount, precision: 14, scale: 2
      t.datetime :created_at, null: false
    end
  end

  def promises_table
    create_table :payment_promises do |t|
      t.references :account, null: false, foreign_key: true
      t.references :receivable_customer, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :conversation_id
      t.date :promised_on, null: false
      t.decimal :amount, precision: 14, scale: 2
      t.string :status, null: false, default: 'pending'
      t.string :note
      t.timestamps
    end
  end

  def claims_table
    create_table :payment_claims do |t|
      t.references :account, null: false, foreign_key: true
      t.references :receivable_customer, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :conversation_id
      t.bigint :message_id
      t.decimal :amount, precision: 14, scale: 2
      t.string :note
      t.string :status, null: false, default: 'pending'
      t.bigint :reviewed_by_id
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
