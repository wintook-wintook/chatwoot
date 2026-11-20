# frozen_string_literal: true

# «Atención a clientes» — las áreas que atiende (Plan-Motor-Agentes §11.15, del plan funcional del
# Coordinador Kontrolya: Soporte, Comercial, Administrativo; más «Otra» con su nombre). Cada una con
# cuándo aplica y ejemplos de «sí» y «no» (los de la matriz del plan): el clasificador (Motor2::Triage)
# decide por la intención, no por la palabra, y «Probar la matriz» los usa como pruebas.
#
# En answers['areas'][clave] (lo que contestó en el asistente):
#   on, examples_yes [], examples_no [], user_id, team_id          (todas)
#   rules (sus reglas propias), hours { from, to, days }           (todas: Motor2::Skills::AreaRules)
#   support: action 'case' | 'handoff' | 'visit' (visita técnica: appointment_user_ids, appointment_minutes), case_type_id,
#            details (pide qué pasa / desde cuándo / a cuántos),
#            default_service_id (el sistema que atiende si el cliente no dice otro: Servicios afectados del catálogo)
#   sales:   quote 'opportunity' | 'handoff', demo 'appointment' | 'handoff', visit 'appointment' | 'handoff',
#            appointment_user_ids [], appointment_minutes, case_type_id
#   admin:   case (bool), case_type_id
#   other:   name, description
module Motor2::Functions::CustomerAreas
  KEYS = %w[support sales admin other].freeze
  MAX_EXAMPLES = 20

  DEFAULTS = {
    'support' => {
      'title' => 'Soporte',
      'when' => 'quiere reparar algo: una falla, un error, un bloqueo, un problema de uso o de configuración, algo que no ' \
                'funciona o una integración que no responde (aunque mencione cotizaciones o facturas)',
      'examples_yes' => ['No puedo enviar una cotización a pedido', 'La cotización no se genera',
                         'El módulo de facturación no carga', 'No puedo generar mi factura porque marca error'],
      'examples_no' => ['Quiero una cotización', 'Mi factura tiene mal el RFC'],
      'on' => true, 'action' => 'case', 'details' => true
    },
    'sales' => {
      'title' => 'Comercial',
      'when' => 'quiere conocer, evaluar, cotizar, comprar, contratar o ampliar: planes, precios, licencias, cotizaciones, ' \
                'demostración, implementación, reunión o visita de un vendedor',
      'examples_yes' => ['¿Qué planes tienen?', '¿Cuánto cuestan las licencias?', 'Quiero una cotización',
                         'Quiero cotización para 10 usuarios', 'Quiero hablar con un vendedor', 'Quiero una demo',
                         'Quiero que un vendedor venga a verme', 'Quiero contratar'],
      'examples_no' => ['No puedo enviar una cotización a pedido', 'La cotización no se genera'],
      'on' => true, 'quote' => 'opportunity', 'demo' => 'handoff', 'visit' => 'handoff'
    },
    'admin' => {
      'title' => 'Administrativo',
      'when' => 'necesita una gestión de su cuenta: saldo, facturas, comprobantes, pagos, datos fiscales o RFC, ' \
                'documentación o aclaraciones administrativas',
      'examples_yes' => ['Mi factura tiene mal el RFC', 'Necesito mi factura', 'Quiero enviar un comprobante de pago',
                         'Quiero saber mi saldo'],
      'examples_no' => ['El módulo de facturación no carga', 'No puedo generar mi factura porque marca error'],
      'on' => true, 'case' => false
    },
    'other' => { 'title' => 'Otra', 'when' => '', 'examples_yes' => [], 'examples_no' => [], 'on' => false }
  }.freeze

  ACTIONS = { 'action' => %w[case handoff visit], 'quote' => %w[opportunity handoff], 'demo' => %w[appointment handoff],
              'visit' => %w[appointment handoff] }.freeze

  module_function

  # Lo que manda el asistente, limpio.
  def sanitize(raw)
    raw = Motor2::Sanitizer.plain(raw)
    KEYS.index_with { |key| area(key, Motor2::Sanitizer.plain(raw[key])) }
  end

  def area(key, raw)
    out = { 'on' => raw.key?('on') ? ActiveModel::Type::Boolean.new.cast(raw['on']) || false : DEFAULTS[key]['on'],
            'examples_yes' => examples(raw, 'examples_yes', key), 'examples_no' => examples(raw, 'examples_no', key),
            'user_id' => raw['user_id'].to_s.presence&.to_i, 'team_id' => raw['team_id'].to_s.presence&.to_i }
    out.merge(own_rules(raw)).merge(specific(key, raw)).compact
  end

  def examples(raw, field, key)
    list = raw.key?(field) ? Array(raw[field]) : DEFAULTS[key][field]
    list.map { |e| e.to_s.squish.first(200) }.compact_blank.uniq.first(MAX_EXAMPLES)
  end

  def specific(key, raw)
    case key
    when 'support' then { 'action' => choice(raw, 'action', key), 'case_type_id' => id(raw['case_type_id']),
                          'details' => raw.key?('details') ? ActiveModel::Type::Boolean.new.cast(raw['details']) || false : true,
                          'default_service_id' => id(raw['default_service_id']) }.merge(visit(raw))
    when 'sales' then sales(raw)
    when 'admin' then { 'case' => ActiveModel::Type::Boolean.new.cast(raw['case']) || false, 'case_type_id' => id(raw['case_type_id']) }
    else { 'name' => raw['name'].to_s.squish.first(60), 'description' => raw['description'].to_s.squish.first(300) }
    end
  end

  def sales(raw)
    %w[quote demo visit].index_with { |field| choice(raw, field, 'sales') }
                        .merge('appointment_user_ids' => Array(raw['appointment_user_ids']).map(&:to_i).select(&:positive?).uniq,
                               'appointment_minutes' => raw['appointment_minutes'].to_s.presence&.to_i,
                               'case_type_id' => id(raw['case_type_id']))
  end

  # Soporte que va a domicilio (aire acondicionado, instalaciones…): con quién y cuánto dura la visita técnica.
  def visit(raw)
    { 'appointment_user_ids' => Array(raw['appointment_user_ids']).map(&:to_i).select(&:positive?).uniq,
      'appointment_minutes' => raw['appointment_minutes'].to_s.presence&.to_i }
  end

  def own_rules(raw) = { 'rules' => raw['rules'].to_s.strip.first(800).presence, 'hours' => hours(raw['hours']) }

  # El horario del área («09:00» a «14:00», lunes a viernes); sin las dos horas, nada.
  def hours(raw)
    raw = Motor2::Sanitizer.plain(raw)
    from, to = raw.values_at('from', 'to').map { |h| h.to_s[/\A\d{2}:\d{2}\z/] }
    return nil unless from && to

    { 'from' => from, 'to' => to, 'days' => raw['days'].to_s.presence_in(%w[weekdays saturday all]) || 'weekdays' }
  end

  def choice(raw, field, key) = raw[field].to_s.presence_in(ACTIONS[field]) || DEFAULTS[key][field]

  def id(value) = value.to_s.presence&.to_i

  # Las áreas prendidas, con su título y cuándo aplica (lo de «Otra» lo pone la empresa).
  def active(areas)
    KEYS.filter_map do |key|
      saved = areas.to_h[key].to_h
      next unless saved.fetch('on', DEFAULTS[key]['on'])

      title = key == 'other' ? saved['name'].presence || 'Otra' : DEFAULTS[key]['title']
      when_text = key == 'other' ? saved['description'].to_s : DEFAULTS[key]['when']
      DEFAULTS[key].merge(saved).merge('key' => key, 'title' => title, 'when' => when_text)
    end
  end
end
