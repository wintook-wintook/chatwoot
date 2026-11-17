# frozen_string_literal: true

# Motor 2.0 — «Pasar a 2.0»: el MISMO agente cambia de motor (plan §11.3). Lo que comparte con
# el 1.0 ya está en sus columnas (canal, intentos, plantillas, palabras clave, agendas, reglas de
# archivos); la ficha 2.0 se arma así:
#   - del código del 1.0 (sin tocarlo): las fuentes, agendas y tipos de caso que usan sus rutas
#     (ContactTrackings::Ficha::Changes#items) y su bienvenida;
#   - con el modelo: el Entrenamiento pasa a instrucciones en texto libre, sin rutas ni
#     directivas, y salen los datos del negocio, las preguntas, las ofertas escalonadas y cuándo
#     pasar a una persona. Sin OpenAI, solo se quitan las directivas.
# El Entrenamiento del 1.0 se queda en su columna: «Regresar a 1.0» lo devuelve tal cual.
class Motor2::Convert < Cases::Ai::BaseService
  SOURCE_TYPES = %w[canned_response article google_sheet google_doc discourse contpaq_support].freeze
  DIRECTIVES = [/@\w+(?:\([^)]*\))?/, /\{\{[^}]*\}\}/, /%[A-Z_0-9]+%/].freeze

  SYSTEM = <<~TEXT
    Convierte el prompt de un agente de chat (secciones [X], rutas @ruta, directivas @buscar_…, {{…}}, %VARIABLES%)
    en la ficha de un motor nuevo. Responde JSON:
    {"instructions": "texto libre en segunda persona: tono, objetivo, qué decir y qué no, cómo manejar casos; SIN rutas,
       directivas, nombres de variables ni datos que van en otros campos",
     "never": "lo que nunca debe hacer, en renglones",
     "tone": "tu" | "usted",
     "business": [{"label": "Horario", "value": "…"}],
     "data_fields": [{"label": "Carrera que le interesa", "ask": true, "values": ["Derecho", "…"]}],
     "offers": {"objection": "qué cuenta como objeción de precio", "steps": ["oferta 1 tal cual", "oferta 2"]},
     "handoff_when": "cuándo pasarlo a una persona"}
    Usa listas vacías o "" si el prompt no trae esa parte. Conserva los textos y cifras exactos. Todo en español.
  TEXT

  def initialize(template, user:)
    super(account: template.account)
    @template = template
    @user = user
    @prompt = template.complementary_prompt.to_s
  end

  def call
    Motor2::AgentForm.new(@account, { 'motor2' => ficha }, user: @user, template: @template, source: 'convert',
                                                           note: 'Pasado a 2.0').save
  end

  private

  def model = Assistant::Settings.model_for(@account)

  def ficha
    keys = ContactTrackings::Ficha::Changes.new(@template, cards: cards).items.map { |i| i.to_h['key'].to_s }
    data = (@prompt.present? && chat(system: SYSTEM, user: @prompt.first(30_000), json: true, max_tokens: 3500)) || {}
    data = {} unless data.is_a?(Hash)
    base(keys, data).merge('skills' => skills(keys, data))
  end

  def cards = ContactTrackings::Ficha::Catalog.new(@account, inbox: @template.inbox, template: @template).call

  def base(keys, data)
    { 'tone' => data['tone'], 'instructions' => data['instructions'].presence || stripped, 'never' => data['never'].to_s,
      'welcome' => ContactTrackings::WelcomeMessage.text(@prompt).to_s.gsub(DIRECTIVES[1], '').strip,
      'business' => Array(data['business']), 'sources' => keys.select { |k| SOURCE_TYPES.include?(k.split(':').first) } }
  end

  def skills(keys, data)
    fields = Array(data['data_fields']).map { |f| f.to_h.merge('key' => f.to_h['label']) }
    { 'data' => { 'on' => fields.any?, 'fields' => fields }, 'offers' => offers(data['offers'].to_h),
      'appointments' => { 'on' => keys.any? { |k| k.start_with?('calendar:') } || Array(@template.calendar_integration_ids).any? },
      'tickets' => tickets(keys), 'handoff' => { 'on' => true, 'when' => data['handoff_when'] } }
  end

  def offers(raw)
    steps = Array(raw['steps']).map { |s| { 'text' => s } }
    { 'on' => steps.any?, 'objection' => raw['objection'], 'steps' => steps }
  end

  def tickets(keys)
    ids = keys.filter_map { |k| k.delete_prefix('case_type:').to_i if k.start_with?('case_type:') }
    { 'on' => ids.any?, 'types' => ids.map { |id| { 'case_type_id' => id } } }
  end

  # Sin modelo: el Entrenamiento sin directivas.
  def stripped
    DIRECTIVES.reduce(@prompt) { |text, re| text.gsub(re, '') }.gsub(/[ \t]{2,}/, ' ').gsub(/\n{3,}/, "\n\n").strip.first(6000)
  end
end
