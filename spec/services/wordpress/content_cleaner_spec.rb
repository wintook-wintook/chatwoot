# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe Wordpress::ContentCleaner do
  def limpiar(html) = described_class.call(html)

  describe 'separación entre bloques' do
    # Sin el salto, Nokogiri devuelve los bloques pegados y la última palabra de un
    # párrafo se funde con la primera del siguiente: "sistemaPara". Eso queda dentro
    # del embedding como un término que nadie escribió nunca.
    it 'no pega el final de un párrafo con el principio del siguiente' do
      expect(limpiar('<p>del sistema</p><p>Para actualizar</p>')).to eq("del sistema\nPara actualizar")
    end

    it 'separa el título del texto que lo sigue' do
      expect(limpiar('<h2>Instalación</h2><p>Primero descargá</p>')).to eq("Instalación\nPrimero descargá")
    end

    it 'deja cada punto de una lista en su renglón' do
      expect(limpiar('<ul><li>uno</li><li>dos</li></ul>')).to eq("uno\ndos")
    end
  end

  describe 'entidades' do
    # Una regex que borre entidades rompe las palabras: "don&#8217;t" queda "don t"
    # y "caf&#233;" queda "caf". Son justo los términos que después hay que encontrar.
    it 'las decodifica en vez de borrarlas' do
      expect(limpiar('<p>don&#8217;t &amp; caf&#233; fin</p>')).to eq('don’t & café fin')
    end

    it 'convierte el espacio duro en un espacio normal' do
      expect(limpiar('<p>uno&nbsp;dos</p>')).to eq('uno dos')
    end
  end

  describe 'lo que se conserva' do
    # Los títulos internos son señal fuerte de tema: es lo que hace que un chunk
    # sobre instalación se parezca a la pregunta "cómo instalo".
    it 'conserva los títulos internos' do
      expect(limpiar('<h3>Requisitos previos</h3>')).to eq('Requisitos previos')
    end

    # De un enlace importa lo que dice, no adónde va: una URL en un embedding es ruido.
    it 'conserva el texto de un enlace y descarta la URL' do
      expect(limpiar('<p>mirá <a href="https://x.com/muy/larga">la guía</a> ahí</p>')).to eq('mirá la guía ahí')
    end
  end

  describe 'lo que se descarta' do
    it 'saca las imágenes sin pegar lo que las rodea' do
      html = '<p>antes</p><figure><img src="x.png" alt="captura"></figure><p>después</p>'

      expect(limpiar(html)).to eq("antes\ndespués")
    end

    it 'saca scripts y estilos' do
      expect(limpiar('<p>real</p><script>alert(1)</script>')).to eq('real')
      expect(limpiar('<p>real</p><style>.a{color:red}</style>')).to eq('real')
    end

    it 'saca iframes y videos incrustados' do
      expect(limpiar('<p>real</p><iframe src="https://youtube.com/x"></iframe>')).to eq('real')
    end

    # content.rendered viene post-renderizado, así que estos dos casi nunca llegan.
    # Pero un shortcode de un plugin desactivado SÍ aparece crudo en el texto.
    it 'saca un shortcode que quedó sin renderizar' do
      expect(limpiar('<p>precio [woo_price id=3] pesos</p>')).to eq('precio pesos')
    end

    it 'saca los comentarios de bloque de Gutenberg' do
      expect(limpiar('<!-- wp:paragraph --><p>hola</p><!-- /wp:paragraph -->')).to eq('hola')
    end
  end

  describe 'bordes' do
    it 'devuelve vacío con nil' do
      expect(limpiar(nil)).to eq('')
    end

    it 'devuelve vacío cuando todo el contenido era markup' do
      expect(limpiar('<figure><img src="x.png"></figure>')).to eq('')
    end

    it 'colapsa los saltos de más pero conserva la separación entre ideas' do
      expect(limpiar('<p>uno</p><br><br><br><p>dos</p>')).to eq("uno\ndos")
    end
  end

  # El número que justifica todo el servicio, medido sobre contenido real.
  describe 'cuánto quita' do
    it 'de un bloque típico de WordPress saca la mayor parte' do
      html = <<~HTML
        <p class="wp-block-paragraph">Para actualizar a la última versión, entrá al panel.</p>
        <figure class="wp-block-image size-large"><img loading="lazy" decoding="async"
          width="1024" height="576" src="https://misitio.com/wp-content/uploads/2026/09/captura.png"
          alt="" class="wp-image-1234"/></figure>
        <p class="wp-block-paragraph">Después reiniciá el servicio.</p>
      HTML

      limpio = limpiar(html)

      expect(limpio).to eq("Para actualizar a la última versión, entrá al panel.\nDespués reiniciá el servicio.")
      expect(limpio.length).to be < (html.length / 3)
    end
  end
end
