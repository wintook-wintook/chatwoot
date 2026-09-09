# frozen_string_literal: true

# ================================================================================
# @knowledge_sources — HTML DE WORDPRESS → TEXTO
# ================================================================================
# Servicio: Wordpress::ContentCleaner
# Descripción: Convierte el HTML de una entrada en el texto que se va a vectorizar.
#
# POR QUÉ IMPORTA MÁS DE LO QUE PARECE:
#   Medido sobre un sitio real (09/09/2026): el HTML crudo promedia 24.700
#   caracteres y el texto limpio 6.286. **Tres de cada cuatro caracteres son
#   markup.** Vectorizar sin limpiar cuadruplica los chunks, cuadruplica el tiempo
#   y —lo peor— mete `<div class="wp-block-group">` dentro de los embeddings, que
#   empeora la búsqueda.
#
# POR QUÉ NOKOGIRI Y NO UNA REGEX:
#   Una regex que borre entidades rompe las palabras:
#     "don&#8217;t &amp; caf&#233;"  →  "don t   caf "     ← regex ingenua
#     "don&#8217;t &amp; caf&#233;"  →  "don’t & café"     ← nokogiri
#   Eso no es cosmético: son los términos que después hay que encontrar.
#
# QUÉ SE CONSERVA Y QUÉ NO:
#   · Los títulos internos (h1..h6) SE CONSERVAN: son señal fuerte de tema.
#   · Los saltos entre bloques SE CONSERVAN: sin ellos dos párrafos se pegan y
#     la última palabra de uno se funde con la primera del otro.
#   · Las listas quedan una por línea, que es como se leen.
#   · De un enlace queda el texto, no la URL: una URL en un embedding es ruido.
#   · Imágenes, iframes, scripts y estilos se van enteros.
#
# NOTA SOBRE GUTENBERG:
#   `content.rendered` viene POST-renderizado: los comentarios `<!-- wp:… -->` y
#   los shortcodes registrados ya no están (verificado sobre 8 entradas reales:
#   cero de cada uno). Igual se limpian, porque un shortcode de un plugin
#   desactivado SÍ aparece crudo en el texto.
# ================================================================================

class Wordpress::ContentCleaner
  # Elementos cuyo contenido no aporta nada al significado del artículo.
  DROPPED = %w[script style noscript iframe embed video audio img figure svg form].freeze
  # Elementos que separan ideas: se convierten en salto para no pegar palabras.
  BLOCK = %w[p div br hr h1 h2 h3 h4 h5 h6 li tr blockquote pre section article header footer].freeze
  # Shortcode de un plugin que no está activo: WordPress lo deja crudo en el texto.
  SHORTCODE = %r{\[/?[a-z][a-z0-9_-]*(?:\s[^\]]*)?\]}i
  # Los comentarios de bloque de Gutenberg, por si llegara HTML sin renderizar.
  BLOCK_COMMENT = %r{<!--\s*/?wp:.*?-->}m

  def self.call(html) = new(html).call

  def initialize(html)
    @html = html.to_s
  end

  def call
    return '' if @html.blank?

    doc = Nokogiri::HTML.fragment(prepare(@html))
    doc.search(*DROPPED).each(&:remove)
    # El salto se inyecta ANTES de pedir el texto: si no, Nokogiri devuelve los
    # bloques pegados y "…del sistema" + "Para actualizar…" quedan como una palabra.
    doc.search(*BLOCK).each { |node| node.add_next_sibling(doc.document.create_text_node("\n")) }

    tidy(doc.text)
  end

  private

  # Lo que hay que sacar por texto, antes de parsear: son cosas que Nokogiri
  # trataría como contenido legítimo.
  def prepare(html)
    html.gsub(BLOCK_COMMENT, ' ').gsub(SHORTCODE, ' ')
  end

  # Todo salto se colapsa a UNO. Sin esto el resultado depende de cómo venga
  # formateado el HTML de origen —un salto si las etiquetas vienen pegadas, dos si
  # vienen en renglones distintos— y el mismo contenido daría chunks distintos según
  # quién lo escribió. El troceador corta por "\n", así que un salto alcanza para
  # marcar dónde termina una idea.
  def tidy(text)
    text.gsub(/ /, ' ')          # &nbsp; ya decodificado
        .gsub(/[ \t]+/, ' ')
        .gsub(/ ?\n ?/, "\n")
        .squeeze("\n")
        .strip
  end
end
