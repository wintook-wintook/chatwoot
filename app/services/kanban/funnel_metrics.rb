# frozen_string_literal: true

# ================================================================================
# Embudo de contactos E3 — métricas de un embudo en un periodo
# ================================================================================
# Todo sale de la bitácora kanban_moves (existe desde el Embudo de contactos E1; lo
# anterior no tiene historia):
#   entries     — conversaciones que entraron al embudo en el periodo (su primer
#                 movimiento en el tablero cae en el periodo)
#   columns     — por columna: cuántas hay hoy y cuántas de las que entraron llegaron
#                 a ella (reach), en orden del embudo
#   converted   — cuántas de las que entraron llegaron a una columna «Convertido»,
#                 la tasa y los días promedio de la entrada a la conversión
#   discards    — descartes del periodo por motivo
#   sources     — quién movió las tarjetas (persona, regla, IA, automatización)
#   ai          — movimientos de la IA y cuántos corrigió una persona después
#                 (la movió a mano en las CORRECTION_WINDOW siguientes)
# ================================================================================

class Kanban::FunnelMetrics
  CORRECTION_WINDOW = 72.hours
  TOP_REASONS = 8

  def initialize(board, days: 30)
    @board = board
    @days = days.to_i.clamp(1, 365)
    @since = @days.days.ago
  end

  def call
    { days: @days, since: @since.to_i, entries: entries.size, columns: columns, converted: converted,
      discards: discards, sources: sources, ai: ai }
  end

  private

  def moves
    @moves ||= KanbanMove.where(kanban_type_process_id: @board.id)
  end

  def period_moves
    moves.where('created_at >= ?', @since)
  end

  # conversation_id → momento de su primer movimiento en el tablero (si cae en el periodo).
  def entries
    @entries ||= moves.group(:conversation_id).minimum(:created_at).select { |_, at| at >= @since }
  end

  # conversation_id → columnas a las que llegó (de las que entraron en el periodo).
  def reached
    @reached ||= moves.where(conversation_id: entries.keys).where.not(to_process_id: nil)
                      .pluck(:conversation_id, :to_process_id, :created_at)
  end

  def column_list
    @column_list ||= @board.kanban_processes.by_position.order(:id).to_a
  end

  def columns
    now = @board.conversations.group(:kanban_process_id).count
    reach = reached.group_by { |row| row[1] }.transform_values { |rows| rows.map(&:first).uniq.size }
    column_list.map do |c|
      { id: c.id, name: c.type_process_name, kind: c.stage_kind, current: now[c.id].to_i, reached: reach[c.id].to_i,
        reach_rate: rate(reach[c.id].to_i, entries.size) }
    end
  end

  def converted
    targets = column_list.select(&:stage_converted?).map(&:id)
    first_conversion = reached.select { |row| targets.include?(row[1]) }
                              .group_by(&:first).transform_values { |rows| rows.map(&:last).min }
    days = first_conversion.map { |id, at| (at - entries[id]) / 1.day }
    { count: first_conversion.size, rate: rate(first_conversion.size, entries.size),
      avg_days: days.empty? ? nil : (days.sum / days.size).round(1) }
  end

  def discards
    targets = column_list.select(&:stage_discarded?).map(&:id)
    period_moves.where(to_process_id: targets).group(:reason).count
                .sort_by { |_, n| -n }.first(TOP_REASONS).map { |reason, n| { reason: reason, count: n } }
  end

  def sources
    period_moves.group(:source).count
  end

  def ai
    ai_moves = period_moves.where(source: 'ai').pluck(:conversation_id, :created_at)
    corrected = ai_moves.count do |conversation_id, at|
      moves.where(conversation_id: conversation_id, source: 'manual')
           .where('created_at > ? AND created_at <= ?', at, at + CORRECTION_WINDOW).exists?
    end
    { moves: ai_moves.size, corrected: corrected,
      accuracy: ai_moves.empty? ? nil : rate(ai_moves.size - corrected, ai_moves.size) }
  end

  def rate(part, total)
    total.zero? ? 0.0 : (part * 100.0 / total).round(1)
  end
end
