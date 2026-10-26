# frozen_string_literal: true

# Embudo de contactos — cada vez que una conversación cambia de columna (a mano,
# por regla, por la IA o por una automatización) se anota quién la movió y por
# qué, en la conversación (lo que muestra la tarjeta) y en kanban_moves (historia
# y métricas). Va en el modelo para cubrir todas las vías de mover una tarjeta
# sin tocar los endpoints que ya usa el tablero.
#
# Quien mueve por código pone `kanban_move_context = { source:, reason:, user_id: }`
# antes de guardar; sin contexto, con usuario en la petición es «manual» y sin él
# es «automation» (p. ej. la acción assign_kanban_type_process).
module KanbanFunnelTrackable
  extend ActiveSupport::Concern

  included do
    attr_accessor :kanban_move_context

    before_save :stamp_kanban_move, if: :will_save_change_to_kanban_process_id?
    after_save :remember_kanban_move, if: :saved_change_to_kanban_process_id?
    after_commit :log_kanban_move
  end

  def kanban_moved_by_person?
    kanban_move_source == 'manual'
  end

  private

  def stamp_kanban_move
    context = kanban_move_context || {}
    self.kanban_moved_at = Time.current
    self.kanban_move_source = context[:source] || (Current.user ? 'manual' : 'automation')
    self.kanban_moved_by_id = context.key?(:user_id) ? context[:user_id] : Current.user&.id
    self.kanban_move_reason = context[:reason]&.to_s&.truncate(250)
  end

  def remember_kanban_move
    from, to = saved_change_to_kanban_process_id
    @pending_kanban_move = { from: from, to: to }
  end

  def log_kanban_move
    move = @pending_kanban_move
    @pending_kanban_move = nil
    self.kanban_move_context = nil
    return if move.nil? || kanban_type_process_id.nil?

    KanbanMove.create!(
      account_id: account_id, conversation_id: id, kanban_type_process_id: kanban_type_process_id,
      from_process_id: move[:from], to_process_id: move[:to], source: kanban_move_source,
      reason: kanban_move_reason, user_id: kanban_moved_by_id, created_at: kanban_moved_at || Time.current
    )
    convert_on_drop(move[:to])
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnel] bitácora de la conversación #{id}: #{e.message}")
  end

  # E2 — soltar a mano en una columna «Convertido» con tipo crea la oportunidad.
  def convert_on_drop(column_id)
    return unless kanban_move_source == 'manual'

    column = KanbanProcess.find_by(id: column_id)
    Kanban::FunnelConverter.new(self, column).call if column&.stage_converted? && column&.convert_case_type_id
  end
end
