# frozen_string_literal: true

# ================================================================================
# @knowledge_sources — CLIENTE DE WORDPRESS
# ================================================================================
# Servicio: WordpressClient
# Descripción: Habla con la API REST pública de un sitio WordPress. Solo lectura.
#
# LOS TRES PASOS QUE SIRVE:
#   probe   — ¿responde el sitio? ¿qué tiene? ¿qué categorías? Se llama AL CONECTAR,
#             antes de indexar nada, y es lo que detecta un sitio bloqueado.
#   titles  — el listado para elegir: id, título, fecha y categoría. Nada más.
#   items   — el contenido completo, y solo de los ids elegidos.
#
#   Esa separación ES el modelo del módulo: conectar no es indexar. El listado de
#   1.106 entradas de un sitio real pesa 213 KB y tarda 3,2 s; ese mismo contenido
#   completo son 2,3 MB cada 100 entradas (medido 09/09/2026). Bajar todo para que
#   el usuario después descarte la mitad es trabajo tirado, y un índice inflado
#   contesta PEOR: con umbral 0.20 sobre un corpus amplio siempre hay "algo
#   parecido", así que el agente responde con lo que sea.
#
# TRES SUPERFICIES, UNA FORMA:
#   posts y pages vienen de wp/v2; products de la Store API de WooCommerce, que
#   devuelve otra cosa (`name` en vez de `title.rendered`, `permalink` en vez de
#   `link`, categorías como objetos). Se normaliza acá para que ni el job ni la
#   pantalla tengan que saberlo.
#
# POR QUÉ LA STORE API Y NO wc/v3:
#   Medido: wc/store/v1/products responde 200 sin credencial; wc/v3/products
#   responde 401. El requisito es que alcance con la URL del sitio, así que la
#   Store API es la única que sirve.
# ================================================================================

class WordpressClient
  # WordPress rechaza per_page > 100 con un 400.
  MAX_PER_PAGE = 100
  # Tope de páginas por barrido. Un sitio de 100.000 entradas no se lista entero en
  # una pantalla; que se corte con un aviso es mejor que colgar el navegador.
  MAX_PAGES = 200
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # Cada tipo con su ruta, sus campos de listado, su dialecto y CÓMO SE FILTRA.
  #
  # Los tres no se seleccionan igual, y tratarlos igual era un fallo silencioso
  # (verificado el 10/09/2026 contra sitios reales):
  #
  #   posts     ?categories=3,7   filtra bien, admite varias
  #   pages     ?categories=3     SE IGNORA — una página no tiene categorías, y
  #                               WordPress devuelve las 24 igual, sin error
  #   products  ?category=1021    otra taxonomía (las del blog no aplican) y UNA
  #                               sola por consulta: ?category=1021,1028 devuelve
  #                               lo mismo que ?category=1021
  #
  # Por eso `filter` dice el nombre del parámetro —o nil si el tipo no se puede
  # filtrar— y `multi` si admite varias de una.
  TYPES = {
    'posts' => { path: '/wp-json/wp/v2/posts', dialect: :wp,
                 fields: 'id,title,date,link,categories',
                 filter: :categories, multi: true },
    'pages' => { path: '/wp-json/wp/v2/pages', dialect: :wp,
                 fields: 'id,title,date,link',
                 filter: nil, multi: false },
    'products' => { path: '/wp-json/wc/store/v1/products', dialect: :store,
                    fields: 'id,name,permalink,categories',
                    filter: :category, multi: false }
  }.freeze

  CATEGORIES_PATH = '/wp-json/wp/v2/categories'
  # Las categorías de la tienda son OTRA taxonomía: en un sitio real, wp/v2 da
  # "Archive · Blog · Business Ideas" y la tienda "Accounting · Additional
  # purchases". Ofrecer las primeras para filtrar productos no filtra nada.
  PRODUCT_CATEGORIES_PATH = '/wp-json/wc/store/v1/products/categories'

  Result = Struct.new(:ok, :data, :error, :detail, keyword_init: true) do
    def ok? = ok
  end

  def initialize(site_url)
    @site_url = normalize(site_url)
  end

  attr_reader :site_url

  # ── AL CONECTAR ─────────────────────────────────────────────────────────────
  # Una llamada barata por tipo (per_page=1, solo para leer el total de la
  # cabecera) más las categorías. Con eso la pantalla puede ofrecer casillas
  # reales en vez de adivinanzas, y se sabe si el sitio está bloqueado ANTES de
  # que alguien configure un agente contra él.
  def probe
    return Result.new(ok: false, error: :invalid_url) if site_url.blank?

    counts = {}
    TYPES.each_key do |type|
      response = fetch(TYPES[type][:path], per_page: 1)
      # Un fallo de red o un bloqueo no son "este tipo no existe": cortan el probe.
      return blocked(response) if hard_failure?(response)

      counts[type] = response.ok? ? total_from(response.data[:headers]) : nil
    end

    Result.new(ok: true, data: { site_url: site_url, counts: counts,
                                 categories: categories,
                                 product_categories: product_categories })
  end

  # ── PARA ELEGIR ─────────────────────────────────────────────────────────────
  # Solo id, título, fecha y categoría. Es lo que hace que conectar sea instantáneo.
  #
  # El filtro se aplica según lo que el tipo admita (ver TYPES): las páginas no se
  # pueden filtrar por categoría y los productos van de a una. Mandar el parámetro
  # igual sería peor que no mandarlo: WordPress lo ignora en silencio y quien lo
  # eligió cree que acotó algo.
  def titles(type, categories: [])
    spec = TYPES[type]
    return Result.new(ok: false, error: :unknown_type) if spec.nil?

    base = { _fields: spec[:fields] }
    return collect_titles(spec, type, base) if spec[:filter].nil? || categories.blank?
    return collect_titles(spec, type, base.merge(spec[:filter] => categories.join(','))) if spec[:multi]

    # Una consulta por categoría, y se unen: la Store API no admite varias.
    merge_by_category(spec, type, base, categories)
  end

  # ── PARA INDEXAR ────────────────────────────────────────────────────────────
  # El contenido completo, y SOLO de los ids elegidos. `modified_after` permite que
  # un resync no vuelva a bajar todo.
  def items(type, ids:, modified_after: nil)
    spec = TYPES[type]
    return Result.new(ok: false, error: :unknown_type) if spec.nil?
    return Result.new(ok: true, data: []) if ids.blank?

    params = { include: ids.join(',') }
    # La Store API no expone modified_after; ahí el resync incremental no aplica.
    params[:modified_after] = modified_after.iso8601 if modified_after.present? && spec[:dialect] == :wp

    collect(spec, params) { |row| normalize_item(row, spec[:dialect], type) }
  end

  # Las categorías del blog: filtran ENTRADAS. Un sitio sin blog no tiene, y eso no
  # es un error: se devuelve vacío y la pantalla no ofrece ese filtro.
  def categories
    category_list(CATEGORIES_PATH)
  end

  # Las de la tienda: filtran PRODUCTOS. Son otra taxonomía, con otros ids.
  def product_categories
    category_list(PRODUCT_CATEGORIES_PATH)
  end

  private

  def category_list(path)
    response = fetch(path, per_page: MAX_PER_PAGE, _fields: 'id,name,count')
    return [] unless response.ok?

    response.data[:body].map { |row| { id: row['id'], name: row['name'], count: row['count'] } }
  end

  def collect_titles(spec, type, params)
    collect(spec, params) { |row| normalize_title(row, spec[:dialect], type) }
  end

  # Se pide categoría por categoría y se unen sin repetir: un producto puede estar
  # en dos de las elegidas y no debe entrar dos veces al índice.
  def merge_by_category(spec, type, base, categories)
    rows = []
    categories.each do |category|
      result = collect_titles(spec, type, base.merge(spec[:filter] => category))
      return result unless result.ok?

      rows.concat(result.data)
    end

    Result.new(ok: true, data: rows.uniq { |row| row[:id] })
  end

  # Se acepta "misitio.com" tanto como la URL completa: nadie escribe el esquema.
  def normalize(url)
    value = url.to_s.strip.chomp('/')
    return '' if value.blank?

    value = "https://#{value}" unless value.match?(%r{\Ahttps?://}i)
    URI.parse(value).to_s
  rescue URI::InvalidURIError
    ''
  end

  # ── paginado ────────────────────────────────────────────────────────────────
  # Se para por total de páginas y no por "hasta que venga vacío": pedir una página
  # fuera de rango devuelve 400, no una lista vacía (verificado 09/09/2026).
  def collect(spec, params, &)
    rows = []
    total_pages = nil

    (1..MAX_PAGES).each do |page|
      response = fetch(spec[:path], params.merge(per_page: MAX_PER_PAGE, page: page))
      return blocked(response) if hard_failure?(response)
      break unless response.ok?

      rows.concat(response.data[:body].map(&))
      total_pages = response.data[:headers]['x-wp-totalpages'].to_i
      break if page >= total_pages
    end

    Result.new(ok: true, data: rows, detail: (total_pages.to_i > MAX_PAGES ? :truncated : nil))
  end

  # ── normalización ───────────────────────────────────────────────────────────
  def normalize_title(row, dialect, type)
    if dialect == :store
      { id: row['id'], type: type, title: row['name'].to_s,
        url: row['permalink'], date: nil,
        category_ids: Array(row['categories']).filter_map { |c| c['id'] } }
    else
      { id: row['id'], type: type, title: row.dig('title', 'rendered').to_s,
        url: row['link'], date: row['date'],
        category_ids: Array(row['categories']) }
    end
  end

  def normalize_item(row, dialect, type)
    base = normalize_title(row, dialect, type)
    body = if dialect == :store
             [row['description'], row['short_description']].compact_blank.join("\n\n")
           else
             row.dig('content', 'rendered').to_s
           end

    base.merge(html: body, modified: row['modified'])
  end

  # ── HTTP ────────────────────────────────────────────────────────────────────
  # Se concatena en vez de usar URI.join: join DESCARTA la ruta de la base, así que
  # un WordPress instalado en subdirectorio (misitio.com/blog, muy común) terminaría
  # consultando la raíz del dominio. Y eso no falla: si en la raíz hay otro
  # WordPress, responde 200 con el contenido equivocado.
  def fetch(path, params)
    uri = URI.parse("#{site_url}#{path}")
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end

    build_result(response)
  rescue StandardError => e
    Rails.logger.warn "[WordpressClient] #{site_url}#{path}: #{e.class} #{e.message}"
    Result.new(ok: false, error: :unreachable, detail: e.message)
  end

  def build_result(response)
    return Result.new(ok: false, error: error_for(response), detail: response.code) unless response.is_a?(Net::HTTPSuccess)

    Result.new(ok: true, data: { body: JSON.parse(response.body), headers: response.to_hash.transform_values(&:first) })
  rescue JSON::ParserError
    # Un sitio que sirve HTML donde debería ir JSON casi siempre es una portada de
    # "sitio en mantenimiento" o un WAF devolviendo su propia página.
    Result.new(ok: false, error: :not_wordpress)
  end

  def error_for(response)
    case response.code.to_i
    when 401, 403 then :forbidden
    when 404 then :not_found
    else :http_error
    end
  end

  # Un 404 significa "este sitio no tiene ese tipo de contenido" —lo normal en un
  # sitio sin WooCommerce— y no debe tumbar el probe. Un 403 o una caída de red sí:
  # ahí no se sabe nada del sitio y seguir preguntando es mentirle al usuario.
  def hard_failure?(result)
    !result.ok? && %i[forbidden unreachable not_wordpress http_error].include?(result.error)
  end

  def blocked(result)
    Result.new(ok: false, error: result.error, detail: result.detail)
  end

  def total_from(headers)
    headers['x-wp-total'].to_i
  end
end
