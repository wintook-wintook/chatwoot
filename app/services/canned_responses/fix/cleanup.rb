# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — PASO 1: LIMPIAR SIN IA
# ================================================================================
# Lo que ocupa caracteres y el agente no puede usar, en cualquier cuenta:
#
#   image_data   imágenes incrustadas (`data:image/…;base64,…`), con o sin la sintaxis
#                de imagen de Markdown. En dev.wintook.com, «Nuestras redes sociales»
#                (cuenta 553) medía 2,560 y casi todo era un logo en base64.
#   html         etiquetas HTML pegadas desde otra página (<br>, <p>, <span>…). Una
#                liga <a href="URL">texto</a> queda como «texto (URL)»: la URL es dato.
#   entities     &nbsp; &amp; …
#   duplicates   párrafos repetidos tal cual dentro de la misma respuesta
#   spaces       espacios y renglones en blanco de más
#
# No cambia palabras ni datos: solo quita. Regresa el texto y qué quitó.
# ================================================================================

class CannedResponses::Fix::Cleanup
  DATA_URI = %r{data:[a-z]+/[a-z0-9.+-]+;base64,[A-Za-z0-9+/=\s]+}i
  MD_IMAGE_DATA = /!\[[^\]]*\]\(\s*#{DATA_URI}\s*\)/
  LINK_TAG = %r{<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>}im
  BREAK_TAG = %r{<br\s*/?>}i
  BLOCK_TAG = %r{</?(?:p|div|li|ul|ol|tr|table|h[1-6])\b[^>]*>}i
  INLINE_TAG = %r{</?(?:span|strong|b|i|em|u|font|small|td|th|tbody|thead|img|a)\b[^>]*>}i
  ENTITIES = { '&nbsp;' => ' ', '&amp;' => '&', '&lt;' => '<', '&gt;' => '>', '&quot;' => '"', '&#39;' => "'" }.freeze

  Result = Struct.new(:content, :removed, keyword_init: true)

  def self.call(content) = new(content).call

  def initialize(content)
    @text = content.to_s.dup
    @removed = []
  end

  def call
    strip(:image_data) { |t| t.gsub(MD_IMAGE_DATA, '').gsub(DATA_URI, '') }
    strip(:html) { |t| html(t) }
    strip(:entities) { |t| ENTITIES.reduce(t) { |acc, (ent, ch)| acc.gsub(ent, ch) } }
    strip(:duplicates) { |t| without_repeated_paragraphs(t) }
    strip(:spaces) { |t| spaces(t) }
    Result.new(content: @text, removed: @removed)
  end

  private

  def strip(kind)
    antes = @text.size
    @text = yield(@text)
    quitado = antes - @text.size
    @removed << { 'kind' => kind.to_s, 'chars' => quitado } if quitado.positive?
  end

  def html(text)
    text.gsub(LINK_TAG) { link_text(Regexp.last_match(1), Regexp.last_match(2)) }
        .gsub(BREAK_TAG, "\n").gsub(BLOCK_TAG, "\n").gsub(INLINE_TAG, '')
  end

  def link_text(url, label)
    label = label.to_s.gsub(INLINE_TAG, '').strip
    label.empty? || label == url ? url : "#{label} (#{url})"
  end

  def without_repeated_paragraphs(text)
    vistos = Set.new
    text.split(/(\n\s*\n)/).each_slice(2).filter_map do |parrafo, separador|
      clave = parrafo.to_s.downcase.gsub(/\s+/, ' ').strip
      next if clave.length >= 20 && !vistos.add?(clave)

      "#{parrafo}#{separador}"
    end.join
  end

  # Espacios dobles dentro del renglón (no la sangría de una lista), espacios al final
  # del renglón y más de un renglón en blanco seguido.
  def spaces(text)
    text.gsub(/(?<=\S)[ \t]{2,}/, ' ').gsub(/[ \t]+$/, '').gsub(/\n{3,}/, "\n\n").strip
  end
end
