# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUÉ CAMBIÓ DE VERDAD ENTRE DOS ENTRENAMIENTOS
# ================================================================================
# Cuando el Asistente modifica un Entrenamiento, devuelve el texto COMPLETO y declara
# qué tocó. La declaración no alcanza: medido el 15/09/2026 sobre el v6.11, al pedirle
# una rama de facturación agregó la línea @ruta Y una línea en [ETIQUETAS], y declaró
# solo la rama. Lo que cambió se saca de acá, comparando los dos textos; lo que el
# modelo declara sirve para una sola cosa: detectar lo que tocó SIN AVISAR.
#
# LAS PIEZAS QUE SE COMPARAN — las mismas que ve quien edita:
#   @ruta(nombre)       cada rama, por nombre: descripción, etiqueta, fuente, escalamiento
#   @ruta_por_defecto
#   [SECCIÓN]           cada sección de la prosa, por su rótulo, sea cual sea. No se
#                       asume la lista del contrato: un prompt escrito a mano tiene las
#                       suyas ([NO SIMULAR], [GESTION EN CURSO]…) y valen igual.
#   (sin sección)       la prosa que va antes del primer rótulo
#
# Se compara con los espacios normalizados: reacomodar un salto de línea no es un
# cambio que valga la pena mostrar.
#
# DESTRUCTIVO: borrar cualquier pieza, o cambiar una rama. Es lo que no se puede
# dejar pasar sin declarar: una rama con otra descripción rutea distinto, y una
# sección borrada se lleva reglas que nadie pidió quitar. Agregar, o retocar el texto
# de una sección, se muestra pero no justifica otra llamada.
# ================================================================================

class ContactTrackings::Assistant::DraftDiff
  SECTION_RE = /^[ \t]*\[([^\]\n]+)\][ \t]*$/
  DEFAULT_KEY = '@ruta_por_defecto'
  PREAMBLE_KEY = '(sin sección)'

  Change = Struct.new(:key, :kind, :route, keyword_init: true) do
    def destructive? = kind == :removed || (route && kind == :changed)
  end

  def self.normalize_key(key)
    key.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase.gsub(/\s+/, ' ').strip
  end

  def initialize(before, after)
    @before = before.to_s
    @after = after.to_s
  end

  def changes
    @changes ||= compare(pieces(@before), pieces(@after))
  end

  delegate :empty?, to: :changes

  # Lo que cambió y el modelo no nombró en `toca`.
  def undeclared(declared)
    nombrados = Array(declared).map { |key| self.class.normalize_key(key) }
    changes.reject { |change| nombrados.include?(self.class.normalize_key(change.key)) }
  end

  private

  def compare(antes, despues)
    (antes.keys + despues.keys).uniq.filter_map do |key|
      kind = kind_of(antes[key], despues[key])
      next if kind.nil?

      pieza = despues[key] || antes[key]
      Change.new(key: pieza[:label], kind: kind, route: pieza[:route])
    end
  end

  def kind_of(viejo, nuevo)
    return :added if viejo.nil?
    return :removed if nuevo.nil?

    :changed if viejo[:value] != nuevo[:value]
  end

  # { clave_normalizada => { label:, value:, route: } }
  def pieces(text)
    map = ContactTrackings::RouteMap.parse(text)
    piezas = {}

    map.routes.each do |route|
      add(piezas, "@ruta(#{route.name})", route.to_h.transform_values { |v| v.to_s.squish }, route: true)
    end
    default = text[ContactTrackings::RouteMap::DEFAULT_RE, 1]
    add(piezas, DEFAULT_KEY, default.to_s.downcase) if default

    sections(ContactTrackings::RouteMap.strip(text)).each { |label, body| add(piezas, label, body.squish) }
    piezas
  end

  # Un rótulo repetido no pisa al primero: se numera, así borrar el segundo
  # [ESTILO] también se ve.
  def add(piezas, label, value, route: false)
    key = self.class.normalize_key(label)
    key = "#{key}##{piezas.keys.count { |k| k.split('#').first == key } + 1}" if piezas.key?(key)
    piezas[key] = { label: label, value: value, route: route }
  end

  def sections(prose)
    partes = prose.split(SECTION_RE)
    resultado = []
    inicio = partes.shift.to_s
    resultado << [PREAMBLE_KEY, inicio] if inicio.strip.present?
    partes.each_slice(2) { |nombre, cuerpo| resultado << ["[#{nombre.strip}]", cuerpo.to_s] }
    resultado
  end
end
