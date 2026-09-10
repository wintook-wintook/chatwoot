# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe WordpressClient do
  let(:site) { 'https://misitio.com' }

  # hash_including({}) hace que el stub acepte cualquier query: sin eso webmock
  # exige que la URL no tenga parámetros y no matchea ninguna llamada real.
  def stub_wp(path, body, headers: {}, status: 200, query: {})
    stub_request(:get, "#{site}#{path}")
      .with(query: hash_including(query))
      .to_return(status: status, body: body.to_json,
                 headers: { 'Content-Type' => 'application/json' }.merge(headers))
  end

  def post_row(id, title, categories: [3])
    { 'id' => id, 'title' => { 'rendered' => title }, 'date' => '2026-09-01T10:00:00',
      'link' => "#{site}/#{id}", 'categories' => categories }
  end

  describe 'la URL del sitio' do
    it 'le pone https cuando la escribieron sin esquema' do
      expect(described_class.new('misitio.com').site_url).to eq('https://misitio.com')
    end

    it 'le saca la barra final' do
      expect(described_class.new('https://misitio.com/').site_url).to eq('https://misitio.com')
    end

    # URI.join DESCARTA la ruta de la base, así que un WordPress en subdirectorio
    # terminaría consultando la raíz del dominio — y si ahí hay otro WordPress,
    # responde 200 con el contenido equivocado. Pasó al probar contra un sitio real.
    it 'conserva el subdirectorio, que es donde vive el WordPress' do
      stub_request(:get, %r{https://misitio\.com/blog/wp-json/wp/v2/posts})
        .to_return(status: 200, body: [post_row(1, 'Hola')].to_json,
                   headers: { 'Content-Type' => 'application/json', 'X-WP-Total' => '1', 'X-WP-TotalPages' => '1' })

      resultado = described_class.new('https://misitio.com/blog').titles('posts')

      expect(resultado).to be_ok
      expect(a_request(:get, %r{https://misitio\.com/blog/wp-json/})).to have_been_made.at_least_once
    end
  end

  describe '#probe' do
    it 'devuelve cuánto contenido hay de cada tipo y las categorías' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-Total' => '1106' })
      stub_wp('/wp-json/wp/v2/pages', [], headers: { 'X-WP-Total' => '24' })
      stub_wp('/wp-json/wc/store/v1/products', [], headers: { 'X-WP-Total' => '87' })
      stub_wp('/wp-json/wp/v2/categories', [{ 'id' => 3, 'name' => 'Soporte', 'count' => 113 }])
      stub_wp('/wp-json/wc/store/v1/products/categories', [])

      datos = described_class.new(site).probe.data

      expect(datos[:counts]).to eq('posts' => 1106, 'pages' => 24, 'products' => 87)
      expect(datos[:categories]).to eq([{ id: 3, name: 'Soporte', count: 113 }])
    end

    # Las de la tienda son OTRA taxonomía: en un sitio real wp/v2 da
    # "Archive · Blog" y la tienda "Accounting · Additional purchases". Ofrecer las
    # del blog para filtrar productos no filtra nada.
    it 'trae las categorías de la tienda aparte de las del blog' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-Total' => '10' })
      stub_wp('/wp-json/wp/v2/pages', [], headers: { 'X-WP-Total' => '2' })
      stub_wp('/wp-json/wc/store/v1/products', [], headers: { 'X-WP-Total' => '5' })
      stub_wp('/wp-json/wp/v2/categories', [{ 'id' => 3, 'name' => 'Blog', 'count' => 10 }])
      stub_wp('/wp-json/wc/store/v1/products/categories',
              [{ 'id' => 1028, 'name' => 'Contabilidad', 'count' => 27 }])

      datos = described_class.new(site).probe.data

      expect(datos[:categories].pluck(:name)).to eq(['Blog'])
      expect(datos[:product_categories]).to eq([{ id: 1028, name: 'Contabilidad', count: 27 }])
    end

    # Un sitio sin tienda devuelve 404 en la Store API. Es lo normal, no un fallo.
    it 'marca como sin contenido el tipo que el sitio no tiene' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-Total' => '10' })
      stub_wp('/wp-json/wp/v2/pages', [], headers: { 'X-WP-Total' => '2' })
      stub_wp('/wp-json/wc/store/v1/products', { 'code' => 'rest_no_route' }, status: 404)
      stub_wp('/wp-json/wp/v2/categories', [])
      stub_wp('/wp-json/wc/store/v1/products/categories', {}, status: 404)

      resultado = described_class.new(site).probe

      expect(resultado).to be_ok
      expect(resultado.data[:counts]['products']).to be_nil
    end

    # Hay instalaciones que bloquean la API REST entera por plugin de seguridad.
    # Tiene que verse al conectar, no cuando un agente ya está en producción.
    it 'falla con un motivo claro cuando el sitio bloquea la API' do
      stub_wp('/wp-json/wp/v2/posts', {}, status: 403)

      resultado = described_class.new(site).probe

      expect(resultado).not_to be_ok
      expect(resultado.error).to eq(:forbidden)
    end

    it 'falla cuando el sitio no responde' do
      stub_request(:get, /#{site}/).to_timeout

      expect(described_class.new(site).probe.error).to eq(:unreachable)
    end

    # Un WAF o una portada de mantenimiento devuelven HTML donde debería ir JSON.
    it 'distingue "no es WordPress" de un error de red' do
      stub_request(:get, /#{site}/).to_return(status: 200, body: '<html>En mantenimiento</html>')

      expect(described_class.new(site).probe.error).to eq(:not_wordpress)
    end

    it 'rechaza una URL vacía sin salir a la red' do
      expect(described_class.new('').probe.error).to eq(:invalid_url)
    end
  end

  describe '#titles' do
    # Es lo que hace que conectar sea instantáneo: 213 KB en vez de 2,3 MB por cada
    # 100 entradas (medido 09/09/2026).
    it 'pide solo los campos del listado, no el contenido' do
      stub_wp('/wp-json/wp/v2/posts', [post_row(1, 'Hola')], headers: { 'X-WP-TotalPages' => '1' })

      described_class.new(site).titles('posts')

      expect(a_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('_fields' => 'id,title,date,link,categories'))).to have_been_made
    end

    it 'normaliza cada entrada a la misma forma' do
      stub_wp('/wp-json/wp/v2/posts', [post_row(412, 'Cómo actualizar')], headers: { 'X-WP-TotalPages' => '1' })

      expect(described_class.new(site).titles('posts').data).to eq(
        [{ id: 412, type: 'posts', title: 'Cómo actualizar', url: "#{site}/412",
           date: '2026-09-01T10:00:00', category_ids: [3] }]
      )
    end

    # La Store API habla otro dialecto: `name`, `permalink`, y categorías como
    # objetos. Se normaliza acá para que el job y la pantalla no tengan que saberlo.
    it 'normaliza un producto igual que una entrada, pese a venir distinto' do
      stub_wp('/wp-json/wc/store/v1/products',
              [{ 'id' => 9, 'name' => 'Licencia anual', 'permalink' => "#{site}/p/9",
                 'categories' => [{ 'id' => 21, 'name' => 'Licencias' }] }],
              headers: { 'X-WP-TotalPages' => '1' })

      expect(described_class.new(site).titles('products').data).to eq(
        [{ id: 9, type: 'products', title: 'Licencia anual', url: "#{site}/p/9",
           date: nil, category_ids: [21] }]
      )
    end

    it 'acota las ENTRADAS por categoría del lado de WordPress, no del nuestro' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-TotalPages' => '1' })

      described_class.new(site).titles('posts', categories: [3, 7])

      expect(a_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('categories' => '3,7'))).to have_been_made
    end

    # Una página NO tiene categorías: WordPress ignora el parámetro y devuelve
    # TODAS igual, sin error. Mandarlo hace creer que se acotó algo que no se acotó
    # — verificado contra un sitio real: 24 páginas con y sin ?categories=18.
    it 'no manda el filtro de categoría en las páginas, porque no existe' do
      stub_wp('/wp-json/wp/v2/pages', [], headers: { 'X-WP-TotalPages' => '1' })

      described_class.new(site).titles('pages', categories: [3])

      pedido = a_request(:get, %r{#{site}/wp-json/wp/v2/pages})
               .with { |req| req.uri.query.exclude?('categories') }
      expect(pedido).to have_been_made
    end

    # La Store API usa `category` en singular y admite UNA sola: ?category=1,2
    # devuelve lo mismo que ?category=1. Hay que preguntar de a una y unir.
    it 'pide los productos de a una categoría y une los resultados' do
      stub_request(:get, "#{site}/wp-json/wc/store/v1/products")
        .with(query: hash_including('category' => '10'))
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '1' },
                   body: [{ 'id' => 1, 'name' => 'Uno', 'permalink' => 'u', 'categories' => [] }].to_json)
      stub_request(:get, "#{site}/wp-json/wc/store/v1/products")
        .with(query: hash_including('category' => '20'))
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '1' },
                   body: [{ 'id' => 2, 'name' => 'Dos', 'permalink' => 'd', 'categories' => [] }].to_json)

      resultado = described_class.new(site).titles('products', categories: [10, 20])

      expect(resultado.data.pluck(:id)).to eq([1, 2])
      expect(a_request(:get, %r{#{site}/wp-json/wc/store/v1/products\?})).to have_been_made.twice
    end

    # Un producto puede estar en dos de las categorías elegidas, y no debe entrar
    # dos veces al índice.
    it 'no repite un producto que está en dos categorías elegidas' do
      stub_request(:get, "#{site}/wp-json/wc/store/v1/products")
        .with(query: hash_including('category'))
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '1' },
                   body: [{ 'id' => 7, 'name' => 'Repetido', 'permalink' => 'r', 'categories' => [] }].to_json)

      expect(described_class.new(site).titles('products', categories: [10, 20]).data.size).to eq(1)
    end

    it 'recorre todas las páginas' do
      stub_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('page' => '1'))
        .to_return(status: 200, body: [post_row(1, 'Uno')].to_json,
                   headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '2' })
      stub_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('page' => '2'))
        .to_return(status: 200, body: [post_row(2, 'Dos')].to_json,
                   headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '2' })

      expect(described_class.new(site).titles('posts').data.pluck(:id)).to eq([1, 2])
    end

    it 'avisa que no conoce un tipo que no existe' do
      expect(described_class.new(site).titles('videos').error).to eq(:unknown_type)
    end
  end

  describe '#items' do
    it 'baja el contenido solo de los ids elegidos' do
      stub_wp('/wp-json/wp/v2/posts',
              [post_row(412, 'Cómo actualizar').merge('content' => { 'rendered' => '<p>Texto</p>' },
                                                      'modified' => '2026-09-02T10:00:00')],
              headers: { 'X-WP-TotalPages' => '1' })

      resultado = described_class.new(site).items('posts', ids: [412, 588])

      expect(a_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('include' => '412,588'))).to have_been_made
      expect(resultado.data.first).to include(id: 412, html: '<p>Texto</p>', modified: '2026-09-02T10:00:00')
    end

    it 'no sale a la red si no hay nada elegido' do
      resultado = described_class.new(site).items('posts', ids: [])

      expect(resultado.data).to eq([])
      expect(a_request(:get, /#{site}/)).not_to have_been_made
    end

    it 'pide solo lo cambiado cuando se le da una fecha' do
      stub_wp('/wp-json/wp/v2/posts', [], headers: { 'X-WP-TotalPages' => '1' })

      described_class.new(site).items('posts', ids: [1], modified_after: Time.utc(2026, 9, 1))

      expect(a_request(:get, "#{site}/wp-json/wp/v2/posts")
        .with(query: hash_including('modified_after' => '2026-09-01T00:00:00Z'))).to have_been_made
    end

    it 'junta descripción y resumen en un producto, que no tiene content' do
      stub_wp('/wp-json/wc/store/v1/products',
              [{ 'id' => 9, 'name' => 'Licencia', 'permalink' => "#{site}/p/9", 'categories' => [],
                 'description' => '<p>Larga</p>', 'short_description' => '<p>Corta</p>' }],
              headers: { 'X-WP-TotalPages' => '1' })

      expect(described_class.new(site).items('products', ids: [9]).data.first[:html])
        .to eq("<p>Larga</p>\n\n<p>Corta</p>")
    end
  end
end
