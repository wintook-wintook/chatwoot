# ================================================================================
# proyecto@ai_agent_assistant - F4
# ================================================================================
# Servicio: AiAgentAssistant::VersionDiff
# Descripción: Compara dos snapshots de un Agente IA y devuelve, campo por campo,
#              qué líneas se quitaron y cuáles se pusieron.
#
# Motivo: hoy comparar la V3 con la V4 de un agente significa mirar a ojo 3 326
# contra 4 031 caracteres. El diff por líneas es lo que convierte «cambió el
# prompt» en «se quitó la regla de cierre y se agregó una directiva».
#
# Todo campo se normaliza a texto multilínea (las listas y los mapas se serializan
# de forma legible) para que un único algoritmo sirva para los quince campos.
# ================================================================================

class AiAgentAssistant::VersionDiff
  def self.between(from_snapshot, to_snapshot)
    new(from_snapshot, to_snapshot).call
  end

  def initialize(from_snapshot, to_snapshot)
    @from = (from_snapshot || {}).stringify_keys
    @to   = (to_snapshot || {}).stringify_keys
  end

  def call
    TrackingTemplateVersion::VERSIONED_FIELDS.filter_map { |field| entry_for(field) }
  end

  # Diff por líneas sobre la subsecuencia común más larga. Los prompts rondan las
  # 100 líneas, así que la tabla O(n·m) es de sobra.
  def self.line_ops(before, after)
    a = before.to_s.split("\n")
    b = after.to_s.split("\n")
    return [] if a.empty? && b.empty?

    walk_back(lcs_table(a, b), a, b)
  end

  def self.lcs_table(rows, cols)
    table = Array.new(rows.size + 1) { Array.new(cols.size + 1, 0) }
    rows.each_index do |i|
      cols.each_index do |j|
        table[i + 1][j + 1] = rows[i] == cols[j] ? table[i][j] + 1 : [table[i][j + 1], table[i + 1][j]].max
      end
    end
    table
  end
  private_class_method :lcs_table

  # Recorre la tabla desde la esquina y emite las operaciones en orden inverso; lo que
  # sobra de cualquiera de los dos lados al llegar a un borde es alta o baja pura.
  def self.walk_back(table, rows, cols)
    ops = []
    i = rows.size
    j = cols.size

    while i.positive? && j.positive?
      op = step(table, rows[i - 1], cols[j - 1], i, j)
      ops << op
      i -= 1 unless op.first == 'add'
      j -= 1 unless op.first == 'del'
    end

    (ops + tail('add', cols.first(j)) + tail('del', rows.first(i))).reverse
  end
  private_class_method :walk_back

  # Qué operación toca en esta celda: coincidencia, o el lado con más subsecuencia común.
  def self.step(table, row, col, row_idx, col_idx)
    return ['eq', row] if row == col

    table[row_idx][col_idx - 1] >= table[row_idx - 1][col_idx] ? ['add', col] : ['del', row]
  end
  private_class_method :step

  def self.tail(kind, lines)
    lines.reverse.map { |line| [kind, line] }
  end
  private_class_method :tail

  private

  def entry_for(field)
    before = readable(@from[field])
    after  = readable(@to[field])
    return nil if before == after

    { field: field, from: before, to: after,
      lines: self.class.line_ops(before, after) }
  end

  def readable(value)
    case value
    when nil       then ''
    when String    then value
    when Array     then value.map { |item| readable_item(item) }.join("\n")
    when Hash      then value.map { |key, item| "#{key}: #{readable_item(item)}" }.join("\n")
    else value.to_s
    end
  end

  def readable_item(item)
    case item
    when Hash  then item.map { |key, value| "#{key}=#{value}" }.join(' · ')
    when Array then item.join(', ')
    else item.to_s
    end
  end
end
