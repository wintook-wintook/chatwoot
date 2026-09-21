# frozen_string_literal: true

# @query_databases — Directiva {{consulta:}} desde el agente de seguimiento.
# Interpola in-place cada {{consulta:...}} del texto por el resultado de una consulta
# predefinida (allowlist), de forma DETERMINISTA (sin IA). Fail-soft: una directiva
# inválida se reemplaza por vacío y nunca revienta el mensaje completo.
#
# Sintaxis:
#   {{consulta:nombre}}                     sin parámetros
#   {{consulta:nombre(valor)}}              posicional → primer param del schema
#   {{consulta:nombre(rfc=XXX)}}            nombrado
#   {{consulta:nombre(rfc=XXX, dias=30)}}   varios nombrados
#   {{consulta:sae/nombre(rfc=XXX)}}        con prefijo de conexión (erp_type o nombre)
#
# Resolución de conexión:
#   con prefijo  → ExternalDbConnection por erp_type o por nombre (scoped a la cuenta)
#   sin prefijo  → conexión del ErpCollectionBot activo del inbox (específico > global)
#
# proyecto@erp_productos — PARÁMETROS "?" (docs/erp_productos_plan.md §3):
#   {{consulta:buscar_productos(linea=COMPUTO, texto=?, precio_max=?)}}
#   Un "?" significa "lo llena la IA con lo que escribió el cliente" (lo hace el motor,
#   F2); los valores fijos siempre ganan. Este archivo solo LEE la directiva: `.parse`
#   la devuelve como datos (fijos y pedidos por separado) para el motor y el comprobador.
#   El render de siempre no cambia: una directiva sin "?" se interpola igual que antes, y
#   si alguna con "?" llegara acá, el "?" nunca viaja como valor a la consulta.
class ExternalDb::ConsultaDirectiveRenderer
  DIRECTIVE = %r!\{\{consulta:(?:(?<conn>[a-z0-9_]+)/)?(?<name>[a-z0-9_]+)(?:\((?<args>[^}]*)\))?\}\}!i

  RFC_PARAM = 'rfc'
  CONTACT_RFC_ATTR = 'erp_rfc'
  ASKED = '?'

  # Una {{consulta:}} leída: `fixed` son los valores que escribió quien arma el agente;
  # `asked`, los parámetros que tiene que llenar la IA ("?"). `positional` es el valor
  # suelto de {{consulta:nombre(valor)}}, que va al primer parámetro de la consulta.
  Directive = Struct.new(:raw, :conn, :name, :fixed, :asked, :positional, keyword_init: true) do
    def asks?
      asked.any?
    end
  end

  def self.contains?(text)
    text.to_s.match?(DIRECTIVE)
  end

  def self.parse(text)
    text.to_s.to_enum(:scan, DIRECTIVE).map { directive_from(Regexp.last_match) }
  end

  def self.directive_from(match)
    parts = match[:args].to_s.split(',').map(&:strip).reject(&:blank?)
    named = named_pairs(parts)
    Directive.new(raw: match[0], conn: match[:conn], name: match[:name],
                  fixed: named.reject { |_, v| v == ASKED }, asked: named.select { |_, v| v == ASKED }.keys,
                  positional: parts.find { |p| p.exclude?('=') })
  end

  def self.named_pairs(parts)
    parts.select { |p| p.include?('=') }.to_h { |p| p.split('=', 2).map(&:strip) }.reject { |k, _| k.blank? }
  end
  private_class_method :directive_from, :named_pairs

  # ¿Alguna {{consulta:}} del texto pide parámetros a la IA?
  def self.asks?(text)
    parse(text).any?(&:asks?)
  end

  def initialize(account:, contact: nil, inbox: nil)
    @account = account
    @contact = contact
    @inbox = inbox
  end

  # Reemplaza CADA {{consulta:...}} por su resultado; el resto del texto queda igual.
  def render(text)
    text.to_s.gsub(DIRECTIVE) do
      m = Regexp.last_match
      render_one(m[:conn], m[:name], m[:args]).to_s
    end
  end

  # La conexión y la consulta de una directiva ya leída, o nil. La usa el motor (F2) con
  # las mismas reglas de conexión que el render.
  def resolve(directive)
    connection = resolve_connection(directive.conn)
    connection&.external_db_queries&.active&.find_by('LOWER(name) = LOWER(?)', directive.name)
  end

  # Los parámetros finales de una directiva con "?": lo que llenó la IA, pisado por los
  # valores fijos (siempre ganan), más el posicional y el RFC del contacto como siempre.
  def params_for(directive, query, asked_values)
    params = asked_values.to_h.transform_keys(&:to_s).merge(directive.fixed)
    params.merge!(positional_arg(directive.positional, query)) { |_, current, _| current } if directive.positional
    fill_rfc_from_contact(query, params)
    params
  end

  private

  def render_one(conn_key, name, args_str)
    connection = resolve_connection(conn_key)
    return log_skip("conexión no resuelta (#{conn_key || 'inbox'})") if connection.nil?

    query = connection.external_db_queries.active.find_by('LOWER(name) = LOWER(?)', name)
    return log_skip("consulta '#{name}' inexistente o inactiva") if query.nil?

    params = parse_args(args_str, query)
    fill_rfc_from_contact(query, params)

    result = ExternalDb::QueryRunner.new(query, params).perform
    render_result(query, result)
  rescue StandardError => e
    log_skip("#{name}: #{e.message}")
  end

  def resolve_connection(conn_key)
    scope = @account.external_db_connections.active
    return connection_by_prefix(scope, conn_key.downcase) if conn_key.present?

    inbox_bot_connection
  end

  def connection_by_prefix(scope, key)
    if ExternalDbConnection.erp_types.key?(key)
      by_type = scope.where(erp_type: key).first
      return by_type if by_type
    end
    scope.detect { |c| c.name.to_s.downcase.delete(' ') == key.delete(' ') }
  end

  # Sin prefijo → replica ChatResponseJob#find_bot: bot activo del inbox (o global).
  def inbox_bot_connection
    @account.erp_collection_bots.active
            .where(inbox_id: [@inbox&.id, nil])
            .order(Arel.sql('inbox_id IS NULL'))
            .first
            &.external_db_connection
  end

  # "rfc=X, dias=30" → { 'rfc' => 'X', 'dias' => '30' }
  # "X"             → { <primer_param> => 'X' } (posicional)
  def parse_args(args_str, query)
    parts = args_str.to_s.split(',').map(&:strip).reject(&:blank?)
    return {} if parts.empty?

    return named_args(parts) if parts.any? { |p| p.include?('=') }

    positional_arg(parts.first, query)
  end

  # Un "?" no es un valor: en el camino determinista el parámetro queda sin dar.
  def named_args(parts)
    parts.each_with_object({}) do |pair, acc|
      key, value = pair.split('=', 2).map(&:strip)
      acc[key] = value if key.present? && value != ASKED
    end
  end

  def positional_arg(value, query)
    first_key = Array(query.params_schema).first&.then { |p| p['key'] || p[:key] }
    first_key.present? ? { first_key => value } : {}
  end

  # Si la consulta usa :rfc y no vino, se toma del contacto (custom_attribute erp_rfc).
  def fill_rfc_from_contact(query, params)
    return unless query_needs_rfc?(query)
    return if params[RFC_PARAM].to_s.strip.present?

    rfc = @contact&.custom_attributes&.dig(CONTACT_RFC_ATTR).to_s.strip
    params[RFC_PARAM] = rfc if rfc.present?
  end

  def query_needs_rfc?(query)
    Array(query.params_schema).any? { |p| (p['key'] || p[:key]).to_s == RFC_PARAM }
  end

  def render_result(query, result)
    return '' if result.rows.empty?

    query.format_summary? ? render_summary(result) : render_table(result)
  end

  # 1 valor legible (p.ej. saldo 1x1) o los valores de la primera fila unidos.
  def render_summary(result)
    row = result.rows.first
    values = result.columns.map { |c| format_value(row[c]) }
    values.length == 1 ? values.first : values.join(' · ')
  end

  # Lista compacta: una línea por fila.
  def render_table(result)
    result.rows.map do |row|
      "• #{result.columns.map { |c| format_value(row[c]) }.join(' · ')}"
    end.join("\n")
  end

  # Montos a 2 decimales, fechas sin hora; el resto tal cual (igual que ErpCollectionBot).
  def format_value(value)
    case value
    when Float, BigDecimal then format('%.2f', value)
    when Time, DateTime, ActiveSupport::TimeWithZone, Date then value.strftime('%d/%m/%Y')
    when nil then ''
    else value.to_s
    end
  end

  def log_skip(reason)
    Rails.logger.warn "[ConsultaDirective] ⏭️ #{reason}"
    ''
  end
end
