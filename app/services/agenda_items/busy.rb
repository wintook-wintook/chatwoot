# frozen_string_literal: true

# Agenda — al agendar con participantes: quién ya tiene algo a esa hora. Sus tareas agendadas en Kontrolya (como
# responsable o participante) y, si tiene Google Calendar conectado, lo ocupado en su calendario (free/busy).
#   AgendaItems::Busy.new(account, user_ids, from, to, exclude_id: 12).call
#   → [{ user_id:, name:, items: [{ title:, start:, end: }] }]   (solo quien tiene algo)
class AgendaItems::Busy
  MAX_USERS = 20

  def initialize(account, user_ids, from, to, exclude_id: nil)
    @account = account
    @users = account.users.where(id: Array(user_ids).map(&:to_i).first(MAX_USERS))
    @from = from
    @to = to
    @exclude_id = exclude_id
  end

  def call
    @users.filter_map do |user|
      items = meetings(user) + google(user)
      { user_id: user.id, name: user.name, items: items.uniq { |i| [i[:start], i[:end]] } } if items.any?
    end
  end

  private

  def meetings(user)
    scope = CaseMeeting.active.for_user(user.id).where(account_id: @account.id).where('starts_at < ? AND ends_at > ?', @to, @from)
    scope = scope.where.not(id: @exclude_id) if @exclude_id.present?
    scope.limit(5).map { |m| { title: m.title, start: m.starts_at, end: m.ends_at } }
  end

  def google(user)
    integration = UserCalendarIntegration.find_by(account_id: @account.id, user_id: user.id)
    return [] unless integration

    busy = GoogleCalendarService.new(integration).free_busy(calendars: ['primary'], time_min: @from, time_max: @to)
    Array(busy.dig('calendars', 'primary', 'busy')).map { |b| { title: nil, start: b['start'], end: b['end'] } }
  rescue StandardError => e
    Rails.logger.warn("[AgendaItems::Busy] Google de #{user.id}: #{e.class}: #{e.message}")
    []
  end
end
