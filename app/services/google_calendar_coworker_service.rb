# Calendario de los compañeros de la cuenta visto por un agente (fix/calendario_google, F1).
#
# Regla de oro: se consulta SIEMPRE con la conexión de Google de QUIEN MIRA y el correo de
# Google del compañero como calendario. Así Google aplica lo que el compañero compartió:
#
#   404                         → 'none'       (no compartido)
#   accessRole freeBusyReader   → 'free_busy'  (Google ya quitó los títulos)
#   accessRole reader           → 'details'    (los privados llegan sin título)
#   accessRole writer / owner   → 'details' + can_schedule (F3b «Agendar a»)
#
# Nunca se usa la conexión del compañero: eso vería su calendario aunque no lo haya
# compartido. (El bot de IA sí la usa para agendar; eso vive en otros servicios y no cambia.)
class GoogleCalendarCoworkerService
  CACHE_TTL = 2.minutes
  ACCESS_BY_ROLE = {
    'freeBusyReader' => 'free_busy',
    'reader' => 'details',
    'writer' => 'details',
    'owner' => 'details'
  }.freeze
  SCHEDULE_ROLES = %w[writer owner].freeze

  # Al cambiar un permiso (F3c) se invalida lo guardado de ese dueño para todos los que lo miran.
  def self.clear_cache_for(owner_email)
    Rails.cache.write(version_key(owner_email), SecureRandom.hex(4))
  end

  def self.version_key(owner_email)
    "gcal_coworker:v:#{owner_email.to_s.downcase}"
  end

  # viewer_service: GoogleCalendarService ya construido con la integración de quien mira
  # (así el token se refresca una sola vez por petición, no una por compañero).
  def initialize(viewer_integration:, viewer_service:)
    @viewer = viewer_integration
    @service = viewer_service
  end

  def fetch(coworker_integration, time_min:, time_max:)
    return base(coworker_integration).merge(access: 'same_google', can_schedule: false, events: []) if same_google?(coworker_integration)

    Rails.cache.fetch(cache_key(coworker_integration, time_min, time_max), expires_in: CACHE_TTL) do
      query(coworker_integration, time_min, time_max)
    end
  end

  def fetch_many(coworker_integrations, time_min:, time_max:)
    coworker_integrations.map { |integration| fetch(integration, time_min: time_min, time_max: time_max) }
  end

  # F3b — antes de escribir en el calendario de un compañero se pregunta a Google EN ESE
  # MOMENTO (sin caché): ¿quien mira tiene «Hacer cambios» (writer/owner)?
  def can_schedule?(coworker_integration)
    return false if same_google?(coworker_integration)

    now = Time.current
    result = @service.list_shared_events(calendar_id: coworker_integration.google_email, time_min: now, time_max: now + 1.minute)
    result[:code] == 200 && SCHEDULE_ROLES.include?(result[:access_role])
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarCoworker] can_schedule? #{@viewer.google_email} → #{coworker_integration.google_email}: #{e.message}"
    false
  end

  private

  def query(coworker, time_min, time_max)
    result = @service.list_shared_events(calendar_id: coworker.google_email, time_min: time_min, time_max: time_max)
    access = access_for(result)
    base(coworker).merge(
      access: access,
      can_schedule: SCHEDULE_ROLES.include?(result[:access_role]),
      events: %w[details free_busy].include?(access) ? result[:items].map { |e| normalize(e) } : []
    )
  rescue StandardError => e
    Rails.logger.warn "[GoogleCalendarCoworker] #{@viewer.google_email} → #{coworker.google_email}: #{e.message}"
    base(coworker).merge(access: 'error', can_schedule: false, events: [])
  end

  def access_for(result)
    # Solo 404 es «no compartido» (medido en F0). Un 403 puede ser cuota agotada → error.
    return 'none' if result[:code] == 404
    return 'error' unless result[:code] == 200

    ACCESS_BY_ROLE.fetch(result[:access_role], 'none')
  end

  # Solo lo que Google mandó; sin título = «Ocupado» (lo decide la pantalla).
  def normalize(event)
    start = event['start'] || {}
    finish = event['end'] || {}
    {
      id: event['id'],
      summary: event['summary'],
      location: event['location'],
      start: start['dateTime'] || start['date'],
      end: finish['dateTime'] || finish['date'],
      all_day: start['dateTime'].blank? && start['date'].present?,
      private: event['summary'].blank?
    }
  end

  def base(coworker)
    { agent_id: coworker.user_id, google_email: coworker.google_email }
  end

  def same_google?(coworker)
    coworker.google_email.to_s.casecmp?(@viewer.google_email.to_s)
  end

  def cache_key(coworker, time_min, time_max)
    version = Rails.cache.read(self.class.version_key(coworker.google_email)) || '0'
    ['gcal_coworker', @viewer.id, coworker.id, version, time_min.to_i, time_max.to_i].join(':')
  end
end
