# frozen_string_literal: true

# Motor 2.0 — guarda la ficha 2.0. Lo que comparte con el 1.0 va a sus columnas (así campañas,
# asignación masiva, automatizaciones e intentos funcionan igual); lo propio, a motor2. Cada
# guardado que cambie algo deja una versión (Motor2Version).
#
#   Motor2::AgentForm.new(account, params, user:, template: nil).save → TrackingTemplate
class Motor2::AgentForm
  COLUMNS = %w[name customer_display_name objective ai_context inbox_id email_signature retry_interval_value
               retry_interval_unit calendar_event_duration timezone].freeze
  RULE_KEYS = %w[ask welcome attempts booking tickets].freeze

  DEFAULT_DIRECTION = { 'direction' => 'incoming' }.freeze

  # opts: template: (el que se edita; sin él, uno nuevo), source: (de la versión), note:
  def initialize(account, params, user:, **opts)
    @account = account
    @params = Motor2::Sanitizer.plain(params)
    @user = user
    @template = opts[:template] || account.tracking_templates.new(user: user)
    @source = opts[:source] || (@template.new_record? ? 'create' : 'manual')
    @note = opts[:note]
  end

  def save
    build
    ActiveRecord::Base.transaction do
      @template.save!
      Motor2Version.record!(@template, user: @user, source: @source, note: @note)
    end
    @template
  end

  # Lo de la pantalla puesto en el agente, sin guardar (el chat de prueba usa esto).
  def build
    @template.assign_attributes(columns.merge(engine: Motor2::ENGINE))
    assign_lists
    @template.motor2 = Motor2::Sanitizer.call(@params['motor2']) if @params.key?('motor2')
    @template
  end

  private

  def columns
    attrs = @params.slice(*COLUMNS)
    attrs['inbox_id'] = @account.inboxes.find_by(id: attrs['inbox_id'])&.id if attrs.key?('inbox_id')
    attrs
  end

  LISTS = { 'whatsapp_templates' => :whatsapp_templates_param, 'keyword_actions' => :keyword_actions,
            'calendar_integration_ids' => :calendar_ids }.freeze

  def assign_lists
    LISTS.each { |key, reader| @template.public_send("#{key}=", send(reader)) if @params.key?(key) }
    @template.follow_up_attempts = @params['attempts'] if @params['attempts'].present?
    @template.resources = (@template.resources || {}).merge('files' => file_rules) if @params.key?('file_rules')
  end

  def whatsapp_templates_param = Array(@params['whatsapp_templates']).map(&:to_s)

  def keyword_actions
    fields = ContactTrackings::Ficha::Settings::KEYWORD_FIELDS.map(&:to_s)
    Array(@params['keyword_actions']).map { |k| DEFAULT_DIRECTION.merge(Motor2::Sanitizer.plain(k).slice(*fields)) }
                                     .select { |k| k['keyword'].present? }
  end

  def calendar_ids
    UserCalendarIntegration.where(account_id: @account.id, id: Array(@params['calendar_integration_ids'])).pluck(:id)
  end

  # La misma regla por archivo que la ficha 1.0 ({ nombre => { ask, welcome, attempts, booking, tickets } }).
  def file_rules
    Motor2::Sanitizer.plain(@params['file_rules']).transform_values do |rule|
      rule = Motor2::Sanitizer.plain(rule).slice(*RULE_KEYS)
      rule['attempts'] = Array(rule['attempts']).map(&:to_i).select(&:positive?)
      rule['tickets'] = Array(rule['tickets']).map(&:to_s)
      rule
    end
  end
end
