# frozen_string_literal: true

# proyecto@hoja_buscar (pieza 2) — las filas que encontró {{hoja_buscar:}}, como texto para el
# modelo: solo las columnas de la búsqueda y las que regresa.
module ContactTrackings::SheetLookup::Describe
  # Lo que regresa, fila por fila y con los criterios: para dárselo al modelo tal cual.
  def describe(spec, rows)
    columnas = (spec.filters.map(&:column) + spec.returns).uniq
    rows.map do |row|
      columnas.filter_map do |col|
        key = row.keys.find { |k| k.to_s.strip.casecmp?(col) }
        "#{key}: #{row[key]}" if key && row[key].present?
      end.join(' · ')
    end
  end
end
