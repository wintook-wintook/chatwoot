# frozen_string_literal: true

# Tareas que se repiten (TaskRecurrence). Cada usuario programa las suyas; con Agenda en «Todo» también las de su
# equipo y las ve todas.
#   GET    /task_recurrences?scope=mine|all
#   POST   /task_recurrences              { title, mode, every, unit, weekdays[], at_time, starts_on, ends_on, max_count, … }
#   PATCH  /task_recurrences/:id          lo mismo, o { status: 'paused' | 'active' }
#   DELETE /task_recurrences/:id          la termina (las tareas que ya creó se quedan)
class Api::V1::Accounts::TaskRecurrencesController < Api::V1::Accounts::BaseController
  before_action :set_recurrence, only: %i[update destroy]

  def index
    scope = Current.account.task_recurrences.where.not(status: 'ended')
    scope = scope.for_user(current_user.id) unless params[:scope] == 'all' && see_all?
    rows = scope.includes(:assignee, :user, :contact, :organization, :case_ticket).order(:next_on, :id).limit(300)
    render json: { task_recurrences: TaskRecurrences::Serializer.list(rows, current_user), see_all: see_all? }
  end

  def create
    recurrence = Current.account.task_recurrences.new(recurrence_params.merge(user: current_user))
    recurrence.assignee ||= current_user
    TaskRecurrences::Schedule.start!(recurrence)
    render json: { task_recurrence: TaskRecurrences::Serializer.one(recurrence.reload, current_user) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    attrs = recurrence_params
    status = params[:status].to_s
    attrs[:status] = status if %w[active paused].include?(status)
    TaskRecurrences::Schedule.change!(@recurrence, attrs)
    render json: { task_recurrence: TaskRecurrences::Serializer.one(@recurrence.reload, current_user) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @recurrence.update!(status: 'ended', next_on: nil)
    head :no_content
  end

  private

  def set_recurrence
    @recurrence = Current.account.task_recurrences.find(params[:id])
    render_access_denied unless see_all? || [@recurrence.user_id, @recurrence.assignee_id].include?(current_user.id)
  end

  def see_all?
    access_grant.admin? || access_grant.level(:agenda) == 'all'
  end

  def recurrence_params
    attrs = params.permit(:title, :description, :priority, :estimated_minutes, :mode, :every, :unit, :at_time, :time_zone,
                          :starts_on, :ends_on, :max_count, :assignee_id, :contact_id, :organization_id, :case_ticket_id,
                          weekdays: []).to_h.symbolize_keys
    attrs[:weekdays] = Array(attrs[:weekdays]).map(&:to_i) if attrs.key?(:weekdays)
    attrs[:at_time] = attrs[:at_time].presence if attrs.key?(:at_time)
    links(attrs)
  end

  # Con Agenda en «solo lo suyo», el responsable es uno mismo.
  def links(attrs)
    if attrs.key?(:assignee_id)
      attrs[:assignee_id] = access_grant.own?(:agenda) ? current_user.id : Current.account.users.where(id: attrs[:assignee_id]).pick(:id)
    end
    client_links(attrs)
  end

  # Solo lo de la cuenta y lo que puede ver.
  def client_links(attrs)
    attrs[:contact_id] = access_grant.contacts(Current.account.contacts).where(id: attrs[:contact_id]).pick(:id) if attrs.key?(:contact_id)
    attrs[:organization_id] = Current.account.organizations.where(id: attrs[:organization_id]).pick(:id) if attrs.key?(:organization_id)
    attrs[:case_ticket_id] = account_case_tickets.where(id: attrs[:case_ticket_id]).pick(:id) if attrs.key?(:case_ticket_id)
    attrs
  end
end
