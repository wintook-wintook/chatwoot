# Plan-Eventos E1 — eventos y su lista de contactos con estado (área Campañas).
#
#   GET    /events                     ?q= &status= &kind= &page=   (con cuántos hay por estado)
#   GET    /events/:id                 POST /events   PATCH /events/:id   DELETE /events/:id
#   POST   /events/:id/close           los que confirmaron y no llegaron → «no asistió»
#   POST   /events/:id/reopen
#   GET    /events/:id/attendees       ?status= &q=
#   POST   /events/:id/add_attendees   (contact_ids, status)  los que ya están no se duplican
#   POST   /events/:id/update_attendee (attendee_id, status)  p. ej. el check-in («attended»)
#   POST   /events/:id/remove_attendee (attendee_id)
#   POST   /events/:id/import          CSV: contacto (correo o teléfono), estado
#   POST   /events/:id/add_segment     (segment_id, status) todos los contactos de un segmento (E2)
#   GET    /events/template            CSV con las columnas
#   GET    /events/for_contact         ?contact_id=  su historial (pestaña del contacto)
class Api::V1::Accounts::EventsController < Api::V1::Accounts::BaseController
  require 'csv'

  PER_PAGE = 50
  FIELDS = %i[name kind status starts_at ends_at location meeting_url capacity description owner_id].freeze

  before_action :set_event, except: %i[index create template for_contact]
  before_action :set_attendee, only: %i[update_attendee remove_attendee]

  def index
    events = filtered_events
    page = [params[:page].to_i, 1].max
    rows = events.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    counts = attendee_counts(rows.map(&:id))
    render json: { events: rows.map { |event| event_json(event, counts[event.id]) },
                   meta: { count: events.count, page: page, per_page: PER_PAGE } }
  end

  def show
    render_event
  end

  def create
    @event = Current.account.events.new(event_params.reverse_merge(owner_id: Current.user.id))
    @event.save ? render(json: { event: event_json(@event) }, status: :created) : render_errors(@event)
  end

  def update
    @event.update(event_params) ? render_event : render_errors(@event)
  end

  def destroy
    @event.destroy!
    head :no_content
  end

  def close
    @event.close!(Current.user)
    render_event
  end

  def reopen
    @event.reopen!
    render_event
  end

  def attendees
    scope = @event.attendees.includes(:contact).joins(:contact).order('contacts.name')
    scope = scope.where(status: params[:status]) if EventAttendee.statuses.key?(params[:status].to_s)
    scope = search_contacts(scope, params[:q]) if params[:q].present?
    render json: { attendees: scope.map { |attendee| attendee_json(attendee) }, counts: @event.counts }
  end

  def add_attendees
    status = EventAttendee.statuses.key?(params[:status].to_s) ? params[:status] : 'invited'
    contacts = visible_contacts.where(id: Array(params[:contact_ids]))
    added = contacts.count { |contact| add(contact, status, 'manual') }
    render json: { added: added, counts: @event.counts }
  end

  # Plan-Eventos E2 — los contactos de un segmento guardado (los que el usuario puede ver).
  def add_segment
    segment = CustomFilter.visible_for(Current.user, account: Current.account, filter_type: :contact)
                          .find(params[:segment_id])
    status = EventAttendee.statuses.key?(params[:status].to_s) ? params[:status] : 'invited'
    added = segment_contacts(segment).count { |contact| add(contact, status, 'segment') }
    render json: { added: added, counts: @event.counts }
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('events.errors.segment_not_found') }, status: :not_found
  end

  def update_attendee
    return render_error(I18n.t('events.errors.status')) unless EventAttendee.statuses.key?(params[:status].to_s)

    @attendee.change_status!(params[:status], Current.user)
    render json: { attendee: attendee_json(@attendee), counts: @event.counts }
  end

  def remove_attendee
    @attendee.destroy!
    render json: { counts: @event.counts }
  end

  def import
    return render_error(I18n.t('events.import.no_file')) if params[:file].blank?

    rows = CSV.parse(params[:file].read.force_encoding('UTF-8').delete_prefix('﻿'), headers: true)
    render json: import_rows(rows).merge(counts: @event.counts)
  rescue CSV::MalformedCSVError => e
    render_error(e.message)
  end

  def template
    send_data %w[contacto estado].to_csv, filename: 'asistentes.csv', type: 'text/csv'
  end

  def for_contact
    contact = visible_contacts.find(params[:contact_id])
    rows = contact.event_attendees.includes(:event).joins(:event).order('events.starts_at DESC')
    render json: { attendances: rows.map { |row| attendee_json(row).merge(event: event_ref(row.event)) } }
  end

  private

  STATUS_ALIASES = { 'invitado' => 'invited', 'confirmado' => 'confirmed', 'confirmo' => 'confirmed',
                     'confirmó' => 'confirmed', 'asistio' => 'attended', 'asistió' => 'attended',
                     'no asistio' => 'no_show', 'no asistió' => 'no_show', 'cancelo' => 'cancelled',
                     'canceló' => 'cancelled' }.freeze

  def set_event
    @event = Current.account.events.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('events.errors.not_found') }, status: :not_found
  end

  def set_attendee
    @attendee = @event.attendees.find(params[:attendee_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('events.errors.not_found') }, status: :not_found
  end

  def filtered_events
    events = Current.account.events.search(params[:q]).includes(:owner).ordered
    events = events.where(status: params[:status]) if Event.statuses.key?(params[:status].to_s)
    events = events.where(kind: params[:kind]) if Event.kinds.key?(params[:kind].to_s)
    events
  end

  def visible_contacts
    access_grant.contacts(Current.account.contacts)
  end

  # Si ya está, no se duplica ni se le cambia el estado.
  def add(contact, status, source)
    attendee = @event.attendees.find_or_initialize_by(contact: contact)
    return false if attendee.persisted?

    attendee.update!(account: Current.account, status: status, source: source, updated_by: Current.user)
    true
  end

  SEGMENT_LIMIT = 5000

  def segment_contacts(segment)
    payload = Array(segment.query.to_h['payload']).map { |condition| condition.to_h.with_indifferent_access }
    contacts = Contacts::FilterService.new(Current.account, Current.user, { payload: payload }).perform[:contacts]
    contacts.where(id: visible_contacts.select(:id)).limit(SEGMENT_LIMIT)
  end

  def import_rows(rows)
    result = { added: 0, updated: 0, errors: [] }
    rows.each.with_index(2) { |row, line| import_row(row.to_h, result, line) }
    result
  end

  def import_row(row, result, line)
    key = row['contacto'].to_s.strip
    contact = visible_contacts.find_by('LOWER(contacts.email) = ?', key.downcase) ||
              visible_contacts.find_by(phone_number: key.start_with?('+') ? key : "+#{key}")
    return result[:errors] << { line: line, error: I18n.t('events.import.contact_not_found', value: key) } unless contact

    status = csv_status(row['estado'])
    attendee = @event.attendees.find_by(contact: contact)
    if attendee
      attendee.change_status!(status, Current.user)
      result[:updated] += 1
    elsif add(contact, status, 'csv')
      result[:added] += 1
    end
  end

  def csv_status(value)
    key = value.to_s.strip.downcase
    key = STATUS_ALIASES.fetch(key, key)
    EventAttendee.statuses.key?(key) ? key : 'invited'
  end

  def search_contacts(scope, term)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s.strip)}%"
    scope.where('contacts.name ILIKE :q OR contacts.email ILIKE :q OR contacts.phone_number ILIKE :q', q: like)
  end

  def attendee_counts(event_ids)
    EventAttendee.where(event_id: event_ids).group(:event_id, :status).count
                 .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((id, status), n), acc| acc[id][status] = n }
  end

  def event_params
    params.require(:event).permit(*FIELDS)
  end

  # Con sus campañas (Plan-Eventos E3): las que tienen este evento en su apartado «Evento».
  def render_event
    campaigns = Current.account.tracking_campaigns.where(event_id: @event.id).order(created_at: :desc)
                       .map { |c| c.slice(:id, :name, :mode, :status, :event_status, :scheduled_for) }
    render json: { event: event_json(@event.reload, @event.counts).merge(campaigns: campaigns) }
  end

  def render_errors(record)
    render_error(record.errors.full_messages.join(', '))
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def event_json(event, counts = nil)
    event.slice(:id, :name, :kind, :status, :starts_at, :ends_at, :location, :meeting_url, :capacity, :description,
                :owner_id, :closed_at, :created_at)
         .merge(owner: event.owner&.slice(:id, :name),
                counts: EventAttendee.statuses.keys.index_with { |key| counts.to_h[key].to_i })
  end

  def event_ref(event)
    event.slice(:id, :name, :kind, :status, :starts_at)
  end

  def attendee_json(attendee)
    attendee.slice(:id, :status, :source, :invited_at, :confirmed_at, :attended_at, :cancelled_at, :updated_at)
            .merge(contact: attendee.contact.slice(:id, :name, :email, :phone_number))
  end
end
