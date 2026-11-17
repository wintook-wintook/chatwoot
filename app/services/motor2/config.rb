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
#                   'tickets' => {...}, 'files' => {...}, 'handoff' => {...} } }
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

  def name = @columns['name'].to_s

  # El nombre que ve el cliente (si no hay, no se presenta con nombre).
  def display_name = @columns['customer_display_name'].to_s.squish.presence

  def objective = @columns['objective'].to_s.strip

  def context = @columns['ai_context'].to_s.strip

  def inbox = @inbox ||= account.inboxes.find_by(id: @columns['inbox_id'])

  def tone = @data['tone'].presence_in(TONES) || 'tu'

  def instructions = text('instructions')

  def welcome = text('welcome')

  def never = text('never')

  def business
    Array(@data['business']).filter_map do |row|
      label = row.to_h['label'].to_s.squish.first(80)
      value = row.to_h['value'].to_s.strip.first(500)
      { 'label' => label, 'value' => value } if label.present? && value.present?
    end
  end

  def sources = Array(@data['sources']).map(&:to_s).compact_blank.uniq

  def skill(key) = @data.dig('skills', key.to_s).to_h

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
