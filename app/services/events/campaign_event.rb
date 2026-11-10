# Plan-Eventos E3 — el apartado «Evento» de una campaña: a qué evento pertenece y con qué
# estado de sus asistentes. Lo leen los dos caminos de alta (por lote y continua).
module Events::CampaignEvent
  # { event_id:, event_status: } válidos para la cuenta (nil si no vienen o no existen).
  def self.attributes(account, params)
    event = account.events.find_by(id: params[:event_id]) if params[:event_id].present?
    status = params[:event_status].to_s
    { event_id: event&.id, event_status: (EventAttendee.statuses.key?(status) && event ? status : nil) }
  end
end
