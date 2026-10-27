# Plan-Contratos R1 — importar contratos de un CSV (Excel › Guardar como CSV UTF-8).
#
# El contacto se busca por correo o teléfono (columna «contacto») y el tipo por nombre;
# si no existen, la fila se reporta con su número y no se crea nada (no se inventan
# clientes). Con la columna «id» se actualiza ese contrato en vez de crear otro.
# Fechas: AAAA-MM-DD o DD/MM/AAAA. Periodo: día, semana, mes o año. Los datos propios del
# tipo van en columnas extra con su nombre.
class Contracts::CsvImport
  COLUMNS = %w[id contacto tipo concepto clave_catalogo cantidad precio moneda cada periodo inicio proximo_cobro
               plazo_meses renovacion_automatica responsable notas].freeze
  UNITS = {
    'dia' => 'day', 'día' => 'day', 'dias' => 'day', 'días' => 'day', 'day' => 'day',
    'semana' => 'week', 'semanas' => 'week', 'week' => 'week',
    'mes' => 'month', 'meses' => 'month', 'mensual' => 'month', 'month' => 'month',
    'año' => 'year', 'ano' => 'year', 'años' => 'year', 'anual' => 'year', 'year' => 'year'
  }.freeze
  YES = %w[si sí s yes y true 1 x].freeze

  def initialize(account:, contacts:)
    @account = account
    @contacts = contacts
  end

  def call(table)
    result = { created: 0, updated: 0, errors: [] }
    table.each.with_index(2) do |row, line|
      _contract, created = import_row(normalize(row))
      result[created ? :created : :updated] += 1
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      result[:errors] << { line: line, error: e.message }
    end
    result
  end

  private

  def normalize(row)
    row.to_h.transform_keys { |key| key.to_s.strip.downcase.tr(' ', '_') }.transform_values { |v| v.to_s.strip }
  end

  def import_row(row)
    contract = row['id'].present? ? @account.contracts.find_by(id: row['id'], contact_id: @contacts.select(:id)) : nil
    raise ArgumentError, I18n.t('contracts.import.not_found', id: row['id']) if row['id'].present? && contract.nil?

    created = contract.nil?
    contract ||= @account.contracts.new(contact: find_contact(row['contacto']))
    contract.assign_attributes(attributes(row, contract))
    contract.save!
    [contract, created]
  end

  # En una fila nueva, lo vacío toma el valor del tipo (o del catálogo); al actualizar,
  # lo vacío deja lo que ya tenía.
  def attributes(row, contract)
    type = find_type(row['tipo'], contract)
    item = find_item(row['clave_catalogo'])
    attrs = text_attributes(row, item).merge(terms(row, item)).merge(contract_type: type, catalog_item: item)
    attrs = defaults(type).merge(attrs.compact) if contract.new_record?
    attrs.merge(custom_attributes: custom_values(row, type, contract)).compact
  end

  # Los datos propios del tipo van en columnas con su nombre («numero_de_cuenta» o
  # «Número de cuenta»); lo vacío deja lo que ya tenía.
  def custom_values(row, type, contract)
    values = Array(type.custom_fields).each_with_object({}) do |field, found|
      value = row[field['key']].presence || row[field['label'].to_s.strip.downcase.tr(' ', '_')].presence
      found[field['key']] = value if value
    end
    values.empty? ? nil : (contract.custom_attributes || {}).merge(values)
  end

  def text_attributes(row, item)
    { title: row['concepto'].presence || item&.name, currency: row['moneda'].presence, notes: row['notas'].presence,
      assignee: find_user(row['responsable']) }
  end

  def terms(row, item)
    { quantity: decimal(row['cantidad']), price: decimal(row['precio']) || item&.price,
      every: row['cada'].presence&.to_i, unit: unit(row['periodo']), term_months: row['plazo_meses'].presence&.to_i,
      auto_renew: yes_no(row['renovacion_automatica']), starts_on: date(row['inicio'], 'inicio'),
      next_charge_on: date(row['proximo_cobro'], 'proximo_cobro') }
  end

  def defaults(type)
    { quantity: 1, price: 0, every: type.default_every, unit: type.default_unit, term_months: type.default_term_months,
      auto_renew: type.default_auto_renew, starts_on: Date.current }
  end

  def yes_no(value)
    YES.include?(value.downcase) if value.present?
  end

  def find_contact(value)
    raise ArgumentError, I18n.t('contracts.import.contact_required') if value.blank?

    digits = value.gsub(/\D/, '')
    contact = @contacts.find_by('LOWER(contacts.email) = ?', value.downcase)
    contact ||= @contacts.find_by("regexp_replace(contacts.phone_number, '\\D', '', 'g') LIKE ?", "%#{digits.last(10)}") if digits.size >= 8
    contact || raise(ArgumentError, I18n.t('contracts.import.contact_not_found', value: value))
  end

  def find_type(name, contract)
    return contract.contract_type if name.blank? && contract.contract_type

    type = @account.contract_types.find_by('LOWER(name) = ?', name.to_s.downcase)
    type || raise(ArgumentError, I18n.t('contracts.import.type_not_found', value: name))
  end

  def find_item(sku)
    return if sku.blank?

    @account.catalog_items.find_by(sku: sku) || raise(ArgumentError, I18n.t('contracts.import.item_not_found', value: sku))
  end

  def find_user(email)
    return if email.blank?

    @account.users.find_by('LOWER(users.email) = ?', email.downcase) ||
      raise(ArgumentError, I18n.t('contracts.import.user_not_found', value: email))
  end

  def unit(value)
    return if value.blank?

    UNITS[value.downcase] || raise(ArgumentError, I18n.t('contracts.import.bad_unit', value: value))
  end

  def decimal(value)
    return if value.blank?

    BigDecimal(value.delete('$, '))
  rescue ArgumentError
    raise ArgumentError, I18n.t('contracts.import.bad_number', value: value)
  end

  def date(value, column)
    return if value.blank?

    value.include?('/') ? Date.strptime(value, '%d/%m/%Y') : Date.iso8601(value)
  rescue Date::Error
    raise ArgumentError, I18n.t('contracts.import.bad_date', column: column, value: value)
  end
end
