# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — QUÉ HACE EL AGENTE CON UNA HOJA
# ================================================================================
# Pedido del usuario (10/11/2026): «observar lo que contiene al seleccionar una hoja…
# para contextualizar lo que el agente debe hacer con ese contenido». En la ficha, cada
# hoja marcada puede decir:
#   purpose      para qué la usa («lista de precios: contestar el precio exacto»)
#   search_by    la columna por la que busca lo que pide el cliente
#   answer_with  las columnas con que contesta
# y con eso se escribe su ruta: {{hoja_buscar: Hoja | search_by=? | answer_with}}.
# Solo columnas que existen en la hoja.
# ================================================================================

module ContactTrackings::Ficha::SheetUse
  KEY_RE = /\{\{\s*hoja_buscar:\s*[^|]+\|\s*([^=|]+?)\s*=\s*\?\s*\|\s*([^}]+)\}\}/
  PREVIEW_ROWS = 6
  MAX_VALUE = 80
  MAX_PURPOSE = 200

  module_function

  # La búsqueda sugerida de SourceProfiles ({{hoja_buscar: …}}) → { search_by:, answer_with: }
  def parse(directiva)
    clave, regresa = directiva.to_s.match(KEY_RE)&.captures
    { search_by: clave&.strip, answer_with: regresa.to_s.split(',').map(&:strip).compact_blank }
  end

  # Lo que manda la pantalla, limpio contra las columnas reales. nil si no sirve.
  def clean(config, columnas)
    h = config.to_h.stringify_keys
    clave = h['search_by'].to_s.strip
    regresa = Array(h['answer_with']).map { |c| c.to_s.strip } & columnas
    proposito = h['purpose'].to_s.squish.tr('()', '  ').squish.first(MAX_PURPOSE)
    return nil if proposito.blank? && columnas.exclude?(clave)

    { 'purpose' => proposito.presence, 'search_by' => (clave if columnas.include?(clave)),
      'answer_with' => (regresa - [clave]).presence }.compact
  end

  def directive(nombre, config)
    return nil if config['search_by'].blank? || Array(config['answer_with']).empty?

    "{{hoja_buscar: #{nombre} | #{config['search_by']}=? | #{config['answer_with'].join(', ')}}}"
  end

  # Lo que se ve al abrir la hoja en la ficha: columnas y las primeras filas.
  def preview(hoja)
    filas = hoja.google_sheet_rows.order(:row_index).limit(PREVIEW_ROWS).map(&:data)
    columnas = filas.first&.keys || []
    { id: hoja.id, name: hoja.name, columns: columnas, total: hoja.google_sheet_rows.count,
      rows: filas.map { |d| columnas.map { |c| d[c].to_s.truncate(MAX_VALUE) } } }
  end
end
