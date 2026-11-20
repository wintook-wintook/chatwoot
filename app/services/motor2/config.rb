# frozen_string_literal: true

# Motor 2.0 — la ficha de un agente. Lo que comparte con el 1.0 vive en columnas de
# tracking_templates (nombre, objetivo, contexto, bandeja, intentos, plantillas, palabras clave,
# agendas); lo propio del 2.0, en tracking_templates.motor2 (jsonb):
#
#   { 'tone' => 'tu' | 'usted', 'instructions' => 'texto libre de la empresa',
#     'welcome' => 'Hola, soy…', 'business' => [{ 'label' => 'Horario', 'value' => 'L-V 9 a 18' }],
#     'sources' => ['canned_response', 'article', 'google_sheet:12', …],   # llaves de ContactTrackings::Ficha::Catalog
#     'never' => 'lo que nunca debe hacer',
#     'skills' => { 'data' => { 'on' => true, 'fields' => [...] }, 'offers' => {...}, 'appointments' => {...},
#                   'tickets' => {...}, 'files' => {...}, 'handoff' => {...} },
#     'answers' => { … } }   # agentes de una función (§11.14): lo que contestó en su asistente
#
# Un agente de función (tracking_templates.agent_function, p. ej. «Atención a prospectos») trae
# su puesto y sus habilidades de Motor2::Functions; lo que tenga motor2['skills'] gana.
#
# Para el chat de prueba se le pasa lo que hay en la pantalla sin guardar (draft).
class Motor2::Config
  COLUMNS = %w[name customer_display_name objective ai_context email_signature inbox_id].freeze
  TONES = %w[tu usted].freeze
  MAX_TEXT = 6000

  attr_reader :template, :data

  def initialize(template, draft: nil)
    @template = template
    draft = draft.to_h.deep_stringify_keys if draft
    @columns = template.attributes.slice(*COLUMNS).merge(draft.to_h.slice(*COLUMNS).compact)
    @data = (draft&.key?('motor2') ? draft['motor2'] : template.motor2).to_h.deep_stringify_keys
  end

  def account = @template.account

  # Los archivos del agente (en el chat de prueba, los del agente del que es copia).
  def attachments = AiAgentAttachment.where(tracking_template_id: @template.id || @template.draft_of)

  def name = @columns['name'].to_s

  # El nombre que ve el cliente (si no hay, no se presenta con nombre).
  def display_name = @columns['customer_display_name'].to_s.squish.presence

  def objective = @columns['objective'].to_s.strip

  def context = @columns['ai_context'].to_s.strip

  def inbox = @inbox ||= account.inboxes.find_by(id: @columns['inbox_id'])

  def tone
    return voice['tone'].to_s.match?(/\busted\b/i) ? 'usted' : 'tu' if function.respond_to?(:answer) && function.answer(:tone) == 'empresa'

    function&.tone || @data['tone'].presence_in(TONES) || 'tu'
  end

  # Lo que se contestó en el asistente de la función.
  def answers = @data['answers'].to_h

  # La función del agente (Motor2::Functions::Prospects…), o nil si es a medida.
  def function
    return @function if defined?(@function)

    @function = Motor2::Functions.for(self)
  end

  def instructions = text('instructions')

  def welcome = text('welcome')

  def never = text('never')

  # «Cómo habla tu empresa» con lo que este agente cambió solo para él (motor2['voice']).
  def voice = AgentBase::CompanyVoice.for_agent(account, @data['voice'].to_h)

  # Los campos que este agente cambió (para el chat de prueba: «habló como…»).
  def own_voice_fields = AgentBase::CompanyVoice.clean(@data['voice'].to_h).keys

  def business
    Array(@data['business']).filter_map do |row|
      label = row.to_h['label'].to_s.squish.first(80)
      value = row.to_h['value'].to_s.strip.first(500)
      { 'label' => label, 'value' => value } if label.present? && value.present?
    end
  end

  # Las que marcó y las que pone su función (p. ej. dónde están sus productos y precios).
  def sources
    extra = function.respond_to?(:extra_sources) ? function.extra_sources : []
    (Array(@data['sources']) + extra).map(&:to_s).compact_blank.uniq
  end

  def skill(key)
    base = function ? function.skills[key.to_s].to_h : {}
    base.merge(@data.dig('skills', key.to_s).to_h.reject { |_, v| v.nil? || v == '' })
  end

  # Pasar a una persona viene prendida: un agente sin salida a una persona se atora.
  def skill_on?(key)
    value = skill(key)['on']
    value.nil? ? key.to_s == 'handoff' : ActiveModel::Type::Boolean.new.cast(value)
  end

  def keyword_actions = Array(@template.keyword_actions)

  def zone = ActiveSupport::TimeZone[@template.timezone.to_s] || ActiveSupport::TimeZone[inbox&.timezone.to_s] || Time.zone

  private

  def text(key) = @data[key].to_s.strip.first(MAX_TEXT)
end
