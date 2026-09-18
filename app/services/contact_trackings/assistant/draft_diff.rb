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
# Las piezas que se comparan salen de DraftPieces: cada @ruta por nombre, la
# @ruta_por_defecto, cada [SECCIÓN] por su rótulo —sea cual sea— y la prosa antes del
# primer rótulo. Se compara con los espacios normalizados: reacomodar un salto de
# línea no es un cambio que valga la pena mostrar.
#
# DESTRUCTIVO: borrar cualquier pieza, o cambiar una rama. Es lo que no se puede
# dejar pasar sin declarar: una rama con otra descripción rutea distinto, y una
# sección borrada se lleva reglas que nadie pidió quitar. Agregar, o retocar el texto
# de una sección, se muestra pero no justifica otra llamada.
# ================================================================================

class ContactTrackings::Assistant::DraftDiff
  DEFAULT_KEY = ContactTrackings::Assistant::DraftPieces::DEFAULT_KEY
  PREAMBLE_KEY = ContactTrackings::Assistant::DraftPieces::PREAMBLE_KEY

  # `slug`: la clave normalizada, la que sirve para cruzar con otras listas.
  Change = Struct.new(:key, :kind, :route, :slug, keyword_init: true) do
    def destructive? = kind == :removed || (route && kind == :changed)
  end

  def self.normalize_key(key)
    ContactTrackings::Assistant::DraftPieces.normalize_key(key)
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
    changes.reject { |change| nombrados.include?(change.slug) }
  end

  private

  def pieces(text)
    ContactTrackings::Assistant::DraftPieces.new(text).pieces
  end

  def compare(antes, despues)
    (antes.keys + despues.keys).uniq.filter_map do |slug|
      kind = kind_of(antes[slug], despues[slug])
      next if kind.nil?

      pieza = despues[slug] || antes[slug]
      Change.new(key: pieza.label, kind: kind, route: pieza.route, slug: slug)
    end
  end

  def kind_of(viejo, nuevo)
    return :added if viejo.nil?
    return :removed if nuevo.nil?

    :changed if viejo.value != nuevo.value
  end
end
