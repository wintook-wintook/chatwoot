# frozen_string_literal: true

# Motor 2.0 — guarda un agente de función con lo que contestó en su asistente (Agentes listos ›
# «Atención a prospectos» › Crear uno). Es un tracking_template 2.0 como cualquier otro: sale en
# la lista de agentes y se usa en campañas, automatizaciones, asignación masiva, Delegar y Dali.
#
#   { kind: 'prospects', name: 'Ana – Facebook', display_name: 'Ana', enabled: true,
#     inbox_ids: [3, 4], settings: { …respuestas del asistente…, instructions: '…' } }
#
#   kind          → agent_function
#   enabled       → attending (atiende a quien escribe a sus bandejas)
#   inbox_ids     → attend_inbox_ids (la primera también es la bandeja del agente: identidad, plantillas)
#   display_name  → customer_display_name (el nombre que ve el cliente)
#   settings      → motor2['answers'] (limpias por la función); settings.instructions → motor2['instructions'];
#                   settings.welcome → motor2['welcome'] (la bienvenida, combinada con la primera respuesta)
#   sources       → motor2['sources'] (las fuentes que marcó en «Qué sabe»; las predefinidas van siempre)
#   channel       → «Vendedor de campaña» (no atiende bandejas: lo usa una campaña): por dónde escribe y sus
#                   toques { inbox_id, whatsapp_templates: [], retry_value, retry_unit, attempts, email_signature }
# Sin `settings` (p. ej. prender o apagar desde la lista) no se tocan las respuestas.
class Motor2::Functions::Form
  def initialize(account, params, user:, template: nil)
    @account = account
    @params = Motor2::Sanitizer.plain(params)
    @user = user
    @template = template || account.tracking_templates.new(user: user)
  end

  def save
    build
    ActiveRecord::Base.transaction do
      @template.save!
      Motor2Version.record!(@template, user: @user, source: @template.previously_new_record? ? 'create' : 'manual')
    end
    @template
  end

  # Lo de la pantalla puesto en el agente, sin guardar (el chat de prueba usa esto).
  def build
    kind = @template.agent_function.presence || @params['kind'].to_s
    raise ArgumentError, 'Función desconocida.' unless Motor2::Functions.available?(kind)

    @template.assign_attributes(engine: Motor2::ENGINE, agent_function: kind)
    @template.objective = Motor2::Functions.entry(kind)['objective'] if @template.objective.blank?
    assign_columns
    assign_settings(kind) if @params.key?('settings')
    assign_sources if @params.key?('sources')
    assign_channel if kind == Motor2::Functions::CampaignSeller::KEY
    @template
  end

  private

  def assign_columns
    @template.name = @params['name'].to_s.squish.first(100) if @params.key?('name')
    @template.customer_display_name = @params['display_name'].to_s.squish.first(30) if @params.key?('display_name')
    @template.attending = ActiveModel::Type::Boolean.new.cast(@params['enabled']) || false if @params.key?('enabled')
    assign_inboxes if @params.key?('inbox_ids')
  end

  def assign_inboxes
    ids = @account.inboxes.where(id: Array(@params['inbox_ids'])).where.not(channel_type: 'Channel::Internal').ids
    ordered = Array(@params['inbox_ids']).map(&:to_i) & ids
    @template.attend_inbox_ids = ordered
    @template.inbox_id = ordered.first
  end

  UNITS = %w[minutes hours days].freeze

  # El Vendedor de campaña no atiende bandejas; escribe por la de su canal, con una plantilla por toque.
  def assign_channel
    @template.attending = false
    @template.attend_inbox_ids = []
    return unless @params['channel'].is_a?(Hash)

    channel = @params['channel']
    @template.inbox_id = @account.inboxes.where(id: channel['inbox_id']).pick(:id) if channel.key?('inbox_id')
    @template.email_signature = channel['email_signature'].to_s.first(1000) if channel.key?('email_signature')
    assign_touches(channel)
  end

  # Cada cuánto y cuántos toques (sin plantillas, los que diga; con plantillas, uno por plantilla).
  def assign_touches(channel)
    @template.whatsapp_templates = Array(channel['whatsapp_templates']).map { |t| t.to_s.strip }.first(10) if channel.key?('whatsapp_templates')
    @template.retry_interval_value = channel['retry_value'].to_i.clamp(1, 999) if channel['retry_value'].present?
    @template.retry_interval_unit = channel['retry_unit'].to_s.presence_in(UNITS) || 'days' if channel.key?('retry_unit')
    @template.follow_up_attempts = channel['attempts'] if channel['attempts'].present?
  end

  # Solo las que la cuenta tiene (Motor2::SourceMap#available); las predefinidas no se marcan.
  def assign_sources
    allowed = Motor2::SourceMap.new(@account).available.pluck(:key) - [Motor2::SourceMap::CANNED]
    @template.motor2 = @template.motor2.to_h.merge('sources' => Array(@params['sources']).map(&:to_s) & allowed)
  end

  def assign_settings(kind)
    settings = Motor2::Sanitizer.plain(@params['settings'])
    data = @template.motor2.to_h.deep_dup
    data['answers'] = Motor2::Functions.klass(kind).sanitize(settings)
    %w[instructions welcome].each do |key|
      data[key] = settings[key].to_s.strip.first(Motor2::Sanitizer::TEXTS[key]) if settings.key?(key)
    end
    @template.motor2 = data
    minutes = data.dig('answers', 'appointment_minutes').to_i
    @template.calendar_event_duration = minutes if minutes.positive?
  end
end
