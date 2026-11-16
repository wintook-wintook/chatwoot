# frozen_string_literal: true

# «Preguntas y datos del cliente» — lo que el agente debe saber del cliente (carrera, turno,
# presupuesto…). El modelo los guarda con guardar_dato y el código los valida contra los
# valores permitidos (antes, en el 1.0, el modelo escribía «VARIABLES: X=v» en su texto).
# Las marcadas «preguntar» se preguntan una a la vez, en orden.
#
#   skills.data = { 'on' => true, 'fields' => [{ 'key' => 'carrera', 'label' => 'Carrera que le interesa',
#                                                 'ask' => true, 'values' => ['Derecho', 'Psicología'] }] }
# Un dato con 'resets' (p. ej. carrera → ['offer_step']) reinicia esa memoria al cambiar (lección
# 4fe6a065: cambiar de carrera no reiniciaba precio ni beca).
class Motor2::Skills::Data < Motor2::Skills::Base
  CONTACT_FIELDS = %w[nombre correo empresa ciudad].freeze

  def self.key = 'data'

  # También sin campos: guardar nombre y correo del cliente sirve a cualquier agente.
  def on? = true

  def tools
    list = [fn('actualizar_contacto', 'Guarda el nombre, correo, empresa o ciudad que el cliente dijo.',
               { nombre: STR, correo: STR, empresa: STR, ciudad: STR })]
    return list if fields.empty?

    list << fn('guardar_dato', 'Guarda un dato que el cliente dijo (en cuanto lo diga, aunque no lo hayas preguntado).',
               { dato: { type: 'string', enum: fields.pluck('key') }, valor: STR }, %w[dato valor])
  end

  def instructions
    return '' if fields.empty?

    lines = fields.map do |f|
      allowed = Array(f['values']).presence
      "  - #{f['key']}: #{f['label']}#{" (uno de: #{allowed.join(', ')})" if allowed}#{' — PREGÚNTALO' if ask?(f)}"
    end
    <<~TEXT.strip
      - DATOS DEL CLIENTE que debes conseguir y guardar con guardar_dato:
      #{lines.join("\n")}
        Pregunta los marcados «PREGÚNTALO» uno a la vez y en ese orden, sin interrogarlo: entre tus respuestas.
    TEXT
  end

  def memory
    saved = state.data.slice(*fields.pluck('key'))
    pending = fields.select { |f| ask?(f) && saved[f['key']].blank? }.pluck('key')
    lines = []
    lines << "DATOS QUE YA TIENES: #{saved.map { |k, v| "#{k}=#{v}" }.join(', ')}" if saved.any?
    lines << "TE FALTA PREGUNTAR (en orden): #{pending.join(', ')}" if pending.any?
    lines.join("\n")
  end

  def call(name, args)
    name == 'guardar_dato' ? save(args['dato'].to_s, args['valor'].to_s.strip) : update_contact(args)
  end

  private

  def fields
    @fields ||= Array(setting(:fields)).filter_map do |f|
      f = f.to_h.stringify_keys
      key = f['key'].to_s.parameterize(separator: '_').presence
      key && f.merge('key' => key, 'label' => f['label'].presence || key)
    end
  end

  def ask?(field) = ActiveModel::Type::Boolean.new.cast(field['ask'])

  def save(key, value)
    field = fields.find { |f| f['key'] == key }
    return { error: "No existe el dato «#{key}»." } unless field
    return { error: 'Falta el valor.' } if value.blank?

    value = allowed_value(field, value)
    return { error: "«#{key}» debe ser uno de: #{Array(field['values']).join(', ')}. Si no es ninguno, pregúntale." } if value.nil?

    store(field, value.first(300))
    { ok: true }
  end

  def store(field, value)
    key = field['key']
    changed = state.data[key].present? && state.data[key] != value
    state.data[key] = value
    Array(field['resets']).each { |memory_key| state.values.delete(memory_key.to_s) } if changed
    trace.event(:dato, "#{key}=#{value}")
  end

  # Con valores permitidos, se acepta sin importar mayúsculas ni acentos («derecho» → «Derecho»).
  def allowed_value(field, value)
    allowed = Array(field['values']).map(&:to_s)
    return value if allowed.empty?

    allowed.find { |a| I18n.transliterate(a).casecmp?(I18n.transliterate(value)) }
  end

  # En el chat de prueba solo se anota.
  def update_contact(args)
    data = contact_data(args)
    trace.event(:contacto, data.map { |k, v| "#{k}=#{v}" }.join(', ')) if data.any?
    contact = @turn.conversation&.contact
    write_contact(contact, data) if data.any? && !test? && contact
    { ok: true }
  end

  def contact_data(args)
    data = args.to_h.slice(*CONTACT_FIELDS).transform_values { |v| v.to_s.strip.first(200) }.compact_blank
    data.delete('correo') unless data['correo'].to_s.match?(URI::MailTo::EMAIL_REGEXP)
    data
  end

  def write_contact(contact, data)
    attrs = contact.additional_attributes.to_h.merge({ 'company_name' => data['empresa'], 'city' => data['ciudad'] }.compact)
    contact.update(name: data['nombre'] || contact.name, email: data['correo'] || contact.email, additional_attributes: attrs)
  end
end
