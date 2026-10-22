# frozen_string_literal: true

# diag/llamadas_whatsapp (F1) — llamadas de voz de WhatsApp Cloud API.
#
# Una fila por llamada (entrante o saliente). El audio no pasa por aquí: va directo del
# navegador del agente a Meta; esto guarda el estado, quién la tomó, cuánto duró y la
# señalización (SDP) en `meta`. Junta en una las 4 migraciones de la v4.19
# (create_calls + ring_state + los dos índices).
#
# `provider` deja el 0 para Twilio aunque aquí solo se use WhatsApp: si un día se trae
# Twilio, el enum no cambia de significado.
# Plan: docs/llamadas_whatsapp_plan.md
class CreateCalls < ActiveRecord::Migration[7.0]
  def change
    create_table :calls do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :message_id
      t.bigint :accepted_by_agent_id
      t.string :provider_call_id, null: false
      t.integer :provider, null: false, default: 1
      t.integer :direction, null: false
      t.string :status, null: false, default: 'ringing'
      t.datetime :started_at
      t.integer :duration_seconds
      t.string :end_reason
      t.jsonb :meta, null: false, default: {}
      # A quién se le hizo sonar y el intento de timeout en curso; aparte de `meta` para
      # que escribir `meta` desde una copia vieja no lo borre.
      t.jsonb :ring_state, null: false, default: {}

      t.timestamps
    end

    add_call_indexes
  end

  private

  def add_call_indexes
    add_index :calls, [:provider, :provider_call_id], unique: true
    add_index :calls, [:account_id, :conversation_id]
    add_index :calls, [:account_id, :contact_id]
    add_index :calls, [:account_id, :created_at]
    add_index :calls, :message_id
    # El barrido del timeout (cada 30 s) solo busca las que siguen sonando.
    add_index :calls, [:provider, :created_at], where: "status = 'ringing'",
                                                name: 'index_calls_ringing_on_provider_and_created_at'
  end
end
