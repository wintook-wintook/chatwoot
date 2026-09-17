# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Controlador: TrackingTemplatesController
# Descripción: CRUD de plantillas de seguimiento (account-scoped)
# Acciones: index (filtros search/tag/inbox_id), show, create, update, destroy
# ================================================================================

class Api::V1::Accounts::TrackingTemplatesController < Api::V1::Accounts::BaseController
  # proyecto@bot_seguimiento_calendar: roles de Google Calendar que permiten crear eventos.
  WRITABLE_CALENDAR_ROLES = %w[owner writer].freeze

  before_action :fetch_tracking_template, only: [:show, :update, :destroy]

  def index
    @tracking_templates = Current.account.tracking_templates.includes(:user, :inbox).ordered
    @tracking_templates = @tracking_templates.search_by_name(params[:search]) if params[:search].present?
    @tracking_templates = @tracking_templates.by_tag(params[:tag]) if params[:tag].present?
    @tracking_templates = @tracking_templates.by_inbox(params[:inbox_id]) if params[:inbox_id].present?
    render json: @tracking_templates.map { |t| template_json(t) }
  end

  def show
    render json: template_json(@tracking_template)
  end

  def create
    @tracking_template = Current.account.tracking_templates.new(tracking_template_params)
    @tracking_template.user = Current.user
    @tracking_template.save!
    render json: template_json(@tracking_template), status: :created
  end

  def update
    @tracking_template.update!(tracking_template_params)
    render json: template_json(@tracking_template)
  end

  # proyecto@asistente_agentes_ia — qué ofrece "Agregar sección": las del contrato del
  # Asistente y las que más usa la cuenta. Medido: 110 nombres distintos en 28 prompts,
  # así que la lista no puede ser fija, pero ofrecerlos todos sería una lista inusable.
  def section_titles
    render json: ContactTrackings::TrainingSectionTitles.new(Current.account).call
  end

  # proyecto@asistente_agentes_ia — la ficha cambia entre la vista Secciones y la vista
  # Texto sin guardar: esto convierte en cualquiera de los dos sentidos y comprueba el
  # resultado. La conversión vive solo acá (TrainingStructure), no duplicada en el
  # navegador: si hubiera dos implementaciones, las vistas podrían no coincidir.
  def training_preview
    texto = if params[:training_structure].present?
              raw = params[:training_structure]
              raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
              ContactTrackings::TrainingStructure.compose('blocks' => sanitized_blocks(raw))
            else
              params[:text].to_s
            end

    render json: { text: texto, training_structure: ContactTrackings::TrainingStructure.parse(texto),
                   validation: ContactTrackings::Assistant::ValidatorService.new(texto, account: Current.account).call }
  end

  def destroy
    @tracking_template.destroy!
    head :ok
  end

  def calendar_integrations
    integrations = UserCalendarIntegration.where(account: Current.account).includes(:user)
    render json: integrations.map { |i|
      # proyecto@bot_seguimiento_calendar: `calendars` = calendarios ESCRIBIBLES de la cuenta,
      # para elegir dónde agenda el bot. Best-effort: si la API falla, queda solo el principal.
      {
        id: i.id,
        google_email: i.google_email,
        user_name: i.user.available_name || i.user.name,
        calendars: writable_calendars(i)
      }
    }
  end

  private

  # Calendarios donde la cuenta puede crear eventos (owner/writer). El principal siempre
  # primero. Tolerante a fallos (token vencido, etc.): devuelve [] y la UI usa 'primary'.
  def writable_calendars(integration)
    GoogleCalendarService.new(integration).list_calendars
                         .select { |c| WRITABLE_CALENDAR_ROLES.include?(c[:access_role]) }
                         .sort_by { |c| c[:primary] ? 0 : 1 }
  rescue StandardError => e
    Rails.logger.warn "[TrackingTemplates] ⚠️ no se pudieron listar calendarios de la integración ##{integration.id}: #{e.message}"
    []
  end

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:id])
  end

  def tracking_template_params
    permitted = params.require(:tracking_template).permit(
      :name, :objective, :ai_context, :complementary_prompt, :inbox_id,
      :retry_interval_value, :retry_interval_unit, :calendar_event_duration, # proyecto@automatizacion_tracking
      :timezone, :slots_presentation, # proyecto@bot_seguimiento_calendar
      whatsapp_templates: [],
      tags: [],
      keyword_actions: [:keyword, :action, :direction], # proyecto@contact_tracking
      calendar_integration_ids: []
    )
    # booking_calendar_ids es un mapa de claves dinámicas { integration_id => [cal_ids] } que
    # strong-params no sabe permitir; lo saneamos a mano (claves int, valores arrays de strings).
    permitted[:booking_calendar_ids] = sanitized_booking_calendar_ids if params[:tracking_template].key?(:booking_calendar_ids)
    with_training_structure(permitted)
  end

  # proyecto@asistente_agentes_ia — la vista Secciones de la ficha manda bloques en vez de
  # texto. Si vienen, mandan sobre `complementary_prompt`: el texto se arma de los bloques
  # y el modelo vuelve a separar la estructura al guardar (ver TrackingTemplate).
  def with_training_structure(permitted)
    raw = params.dig(:tracking_template, :training_structure)
    return permitted if raw.blank?

    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    permitted.delete(:complementary_prompt)
    permitted[:training_structure_from_form] = { 'blocks' => sanitized_blocks(raw) }
    permitted
  end

  TRAINING_BLOCK_KEYS = %w[type title style header body text gap].freeze
  MAX_TRAINING_BLOCKS = 300

  def sanitized_blocks(raw)
    Array(raw['blocks'] || raw[:blocks]).first(MAX_TRAINING_BLOCKS).filter_map do |bloque|
      bloque = bloque.to_unsafe_h if bloque.respond_to?(:to_unsafe_h)
      next unless bloque.is_a?(Hash)

      bloque.stringify_keys.slice(*TRAINING_BLOCK_KEYS)
    end
  end

  # proyecto@bot_seguimiento_calendar — { integration_id => [google_calendar_id, ...] }: en qué
  # calendarios de Google puede agendar el agente por cada agenda. Filtra vacíos y duplica nada.
  def sanitized_booking_calendar_ids
    raw = params.dig(:tracking_template, :booking_calendar_ids)
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    return {} unless raw.is_a?(Hash)

    raw.each_with_object({}) do |(integration_id, cal_ids), acc|
      cals = Array(cal_ids).map(&:to_s).reject(&:blank?).uniq
      acc[integration_id.to_s] = cals if cals.present?
    end
  end

  def template_json(template)
    json = template.as_json(except: [:user_id])
    json['creator'] = if template.user
                        { id: template.user.id, name: template.user.available_name || template.user.name }
                      end
    json['inbox_name']      = template.inbox&.name
    json['keyword_actions'] = template.keyword_actions || [] # proyecto@contact_tracking
    json['training_structure'] = template.training_blocks # proyecto@asistente_agentes_ia
    json
  end
end
