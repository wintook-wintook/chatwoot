# frozen_string_literal: true

# ================================================================================
# @knowledge_sources — QUÉ ENTRA AL ÍNDICE
# ================================================================================
# Servicio: Wordpress::Selection
# Descripción: Resuelve, para cada tipo de contenido, qué ids de WordPress entran.
#
# EL MODELO, EN UNA LÍNEA:
#   la CATEGORÍA es la regla; la LISTA es para las excepciones.
#
#     categories    entra todo lo de estas categorías — y lo que se publique
#                   después en ellas entra solo
#     excluded_ids  excepción hacia afuera: sacar algo que la regla trae
#     included_ids  excepción hacia adentro: meter algo que la regla no cubre
#
# LA EXCEPCIÓN GANA SIEMPRE:
#   Una entrada en excluded_ids NO vuelve a entrar aunque su categoría esté
#   elegida. Si no fuera así, deseleccionar no serviría de nada: la próxima
#   sincronización la traería de vuelta y nadie entendería por qué.
#
# SIN CATEGORÍAS ELEGIDAS ENTRA TODO:
#   Es lo que espera alguien que no tocó el filtro, y es coherente con la API de
#   WordPress, donde no mandar `categories` significa "todas".
#
# "NO HAY NADA ELEGIDO" Y "NO PUDE PREGUNTAR" NO SON LO MISMO:
#   Devolver {} en los dos casos costó caro: el sincronizador leía el vacío de un
#   sitio caído como "el usuario deseleccionó todo" y BORRABA EL ÍNDICE ENTERO,
#   dejando la fuente en `idle` como si hubiera ido bien. Un 403 pasajero o una
#   caída de red se llevaban puesto todo lo que el agente sabía.
#   Por eso `call` devuelve nil cuando el sitio no se pudo consultar, y {} solo
#   cuando la respuesta fue "no hay nada". Solo el segundo autoriza a borrar.
# ================================================================================

class Wordpress::Selection
  def initialize(client, config)
    @client = client
    @config = config.to_h.with_indifferent_access
  end

  # → { 'posts' => [412, 588], 'pages' => [7] }, o nil si el sitio no respondió.
  # Solo los tipos elegidos; un tipo sin nada seleccionado no aparece.
  def call
    @failed = false
    seleccion = content_types.index_with { |type| ids_for(type) }.reject { |_, ids| ids.empty? }

    @failed ? nil : seleccion
  end

  # El listado completo para la pantalla de elegir, con una marca por ítem de si
  # está adentro o no. Es la misma resolución, para que la pantalla no pueda decir
  # una cosa distinta de la que el sincronizador va a hacer.
  def catalog(type)
    result = @client.titles(type)
    return [] unless result.ok?

    seleccion = ids_for(type).to_set
    result.data.map { |item| item.merge(selected: seleccion.include?(item[:id])) }
  end

  private

  def content_types
    Array(@config[:content_types]).presence || []
  end

  # Cada tipo tiene SU taxonomía, y confundirlas no da error: da un filtro que no
  # filtra. Las páginas no tienen ninguna —WordPress ignora el parámetro y devuelve
  # todas—, y las de la tienda son otra lista con otros ids que las del blog.
  CATEGORY_KEY = { 'posts' => :categories, 'products' => :product_categories }.freeze

  def categories_for(type)
    key = CATEGORY_KEY[type]
    return [] if key.nil?

    Array(@config[key]).map(&:to_i)
  end

  def excluded
    Array(@config[:excluded_ids]).to_set(&:to_i)
  end

  def included
    Array(@config[:included_ids]).to_set(&:to_i)
  end

  def ids_for(type)
    # El filtro por categoría lo aplica WordPress, no nosotros: así no se baja el
    # sitio entero para descartar después.
    result = @client.titles(type, categories: categories_for(type))
    # Un tipo que el sitio no tiene (404) no es un fallo; que el sitio no responda, sí.
    unless result.ok?
      @failed = true unless result.error == :not_found
      return []
    end

    por_regla = result.data.pluck(:id)
    # Los sueltos se suman aunque la regla no los cubra; los excluidos se van
    # aunque sí los cubra. Ese orden es la política: la excepción manda.
    ((por_regla.to_set | included_of(type)) - excluded).to_a.sort
  end

  # included_ids no dice de qué tipo es cada id. Se resuelve preguntando por ellos
  # sin filtro de categoría: los que ese tipo reconozca, son suyos.
  def included_of(type)
    return Set.new if included.empty?

    result = @client.items(type, ids: included.to_a)
    result.ok? ? result.data.pluck(:id).to_set : Set.new
  end
end
