# Plan-Trabajo-Campo R2 — Llegué / Terminé en el celular del técnico.
#
# Llegué: abre una entrada de horas de la visita con la ubicación (solo en ese
# momento, no se rastrea) y pasa la orden a «En ejecución» si no lo estaba.
# Terminé: cierra la entrada (otra ubicación), guarda la conformidad (quién
# recibió, nota y firma) y termina la orden: ahí aplican los requisitos del tipo
# (ServiceReportable) y, si el tipo lo manda solo, sale el reporte al cliente.
class Field::Visit
  WORKING = 'in_progress'.freeze
  DONE = 'resolved'.freeze

  # `user` nil = técnico externo (R5, por su enlace). `at`: cuándo pasó de verdad
  # (R5 — si el celular lo guardó sin señal y lo manda después).
  def initialize(order, user, at: nil)
    @order = order
    @user = user
    @at = at || Time.current
  end

  def arrive!(location)
    entry = @order.time_entries.visit.running.find_by(user_id: @user&.id)
    entry ||= @order.time_entries.create!(account: @order.account, user: @user, source: :visit, started_at: @at,
                                          location: { arrive: location.presence }.compact)
    start_work!
    entry
  end

  def finish!(location, conformity)
    CaseTicket.transaction do
      entry = close_entry(location)
      @order.update!(received_by: conformity[:received_by].presence, conformity_note: conformity[:conformity_note].presence,
                     conformity_signature: conformity[:signature], received_at: @at)
      @order.transition!(DONE, actor: @user, force: true) unless ServiceReportable::COMPLETION_STATUSES.include?(@order.status)
      Field::VisitReport.new(@order, entry, @user).record!
    end
  end

  private

  def start_work!
    return if @order.status == WORKING || ServiceReportable::COMPLETION_STATUSES.include?(@order.status)

    @order.transition!(WORKING, actor: @user, force: true)
  end

  def close_entry(location)
    entry = @order.time_entries.visit.running.find_by(user_id: @user&.id)
    return unless entry

    entry.update!(ended_at: [@at, entry.started_at].max, location: entry.location.merge('leave' => location.presence).compact)
    entry
  end
end
