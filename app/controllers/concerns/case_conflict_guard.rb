# frozen_string_literal: true

# Casos editados por dos personas a la vez (K1). No se bloquea el caso: lo que se agrega
# (notas, tareas, agendadas) no choca. El choque es cambiar el MISMO dato:
#   · Campos: el navegador manda `expected: { campo: valor que vio }`; si en el servidor ese
#     campo ya es otro, 409 con el valor actual y el último cambio de otra persona.
#     Campos distintos no chocan. `force: true` = «Usar el mío».
#   · Estado: `expected_status` / `expected_column_id` en mover, cerrar, ganar, posponer…
# Presencia: quién más tiene abierto el caso (señal cada 30 s; vale 90 s).
module CaseConflictGuard
  extend ActiveSupport::Concern

  PRESENCE_TTL = 90 # segundos
  NOT_EDITABLE = %w[id account_id].freeze

  # GET …/case_tickets/:id/presence[?leaving=true] → { viewers: [{ id, name }] } (sin uno mismo).
  # Basta con poder VER el caso (no usa set_ticket, que pide poder escribir).
  def track_presence
    ids = mark_presence(presence_key(account_case_tickets.find(params[:id])), leaving: params[:leaving].to_s == 'true')
    render json: { viewers: Current.account.users.where(id: ids).map { |u| { id: u.id, name: u.name } } }
  end

  private

  # Anota (o quita, con puntaje 0) a quien está en el caso y devuelve a los demás vigentes.
  def mark_presence(key, leaving:)
    now = Time.current.to_i
    Redis::Alfred.zremrangebyscore(key, 0, now - PRESENCE_TTL)
    Redis::Alfred.zadd(key, leaving ? 0 : now, current_user.id)
    Redis::Alfred.zrangebyscore(key, now - PRESENCE_TTL, '+inf').map(&:to_i) - [current_user.id]
  end

  def presence_key(ticket) = "case_presence:#{ticket.id}"

  def check_case_conflict
    return if params[:force].to_s == 'true'

    conflicts = field_conflicts + status_conflicts
    return if conflicts.empty?

    change = last_change_by_other
    render json: { error: conflict_message(change), conflict: true, fields: conflicts, last_change: change,
                   case_ticket: ticket_json(@ticket) }, status: :conflict
  end

  def field_conflicts
    expected = params[:expected]
    return [] unless expected.respond_to?(:to_unsafe_h)

    expected.to_unsafe_h.flat_map do |field, value|
      next custom_attribute_conflicts(value) if field == 'custom_attributes'
      next [] unless @ticket.has_attribute?(field) && NOT_EDITABLE.exclude?(field)

      current = @ticket.public_send(field)
      same_value?(current, value) ? [] : [{ field: field, expected: value, current: current }]
    end
  end

  def custom_attribute_conflicts(values)
    return [] unless values.is_a?(Hash)

    values.filter_map do |key, value|
      current = @ticket.custom_attributes.to_h[key]
      { field: "custom_attributes.#{key}", expected: value, current: current } unless same_value?(current, value)
    end
  end

  def status_conflicts
    list = []
    if params[:expected_status].present? && params[:expected_status].to_s != @ticket.status
      list << { field: 'status', expected: params[:expected_status], current: @ticket.status }
    end
    if params[:expected_column_id].present? && params[:expected_column_id].to_s != @ticket.case_type_column_id.to_s
      list << { field: 'case_type_column_id', expected: params[:expected_column_id], current: @ticket.case_type_column_id }
    end
    list
  end

  # Vacíos iguales; números, fechas y sí/no por su valor (no por cómo se escribieron).
  def same_value?(current, value)
    return current.blank? == value.blank? if current.blank? || value.blank?

    case current
    when Numeric then current.to_d == value.to_s.to_d
    when ActiveSupport::TimeWithZone, Time, Date then same_moment?(current, value)
    when true, false then current == ActiveModel::Type::Boolean.new.cast(value)
    else current.to_s == value.to_s
    end
  rescue ArgumentError, TypeError
    false
  end

  def same_moment?(current, value)
    return current == Date.parse(value.to_s) if current.is_a?(Date)

    (current.to_i - Time.zone.parse(value.to_s).to_i).abs < 1
  end

  def last_change_by_other
    event = @ticket.case_events.where.not(actor_id: [nil, current_user.id]).order(created_at: :desc).first
    event && { by: event.actor&.name, at: event.created_at }
  end

  def conflict_message(change)
    return I18n.t('case_tickets.conflict.someone') unless change&.dig(:by)

    I18n.t('case_tickets.conflict.by', name: change[:by])
  end
end
