# frozen_string_literal: true

# @tickets_cases F7 — Push en tiempo real de Google Calendar (plan §12.6).
#
# Se agregan columnas a `user_calendar_integrations`, que ya comparte el módulo
# de seguimientos: NO se toca nada de lo existente.
#
#   push_channel_id     uuid del canal que registramos
#   push_resource_id    id del recurso que devuelve Google (para channels.stop)
#   push_channel_token  secreto que autentica el ping (el endpoint es público)
#   push_expires_at     caducidad que informa Google → la usa el renovador
#   sync_token          cursor incremental de events.list
#
# Un canal por INTEGRACIÓN, nunca uno por reunión: eso agotaría la cuota (§12.7.7).
class AddPushChannelToUserCalendarIntegrations < ActiveRecord::Migration[7.0]
  def change
    add_column :user_calendar_integrations, :push_channel_id, :string
    add_column :user_calendar_integrations, :push_resource_id, :string
    add_column :user_calendar_integrations, :push_channel_token, :string
    add_column :user_calendar_integrations, :push_expires_at, :datetime
    add_column :user_calendar_integrations, :sync_token, :string

    # El ping llega con el id de canal: hay que resolver la integración por ahí.
    add_index :user_calendar_integrations, :push_channel_id, unique: true
    # El renovador barre por caducidad.
    add_index :user_calendar_integrations, :push_expires_at
  end
end
