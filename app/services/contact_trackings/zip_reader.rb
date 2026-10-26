# frozen_string_literal: true

# ================================================================================
# proyecto@solicitudes — LECTOR ZIP MÍNIMO (pieza 7, 26/09/2026)
# ================================================================================
# Un .xlsx y un .docx son ZIP con XML adentro. El proyecto no trae rubyzip y agregar una
# gema implica bundle install y reiniciar el servidor; esto lee lo que hace falta con Zlib
# (librería estándar): el directorio central y cada entrada guardada o comprimida (deflate).
# ================================================================================

class ContactTrackings::ZipReader
  EOCD = [0x06054b50].pack('V')
  CENTRAL = 0x02014b50
  LOCAL = 0x04034b50
  MAX_ENTRY = 20 * 1024 * 1024

  def initialize(bytes)
    @bytes = bytes.b
  end

  # { 'xl/sharedStrings.xml' => '<?xml…', … } — solo lo que se pide (o todo, sin filtro).
  def entries(only: nil)
    central_directory.each_with_object({}) do |(nombre, metodo, tamano, offset), acc|
      next if only && !only.call(nombre)
      next if tamano > MAX_ENTRY

      acc[nombre] = read_entry(metodo, tamano, offset)
    end
  end

  private

  def central_directory
    fin = @bytes.rindex(EOCD)
    raise 'no es un ZIP' if fin.nil?

    total, _tam, pos = @bytes[fin + 10, 10].unpack('vVV')
    Array.new(total) do
      entrada, pos = central_entry(pos)
      entrada
    end
  end

  # [[nombre, método, tamaño comprimido, offset del encabezado local], siguiente posición]
  def central_entry(pos)
    raise 'directorio ZIP roto' unless @bytes[pos, 4].unpack1('V') == CENTRAL

    metodo = @bytes[pos + 10, 2].unpack1('v')
    tamano = @bytes[pos + 20, 4].unpack1('V')
    largo_nombre, largo_extra, largo_coment = @bytes[pos + 28, 6].unpack('vvv')
    offset = @bytes[pos + 42, 4].unpack1('V')
    nombre = @bytes[pos + 46, largo_nombre].force_encoding('UTF-8')
    [[nombre, metodo, tamano, offset], pos + 46 + largo_nombre + largo_extra + largo_coment]
  end

  def read_entry(metodo, tamano, offset)
    raise 'entrada ZIP rota' unless @bytes[offset, 4].unpack1('V') == LOCAL

    largo_nombre, largo_extra = @bytes[offset + 26, 4].unpack('vv')
    datos = @bytes[offset + 30 + largo_nombre + largo_extra, tamano]
    texto = metodo == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(datos) : datos
    texto.force_encoding('UTF-8').scrub
  end
end
