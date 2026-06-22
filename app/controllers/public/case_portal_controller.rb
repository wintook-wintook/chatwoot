# frozen_string_literal: true

# @tickets_cases — User Portal (P1)
# Superficie pública del cliente (estilo osTicket). Resuelve el portal por `slug`
# y sirve HTML server-rendered: landing, abrir solicitud y consultar estado.
# Guest: sin login; el cliente se identifica por email o teléfono + folio.
class Public::CasePortalController < PublicController
  layout 'case_portal'

  before_action :set_portal

  # Eventos visibles al cliente en el timeline público (oculta notas internas, SLA, IA…).
  PUBLIC_EVENT_TYPES = %w[
    ticket_created assigned status_changed escalated in_diagnosis
    resolved reopened validating closed
  ].freeze

  EVENT_LABELS = {
    'ticket_created' => 'Solicitud recibida',
    'assigned'       => 'Asignado a un agente',
    'status_changed' => 'Actualización de estado',
    'escalated'      => 'Escalado para revisión',
    'in_diagnosis'   => 'En diagnóstico',
    'resolved'       => 'Resuelto',
    'reopened'       => 'Reabierto',
    'validating'     => 'En validación',
    'closed'         => 'Cerrado'
  }.freeze

  STATUS_LABELS = {
    'open' => 'Nuevo', 'classified' => 'Clasificado', 'assigned' => 'Asignado',
    'in_diagnosis' => 'En diagnóstico', 'in_progress' => 'En progreso',
    'waiting_on_customer' => 'Esperando tu respuesta', 'waiting_on_third_party' => 'Esperando a un tercero',
    'waiting_on_internal' => 'En gestión interna', 'escalated' => 'Escalado',
    'resolved' => 'Resuelto', 'validating' => 'En validación',
    'closed' => 'Cerrado', 'cancelled' => 'Cancelado'
  }.freeze

  def show; end

  def new
    @case_types = @portal.public_case_types
  end

  def create
    if invalid_submission?
      @case_types = @portal.public_case_types
      @error = 'Indica tu nombre y al menos un correo o un WhatsApp, además del asunto y el mensaje.'
      return render :new, status: :unprocessable_entity
    end

    @ticket = Cases::PortalTicketService.new(
      portal: @portal, name: params[:name], email: params[:email], phone: params[:phone],
      subject: params[:subject], message: params[:message], case_type_id: params[:case_type_id],
      custom_attributes: custom_attributes_param, attachments: params[:attachments]
    ).perform
    render :create
  rescue StandardError => e
    Rails.logger.error("[GestorTickets][Portal] create error: #{e.message}")
    @case_types = @portal.public_case_types
    @error = 'No pudimos registrar tu solicitud. Inténtalo de nuevo en un momento.'
    render :new, status: :unprocessable_entity
  end

  def status
    @identifier = params[:identifier].to_s.strip
    @folio      = params[:folio].to_s.strip
    return if @identifier.blank? && @folio.blank?

    @ticket = lookup_ticket(@identifier, @folio)
    if @ticket
      @timeline = public_timeline(@ticket)
    else
      @not_found = true
    end
  end

  helper_method :status_label

  private

  def set_portal
    @portal = CasePortal.enabled.find_by(slug: params[:slug])
    raise ActionController::RoutingError, 'Portal no encontrado' unless @portal
  end

  def invalid_submission?
    params[:name].blank? || params[:subject].blank? || params[:message].blank? ||
      (params[:email].blank? && params[:phone].blank?)
  end

  def custom_attributes_param
    raw = params[:custom]
    return {} if raw.blank?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
  end

  # Busca el ticket por folio dentro de la cuenta del portal y valida que el
  # identificador (email o teléfono) corresponda a su contacto.
  def lookup_ticket(identifier, folio)
    return nil if identifier.blank? || folio.blank?

    ticket = @portal.account.case_tickets.where('LOWER(folio) = ?', folio.downcase).first
    return nil unless ticket&.contact

    contact = ticket.contact
    id = identifier.downcase
    email_match = contact.email.present? && contact.email.downcase == id
    phone_match = contact.phone_number.present? &&
                  contact.phone_number.delete('^0-9') == identifier.delete('^0-9').presence.to_s
    (email_match || phone_match) ? ticket : nil
  end

  def public_timeline(ticket)
    ticket.case_events
          .where(event_type: PUBLIC_EVENT_TYPES)
          .order(:created_at)
          .map { |e| { label: EVENT_LABELS[e.event_type] || e.event_type.humanize, at: e.created_at } }
  end

  def status_label(status)
    STATUS_LABELS[status.to_s] || status.to_s.humanize
  end
end
