# frozen_string_literal: true

# Cobranza — las filas de un corte ya normalizadas (Receivables::Row), con su clave de cliente y sin folios repetidos
# (si un folio se repite para el mismo cliente, manda la última fila y queda el aviso).
#   rows = Receivables::SnapshotRows.new([[línea, { … }], …])
#   rows.valid  → [{ key:, customer_name:, folio:, due_on:, balance:, … }]
#   rows.errors → [{ row:, reason: }]
class Receivables::SnapshotRows
  attr_reader :valid, :errors

  def initialize(rows)
    @errors = []
    @valid = dedupe(Array(rows).each_with_index.filter_map { |item, i| parse(item, i) })
  end

  # Clave del cliente: la del sistema, o su RFC, o su nombre (en ese orden).
  def self.customer_key(row)
    return "clave:#{row[:customer_key].upcase}" if row[:customer_key]
    return "rfc:#{row[:rfc]}" if row[:rfc]

    "nombre:#{I18n.transliterate(row[:customer_name]).downcase.gsub(/[^a-z0-9]/, '')}"
  end

  def rejected = @errors.count { |e| !e[:duplicate] }

  private

  def parse(item, index)
    line, raw = item.is_a?(Array) ? item : [index + 1, item]
    row, error = Receivables::Row.normalize(raw)
    if error
      @errors << { row: line, reason: error }
      return nil
    end

    row.merge(key: self.class.customer_key(row), line: line)
  end

  def dedupe(rows)
    last = rows.index_by { |r| [r[:key], r[:folio].downcase] }
    (rows - last.values).each do |r|
      winner = last[[r[:key], r[:folio].downcase]]
      @errors << { row: r[:line], reason: "folio #{r[:folio]} repetido: se tomó el de la fila #{winner[:line]}", duplicate: true }
    end
    last.values
  end
end
