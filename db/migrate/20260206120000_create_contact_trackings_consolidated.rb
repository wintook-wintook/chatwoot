# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking - MIGRACIÓN CONSOLIDADA
# ================================================================================
# Migración: CreateContactTrackingsConsolidated
# Descripción: Crea la tabla contact_trackings con todos los campos necesarios
#              (consolida 7 migraciones de desarrollo en una sola para producción)
# Fecha: 2026-02-06
#
# Migraciones originales consolidadas:
#   1. 20251110212133_create_contact_trackings
#   2. 20251110223435_add_account_id_to_contact_trackings
#   3. 20251128000306_add_whatsapp_fields_to_contact_trackings
#   4. 20251216131723_add_sentiment_analysis_to_contact_trackings
#   5. 20260105104556_add_unique_active_tracking_per_contact
#   6. 20260123223823_add_complementary_prompt_to_contact_trackings
#   7. 20260130100000_add_paused_at_to_contact_trackings
# ================================================================================

class CreateContactTrackingsConsolidated < ActiveRecord::Migration[7.0]
  def up
    create_table :contact_trackings do |t|
      # Referencias
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :conversation, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true

      # Campos principales
      t.string :objective, null: false
      t.datetime :scheduled_for, null: false, index: true
      t.integer :max_attempts, default: 3, null: false
      t.integer :attempt_count, default: 0, null: false
      t.integer :interval_days

      # Contexto e IA
      t.text :ai_context
      t.integer :quote_id
      t.text :complementary_prompt

      # Estado y tracking
      t.string :status, default: 'pending', null: false, index: true
      t.datetime :last_attempt_at
      t.text :last_message_sent
      t.string :last_error
      t.datetime :paused_at

      # WhatsApp
      t.json :whatsapp_templates, default: []
      t.integer :retry_interval_value, default: 30
      t.string :retry_interval_unit, default: 'minutes'

      # Análisis de sentimiento
      t.jsonb :last_sentiment_analysis, default: {}
      t.integer :response_adjustments_count, default: 0, null: false

      t.timestamps
    end

    # Índices compuestos para optimizar búsquedas
    add_index :contact_trackings, [:conversation_id, :inbox_id]
    add_index :contact_trackings, [:status, :scheduled_for]

    # Índice para búsquedas por sentimiento
    add_index :contact_trackings,
              "(last_sentiment_analysis->>'sentiment')",
              name: 'index_contact_trackings_on_sentiment',
              using: :btree

    # Índice único: solo un tracking activo por contacto
    add_index :contact_trackings,
              [:contact_id, :status],
              unique: true,
              where: "status IN ('pending', 'scheduled', 'active', 'paused')",
              name: 'index_unique_active_tracking_per_contact'
  end

  def down
    drop_table :contact_trackings
  end
end
