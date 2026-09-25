# frozen_string_literal: true

# ================================================================================
# proyecto@hoja_buscar — BUSCAR EXACTO EN UNA HOJA: {{hoja_buscar: Hoja | col=valores | regresar}}
# ================================================================================
# Pedido del usuario (25/09/2026) con el Agente de Grúas SSUSA: cada remolque tiene su
# propio calendario de Google, y la agenda tiene que buscar horarios SOLO en el de los
# remolques de los que se habló. La hoja trae la relación:
#
#   {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}}
#                  └── la hoja ──┘ └─ buscar ─┘ └─ regresar ─┘
#
# · buscar:   columna=valores. Varias condiciones con «;». Valores separados por coma;
#             se comparan sin mayúsculas, espacios ni guiones («tp 63» = «TP-63»).
#             «?» = el valor sale de la conversación (ver #mentioned_values).
# · regresar: una o varias columnas, separadas por coma.
#
# Sin IA: comparación exacta sobre las filas crudas
# (google_sheet_rows, que desde F0 se guardan también en modo FAQ). Sin coincidencias no
# se completa nada. Plan: docs/hoja_buscar_plan.md
# ================================================================================

class ContactTrackings::SheetLookup
  DIRECTIVE_RE = /\{\{\s*hoja_buscar\s*:([^{}]*)\}\}/i
  ASK = '?'
  # Cuántos mensajes atrás se buscan los valores del «?». Los últimos bastan: es lo que
  # se está hablando ahora, no lo que se dijo hace media conversación.
  RECENT_MESSAGES = 6

  Filter = Struct.new(:column, :wanted, keyword_init: true) do
    def ask?
      wanted == ASK
    end
  end

  Spec = Struct.new(:sheet, :filters, :returns, keyword_init: true) do
    def asked_filter
      filters.find(&:ask?)
    end
  end

  # status: :ok · :sheet_missing · :column_missing · :needs_value (nadie nombró un valor) · :no_match
  # source_message_id: el mensaje de donde salió el «?» (para saber si se nombró AHORA).
  Result = Struct.new(:status, :rows, :found, :asked, :missing, :source_message_id, keyword_init: true) do
    def ok?
      status == :ok
    end
  end

  # Todas las directivas bien escritas de un texto. Una mal escrita (le falta una de las
  # tres partes) no se devuelve: la marca el comprobador.
  def self.parse_all(text)
    text.to_s.scan(DIRECTIVE_RE).filter_map { |(inner)| parse(inner) }
  end

  def self.parse(inner)
    parts = inner.to_s.split('|', -1).map(&:strip)
    return nil unless parts.size == 3 && parts.all?(&:present?)

    sheet, where, returns = parts
    filters = parse_filters(where)
    filters && Spec.new(sheet: sheet, filters: filters, returns: returns.split(',').map(&:strip).compact_blank)
  end

  # nil si alguna condición está mal escrita (sin «=» o sin valor).
  def self.parse_filters(where)
    filters = where.split(';').map(&:strip).compact_blank.map { |cond| parse_filter(cond) }
    filters if filters.any? && filters.none?(&:nil?)
  end
  private_class_method :parse_filters

  def self.parse_filter(cond)
    column, wanted = cond.split('=', 2).map { |part| part.to_s.strip }
    return nil if column.blank? || wanted.blank?

    Filter.new(column: column, wanted: wanted == ASK ? ASK : wanted.split(',').map(&:strip).compact_blank)
  end
  private_class_method :parse_filter

  # La columna Calendar_ID de la hoja trae el link para ver el calendario
  # (…/calendar/embed?src=<id>%40group.calendar.google.com&ctz=…). La agenda necesita el id.
  def self.calendar_id(value)
    text = value.to_s.strip
    return text unless text.match?(%r{\Ahttps?://}i)

    src = URI.decode_www_form(URI.parse(text).query.to_s).to_h['src']
    src.presence || text
  rescue URI::InvalidURIError
    text
  end

  def initialize(account, spec, conversation: nil)
    @account = account
    @spec = spec
    @conversation = conversation
  end

  def call
    source = sheet_source
    return Result.new(status: :sheet_missing) if source.nil?

    rows = source.google_sheet_rows.order(:row_index).pluck(:data)
    missing = missing_columns(rows)
    return Result.new(status: :column_missing, missing: missing) if missing.any?

    filtered, asked = apply_filters(rows)
    return Result.new(status: :needs_value, asked: @spec.asked_filter.column) if asked == :none
    return Result.new(status: :no_match, asked: asked) if filtered.empty?

    Result.new(status: :ok, rows: filtered, asked: asked, source_message_id: @mentioned_in,
               found: filtered.flat_map { |row| @spec.returns.map { |col| cell(row, col) } }.compact_blank.uniq)
  end

  private

  def sheet_source
    @account.knowledge_sources.active.where(source_type: 'google_sheet')
            .find_by('LOWER(name) = LOWER(?)', @spec.sheet)
  end

  def missing_columns(rows)
    headers = rows.first.to_h.keys.map { |h| norm(h) }
    (@spec.filters.map(&:column) + @spec.returns).reject { |col| headers.include?(norm(col)) }.uniq
  end

  # Devuelve [filas, valores tomados de la conversación]. Si el «?» no encontró nada,
  # los valores son :none: no se busca en todas las filas, se pregunta.
  def apply_filters(rows)
    asked = nil
    filtered = @spec.filters.reduce(rows) do |acc, filter|
      wanted = filter.wanted
      if filter.ask?
        asked = wanted = mentioned_values(filter.column, rows)
        return [[], :none] if wanted.empty?
      end
      keys = wanted.map { |v| loose(v) }
      acc.select { |row| keys.include?(loose(cell(row, filter.column))) }
    end
    [filtered, asked]
  end

  # Los valores de la columna que aparecen en los últimos mensajes. Decisión del usuario
  # (25/09/2026): si el cliente nombró alguno, valen los que nombró; si no, los que ofreció
  # el agente en su último mensaje que nombra alguno. Todos los nombrados, no solo uno.
  def mentioned_values(column, rows)
    known = rows.map { |row| cell(row, column).to_s.strip }.compact_blank.uniq
    return [] if known.empty? || @conversation.nil?

    cliente, agente = recent_messages.partition(&:incoming?)
    first_mention(cliente, known) || first_mention(agente, known) || []
  end

  # Del más reciente al más viejo: los valores del primer mensaje que nombra alguno.
  def first_mention(messages, known)
    messages.each do |msg|
      found = known.select { |value| mentions?(msg.content.to_s, value) }
      next if found.empty?

      @mentioned_in = msg.id
      return found
    end
    nil
  end

  def recent_messages
    @conversation.messages.where(message_type: %i[incoming outgoing], private: false)
                 .where.not(content: [nil, '']).reorder(created_at: :desc, id: :desc).limit(RECENT_MESSAGES).to_a
  end

  # «TP-64», «tp 64» y «TP64» son el mismo remolque; «TP-6» no es «TP-64».
  def mentions?(text, value)
    parts = value.scan(/[[:alnum:]]+/)
    return false if parts.empty?

    text.match?(/(?<![[:alnum:]])#{parts.map { |p| Regexp.escape(p) }.join('[\s\-_.]*')}(?![[:alnum:]])/i)
  end

  def cell(row, column)
    key = row.keys.find { |k| norm(k) == norm(column) }
    key && row[key]
  end

  # Para comparar valores: «TP-63», «tp 63» y «TP63» son lo mismo.
  def loose(value)
    value.to_s.downcase.scan(/[[:alnum:]]+/).join
  end

  def norm(value)
    value.to_s.strip.downcase.gsub(/\s+/, ' ')
  end
end
