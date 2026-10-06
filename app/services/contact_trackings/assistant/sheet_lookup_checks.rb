# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — EL COMPROBADOR DE {{hoja_buscar:}} (docs/hoja_buscar_plan.md F4)
# ================================================================================
# El motor es fail-soft: una {{hoja_buscar:}} mal escrita o contra una columna que no
# existe no da error, la agenda solo deja de ofrecer horarios. Aquí se dice por qué:
#
#   rojo   la directiva no tiene sus tres partes (hoja | buscar | regresar)
#   rojo   la hoja no existe (o está inactiva) en la cuenta
#   rojo   una columna de buscar o de regresar no está en los encabezados
#   ámbar  la hoja no tiene sus filas guardadas: hay que sincronizarla
#
# Con el número de línea: el editor la pinta y el aviso sale al pasar el mouse.
# ================================================================================
class ContactTrackings::Assistant::SheetLookupChecks
  RAW_RE = /\{\{\s*hoja_buscar\s*:[^{}]*\}\}/i

  def initialize(text, account:, findings:)
    @text = text.to_s
    @account = account
    @findings = findings
  end

  def call
    occurrences.each { |raw, line, route| check(raw, line: line, route: route) }
  end

  private

  attr_reader :findings

  # [[directiva, número de línea, ruta de esa línea o nil]]
  def occurrences
    @text.split("\n", -1).each_with_index.flat_map do |linea, indice|
      route = linea[ContactTrackings::RouteMap::LINE_RE, 1]&.downcase
      linea.scan(RAW_RE).map { |raw| [raw, indice + 1, route] }
    end
  end

  def check(raw, **where)
    spec = ContactTrackings::SheetLookup.parse_all(raw).first
    return add(:blocking, :sheet_lookup_invalid, raw, where) if spec.nil?

    source = sheet_source(spec.sheet)
    return add(:blocking, :sheet_lookup_sheet_missing, raw, where, name: spec.sheet) if source.nil?

    headers = source.google_sheet_rows.order(:row_index).first&.data&.keys
    return add(:degrading, :sheet_lookup_no_rows, raw, where, name: spec.sheet) if headers.blank?

    check_columns(spec, headers, raw, where)
  end

  def check_columns(spec, headers, raw, where)
    known = headers.map { |h| h.to_s.strip.downcase }
    missing = (spec.filters.map(&:column) + spec.returns).uniq.reject { |col| known.include?(col.strip.downcase) }
    return if missing.empty?

    add(:blocking, :sheet_lookup_column_missing, raw, where,
        name: spec.sheet, columns: missing.join(', '), available: headers.join(', '))
  end

  def sheet_source(name)
    @account.knowledge_sources.active.where(source_type: 'google_sheet').find_by('LOWER(name) = LOWER(?)', name)
  end

  def add(level, code, raw, where, **args)
    findings.add(level, code, t("findings.#{code}", line: where[:line], **args),
                 wrote: raw, line: where[:line], route: where[:route])
  end

  def t(key, **args)
    I18n.t("tracking_assistant.#{key}", locale: ContactTrackings::Assistant::Language.resolve, **args)
  end
end
