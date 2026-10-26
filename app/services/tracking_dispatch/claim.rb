# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — Fase 2: una vuelta del despachador
# ================================================================================
# Toma los seguimientos vencidos (pending / scheduled con scheduled_for ya pasado) de las
# cuentas con despachador y los marca 'active' con dispatched_at = la hora de la vuelta.
# Esa hora es la marca del envío: TrackingDispatch::SendJob solo procede si sigue igual.
#
# Cuántos toma de cada inbox (= número de WhatsApp), lo menor de:
#   - TRACKING_DISPATCH_PER_INBOX_PER_ROUND (reparto justo entre cuentas),
#   - lo que le queda del minuto (TRACKING_DISPATCH_PER_INBOX_PER_MINUTE, contador en Redis),
#   - lo que le queda del día según su nivel de Meta (TrackingDispatch::MessagingTier).
# Y en total, TRACKING_DISPATCH_MAX_PER_ROUND, repartido por turnos (el 1º de cada inbox,
# luego el 2º...). Lo que no cabe se queda vencido y sale en la siguiente vuelta.
#
# Las campañas pausadas no se despachan: sus seguimientos se quedan como están y salen solos
# al reanudarla.
#
# El marcado es un UPDATE condicionado al estado: si dos vueltas chocan, cada seguimiento
# lo toma solo una.
# ================================================================================
class TrackingDispatch::Claim
  DUE_STATUSES = %w[pending scheduled].freeze
  MINUTE_KEY_TTL = 120

  # La hora en microsegundos, como la guarda Postgres: así la marca se compara igual.
  def initialize(now: Time.current)
    @now = now.floor(6)
  end

  # [[tracking_id, marca], ...] de lo que se tomó en esta vuelta. La marca es dispatched_at
  # en texto (TrackingDispatch.token).
  def call
    ids = candidate_ids(inbox_budgets)
    return [] if ids.empty?

    claimed = mark_active(ids)
    count_minute_usage(claimed)
    claimed.map { |id, _inbox_id| [id, TrackingDispatch.token(@now)] }
  end

  private

  def due_scope
    scope = ContactTracking.where(status: DUE_STATUSES).where(scheduled_for: ..@now)
                           .where.not(inbox_id: nil)
                           .where(<<~SQL.squish)
                             NOT EXISTS (SELECT 1 FROM tracking_campaigns tc
                                         WHERE tc.id = contact_trackings.tracking_campaign_id AND tc.status = 'paused')
                           SQL
    accounts = TrackingDispatch::Settings.account_scope
    accounts == :all ? scope : scope.where(account_id: accounts)
  end

  # { inbox_id => cuántos se pueden tomar ahora }
  def inbox_budgets
    inbox_ids = due_scope.distinct.pluck(:inbox_id)
    Inbox.where(id: inbox_ids).includes(:channel).to_h do |inbox|
      [inbox.id, [TrackingDispatch::Settings.per_inbox_per_round, minute_remaining(inbox.id), day_remaining(inbox)].min]
    end
  end

  def candidate_ids(budgets)
    open_budgets = budgets.select { |_, budget| budget.positive? }
    return [] if open_budgets.empty?

    sql = <<~SQL.squish
      SELECT id, inbox_id, rn FROM (
        SELECT id, inbox_id, row_number() OVER (PARTITION BY inbox_id ORDER BY scheduled_for, id) AS rn
        FROM (#{due_scope.where(inbox_id: open_budgets.keys).select(:id, :inbox_id, :scheduled_for).to_sql}) due
      ) ranked
      WHERE rn <= #{open_budgets.values.max.to_i}
      ORDER BY rn, inbox_id
    SQL
    rows = ContactTracking.connection.select_rows(sql)
    rows.select { |_id, inbox_id, rn| rn.to_i <= open_budgets[inbox_id.to_i] }
        .first(TrackingDispatch::Settings.max_per_round)
        .map { |id, _inbox_id, _rn| id.to_i }
  end

  # [[id, inbox_id], ...] de los que de verdad se marcaron (UPDATE ... RETURNING).
  def mark_active(ids)
    sql = ContactTracking.sanitize_sql_array([<<~SQL.squish, { now: @now, ids: ids, due: DUE_STATUSES }])
      UPDATE contact_trackings SET status = 'active', dispatched_at = :now, updated_at = :now
      WHERE id IN (:ids) AND status IN (:due) AND scheduled_for <= :now
      RETURNING id, inbox_id
    SQL
    ContactTracking.connection.select_rows(sql).map { |id, inbox_id| [id.to_i, inbox_id.to_i] }
  end

  def minute_key(inbox_id)
    "tracking_dispatch:minute:#{inbox_id}:#{@now.to_i / 60}"
  end

  def minute_remaining(inbox_id)
    TrackingDispatch::Settings.per_inbox_per_minute - Redis::Alfred.get(minute_key(inbox_id)).to_i
  end

  # Redis::Alfred no tiene INCRBY con caducidad; se usa su pool como hace Redis::Alfred.
  def count_minute_usage(claimed)
    claimed.group_by(&:last).each do |inbox_id, rows|
      $alfred.with do |conn| # rubocop:disable Style/GlobalVars
        conn.incrby(minute_key(inbox_id), rows.size)
        conn.expire(minute_key(inbox_id), MINUTE_KEY_TTL)
      end
    end
  end

  # Contactos distintos a los que ya se les escribió con plantilla en 24 h por este número,
  # más los que están tomados ahora mismo. Solo cuenta lo de los seguimientos: los envíos de
  # agentes u otras campañas del mismo número no se ven aquí.
  def day_remaining(inbox)
    limit = TrackingDispatch::MessagingTier.daily_limit(inbox)
    return Float::INFINITY if limit.nil?

    sent = TrackingDelivery.joins(:contact_tracking)
                           .where(kind: 'template', contact_trackings: { inbox_id: inbox.id })
                           .where(tracking_deliveries: { created_at: 24.hours.ago(@now).. })
                           .distinct.count('contact_trackings.contact_id')
    in_flight = ContactTracking.where(inbox_id: inbox.id, status: 'active').where.not(dispatched_at: nil).count
    [limit - sent - in_flight, 0].max
  end
end
