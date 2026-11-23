# frozen_string_literal: true

require 'csv'

# Cobranza — la cartera desde un archivo (Excel .xlsx o CSV): la primera fuente del corte (Receivables::Snapshot).
# Reconoce las columnas de la plantilla por su nombre (sin importar mayúsculas ni acentos) y también el Excel propio de
# la empresa con un mapeo { 'folio' => 'Factura', 'balance' => 'Saldo pendiente', … } que se guarda en la cuenta para
# los siguientes cortes.
#
#   sheet = Receivables::Spreadsheet.new(file, mapping: {})
#   sheet.headers  → los encabezados del archivo
#   sheet.mapping  → { 'customer_name' => 'Cliente', … } (lo reconocido + lo que dijo la empresa)
#   sheet.rows     → [[línea, { customer_name: 'Grúas', … }], …] (sin normalizar: Receivables::Row lo hace)
class Receivables::Spreadsheet
  Invalid = Class.new(StandardError)
  MAX_ROWS = 20_000
  ALIASES = {
    customer_key: %w[clavecliente clave cvecliente numerocliente nocliente idcliente codigocliente],
    customer_name: %w[cliente razonsocial nombrecliente nombre],
    rfc: %w[rfc],
    contact_name: %w[contacto nombrecontacto atencion],
    phone: %w[whatsapp telefono celular movil tel],
    email: %w[correo email correoelectronico mail],
    folio: %w[folio factura nofactura numerofactura documento serieyfolio],
    issued_on: %w[fechafactura fecha fechaemision fechadocumento],
    due_on: %w[vencimiento fechavencimiento fechadevencimiento vence],
    total: %w[total importe montototal],
    balance: %w[saldo saldopendiente adeudo pendiente porpagar],
    currency: %w[moneda divisa],
    collector_email: %w[cobrador vendedor ejecutivo responsable]
  }.freeze

  def initialize(file, mapping: {})
    @file = file
    @custom = mapping.to_h.transform_keys(&:to_s).compact_blank
  end

  def headers = @headers ||= table.first.to_a.map { |h| h.to_s.strip }

  def mapping
    @mapping ||= Receivables::Row::FIELDS.each_with_object({}) do |field, out|
      header = @custom[field.to_s].presence_in(headers) || headers.find { |h| ALIASES.fetch(field, []).include?(plain(h)) }
      out[field.to_s] = header if header
    end
  end

  def rows
    index = mapping.transform_values { |h| headers.index(h) }
    table.drop(1).each_with_index.filter_map do |line, i|
      next if line.compact.all? { |v| v.to_s.strip.empty? }

      [i + 2, index.to_h { |field, col| [field.to_sym, line[col]] }]
    end
  end

  private

  def plain(text) = I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]/, '')

  def table
    @table ||= begin
      data = @file.read.to_s
      rows = xlsx?(data) ? Receivables::XlsxReader.rows(data) : csv(data)
      raise Invalid, 'El archivo está vacío.' if rows.size < 2
      raise Invalid, "El archivo trae más de #{MAX_ROWS} renglones: divídelo." if rows.size > MAX_ROWS + 1

      rows
    end
  rescue Receivables::XlsxReader::Invalid, CSV::MalformedCSVError => e
    raise Invalid, e.message
  end

  def xlsx?(data) = data.b.start_with?("PK\x03\x04".b)

  def csv(data)
    text = data.force_encoding('UTF-8')
    text = data.force_encoding('ISO-8859-1').encode('UTF-8') unless text.valid_encoding?
    text = text.delete_prefix('﻿')
    first = text.lines.first.to_s
    CSV.parse(text, col_sep: first.count(';') > first.count(',') ? ';' : ',')
  end
end
