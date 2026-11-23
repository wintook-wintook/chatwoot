# frozen_string_literal: true

require 'zlib'

# Cobranza — lee la primera hoja de un .xlsx sin gemas extra: un .xlsx es un ZIP con XML adentro. Se lee el directorio
# del ZIP, se descomprime (Zlib) cada parte que hace falta y se arma la tabla con Nokogiri.
#
#   Receivables::XlsxReader.rows(io_or_string) → [['Cliente', 'Folio', …], ['Grúas', 'A-1', 45500.0, …], …]
# Las celdas de texto salen como String; las de número, como Float (las fechas de Excel son números: se convierten en
# Receivables::Row). Lanza Receivables::XlsxReader::Invalid si no es un .xlsx.
module Receivables::XlsxReader
  Invalid = Class.new(StandardError)
  EOCD = "PK\x05\x06".b
  CENTRAL = "PK\x01\x02".b
  LOCAL = "PK\x03\x04".b

  module_function

  def rows(input)
    data = input.respond_to?(:read) ? input.read : input.to_s
    entries = zip_entries(data.b)
    shared = shared_strings(entries['xl/sharedStrings.xml'] && extract(data.b, entries['xl/sharedStrings.xml']))
    sheet = entries.keys.grep(%r{\Axl/worksheets/sheet\d+\.xml\z}).min_by { |k| k[/\d+/].to_i }
    raise Invalid, 'El archivo no trae hojas.' unless sheet

    sheet_rows(extract(data.b, entries[sheet]), shared)
  end

  # { 'ruta' => { offset:, method:, size: } } del directorio central del ZIP.
  def zip_entries(data)
    eocd = data.rindex(EOCD) or raise Invalid, 'No es un archivo de Excel (.xlsx).'
    pos = data[eocd + 16, 4].unpack1('V')
    data[eocd + 10, 2].unpack1('v').times.each_with_object({}) do |_, out|
      raise Invalid, 'El archivo de Excel está dañado.' unless data[pos, 4] == CENTRAL

      name, entry, pos = central_entry(data, pos)
      out[name] = entry
    end
  end

  # Una entrada del directorio central: [nombre, { offset:, method:, size: }, posición de la siguiente].
  def central_entry(data, pos)
    method = data[pos + 10, 2].unpack1('v')
    size = data[pos + 20, 4].unpack1('V')
    name_len, extra_len, comment_len = data[pos + 28, 6].unpack('vvv')
    offset = data[pos + 42, 4].unpack1('V')
    name = data[pos + 46, name_len].force_encoding('UTF-8')
    [name, { offset: offset, method: method, size: size }, pos + 46 + name_len + extra_len + comment_len]
  end

  def extract(data, entry)
    raise Invalid, 'El archivo de Excel está dañado.' unless data[entry[:offset], 4] == LOCAL

    name_len, extra_len = data[entry[:offset] + 26, 4].unpack('vv')
    raw = data[entry[:offset] + 30 + name_len + extra_len, entry[:size]]
    text = entry[:method].zero? ? raw : Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw)
    text.force_encoding('UTF-8')
  end

  def shared_strings(xml)
    return [] unless xml

    Nokogiri::XML(xml).remove_namespaces!.xpath('//si').map { |si| si.xpath('.//t').map(&:text).join }
  end

  def sheet_rows(xml, shared)
    Nokogiri::XML(xml).remove_namespaces!.xpath('//sheetData/row').map do |row|
      row.xpath('c').each_with_object([]) do |cell, line|
        line[column_index(cell['r'])] = cell_value(cell, shared)
      end
    end
  end

  def cell_value(cell, shared)
    value = cell.at_xpath('v')&.text
    case cell['t']
    when 's' then shared[value.to_i]
    when 'inlineStr' then cell.xpath('.//t').map(&:text).join
    when 'str', 'b' then value
    else value&.to_f
    end
  end

  # 'C7' → 2
  def column_index(ref)
    ref.to_s[/\A[A-Z]+/].to_s.chars.reduce(0) { |n, c| (n * 26) + (c.ord - 64) } - 1
  end
end
