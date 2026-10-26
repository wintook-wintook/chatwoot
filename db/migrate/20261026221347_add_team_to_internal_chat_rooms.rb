# feat/chat_interno — los grupos del chat interno SON los equipos de Chatwoot (pedido del
# 26/10/2026): una sala por equipo, con los miembros del equipo. Reemplaza los grupos a mano.
class AddTeamToInternalChatRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :internal_chat_rooms, :team_id, :bigint
    add_index :internal_chat_rooms, [:account_id, :team_id], unique: true, where: 'team_id IS NOT NULL'
  end
end
