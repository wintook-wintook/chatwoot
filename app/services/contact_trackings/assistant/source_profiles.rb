# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — FR: LA FICHA DE CADA FUENTE
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §12. El inventario dice QUÉ
# fuentes tiene la cuenta; la ficha dice QUÉ HAY DENTRO de cada una, para que el chat
# (y quien arma el agente) sepa qué se le puede preguntar y cómo se usa en una ruta:
#
#   Hoja «Precios»  Servicio · Zona · Precio (48 filas), ej. «Plataforma | Norte | $1,800»
#                   {{hoja_buscar: Precios | Servicio=? | Precio}}
#
# SIN IA: todo sale de la base (columnas y filas de las hojas, títulos de los
# documentos y artículos, grupos de predefinidas, campos de los tipos de caso). D9: se
# arma cada vez, así nunca dice algo que ya cambió.
#
# Medido el 03/11/2026 (F0): 3 de 4 cuentas de staging arman agentes SIN ninguna
# fuente. Por eso la respuesta también dice qué falta y dónde se configura.
# ================================================================================

class ContactTrackings::Assistant::SourceProfiles
  SAMPLE_ROWS = 3
  SAMPLE_SCAN = 50
  MAX_SUMMARY = 20
  NUMERIC_RE = /\A[$€]?\s*-?[\d.,]+\s*(?:%|usd|mxn)?\z/i
  MAX_TITLES = 12
  MAX_VALUE = 60
  Inventory = ContactTrackings::Assistant::InventoryService

  def initialize(account, inbox: nil)
    @account = account
    @inbox = inbox
  end

  # [{ tipo:, nombre:, directiva:, que_tiene:, ejemplo:, se_le_puede_preguntar:, como_se_usa:, ruta_sugerida: }]
  def call
    [*sheets, *docs, *articles, *canned, *external, *case_types].compact
  end

  # La ficha de una fuente por su nombre (o de un tipo: «predefinidas», «articulos»).
  def find(nombre)
    clave = normalize(nombre)
    call.find { |f| normalize(f[:nombre]) == clave || normalize(f[:tipo]) == clave } ||
      call.find { |f| normalize(f[:nombre]).include?(clave) }
  end

  # Para el chat de creación: una línea por fuente con lo que tiene dentro.
  def summary_lines
    fichas = call
    return [] if fichas.empty?

    ['Qué tiene cada fuente:', *fichas.first(MAX_SUMMARY).map { |f| "- #{f[:tipo]} «#{f[:nombre]}»: #{f[:que_tiene].to_s.truncate(160)}" }]
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pudieron armar las fichas: #{e.message}"
    []
  end

  # Lo que la cuenta no tiene, dicho para quien arma el agente.
  def missing
    tipos = active.pluck(:source_type).uniq
    faltan = %w[google_sheet google_doc article canned_response].reject { |t| tipos.include?(t) }
    faltan << 'case_type' if CaseType.where(account_id: @account.id).none?
    faltan
  end

  private

  def active
    @active ||= @account.knowledge_sources.active.order(:name).to_a
  end

  def of_type(tipo) = active.select { |s| s.source_type == tipo }

  # ── hojas ────────────────────────────────────────────────────────────────────
  def sheets
    of_type('google_sheet').map { |hoja| sheet_profile(hoja) }
  end

  def sheet_profile(hoja)
    datos = hoja.google_sheet_rows.order(:row_index).limit(SAMPLE_SCAN).map(&:data)
    columnas = datos.first&.keys || []
    uso = sheet_use(hoja.name, columnas, datos)
    { tipo: 'hoja', nombre: hoja.name, directiva: "{{hoja:#{hoja.name}}}",
      que_tiene: "#{columnas.join(' · ')} (#{hoja.google_sheet_rows.count} filas)",
      ejemplo: datos.first(SAMPLE_ROWS).map { |d| d.values.map { |v| v.to_s.truncate(MAX_VALUE) }.join(' | ') },
      se_le_puede_preguntar: uso[:pregunta], como_se_usa: uso[:directiva],
      ruta_sugerida: "@ruta(consultar_#{slug(hoja.name)}: <frases del cliente>): #{uso[:directiva]}" }
  end

  def sheet_use(nombre, columnas, datos)
    return { directiva: "{{hoja:#{nombre}}}", pregunta: 'la hoja no tiene filas todavía' } if columnas.size < 2

    clave, regresa = lookup_columns(columnas, datos)
    { directiva: "{{hoja_buscar: #{nombre} | #{clave}=? | #{regresa.join(', ')}}}",
      pregunta: "busca por #{clave} y contesta #{regresa.join(', ')} (u otra columna)" }
  end

  # Por cuál columna se busca y cuáles se regresan, sin IA: se busca por la de TEXTO con
  # más valores distintos (Producto, cliente, placas) y se regresan las numéricas (Precio,
  # monto); si no hay numéricas, las dos siguientes. Es una sugerencia: el chat ve la
  # hoja entera con ver_fuente y elige.
  def lookup_columns(columnas, datos)
    valores = columnas.index_with { |c| datos.map { |d| d[c].to_s.strip }.compact_blank }
    numericas = columnas.select { |c| numeric?(valores[c]) }
    clave = (columnas - numericas).max_by { |c| valores[c].uniq.size } || columnas.first
    regresa = numericas - [clave]
    [clave, (regresa.presence || (columnas - [clave])).first(2)]
  end

  def numeric?(valores) = valores.any? && valores.all? { |v| v.match?(NUMERIC_RE) }

  # ── documentos ───────────────────────────────────────────────────────────────
  def docs
    of_type('google_doc').map do |doc|
      titulos = doc.knowledge_items.order(:id).limit(MAX_TITLES).pluck(:title).compact_blank.uniq
      { tipo: 'documento', nombre: doc.name, directiva: "{{doc:#{doc.name}}}",
        que_tiene: titulos.any? ? "#{doc.knowledge_items.count} partes: #{titulos.join(' · ')}" : 'sin contenido sincronizado',
        se_le_puede_preguntar: 'lo que explica el documento (busca por significado, no por palabras exactas)',
        como_se_usa: "{{doc:#{doc.name}}}", ruta_sugerida: "@ruta(info_#{slug(doc.name)}: <frases>): {{doc:#{doc.name}}}" }
    end
  end

  # ── artículos del Centro de Ayuda ────────────────────────────────────────────
  def articles
    return [] if of_type('article').empty?

    publicados = Article.where(account_id: @account.id).published
    categorias = Category.where(id: publicados.select(:category_id)).pluck(:name).compact_blank.uniq
    titulos = publicados.order(updated_at: :desc).limit(MAX_TITLES).pluck(:title).compact_blank
    [{ tipo: 'articulos', nombre: 'Centro de Ayuda', directiva: '@buscar_articulo',
       que_tiene: "#{publicados.count} artículos publicados#{" en #{categorias.join(' · ')}" if categorias.any?}",
       ejemplo: titulos, se_le_puede_preguntar: 'lo que respondan sus artículos',
       como_se_usa: '@buscar_articulo', ruta_sugerida: '@ruta(ayuda: <frases>): @buscar_articulo' }]
  end

  # ── respuestas predefinidas ──────────────────────────────────────────────────
  def canned
    return [] if of_type('canned_response').empty?

    grupos = Inventory.new(@account, inbox: @inbox).call[:canned_groups]
    [{ tipo: 'predefinidas', nombre: 'Respuestas predefinidas', directiva: '@buscar_predefinidas',
       que_tiene: "#{@account.canned_responses.count} respuestas" \
                  "#{"; grupos: #{grupos.map { |g| "#{g[:prefix]} (#{g[:count]})" }.join(' · ')}" if grupos.any?}",
       ejemplo: canned_examples(grupos), se_le_puede_preguntar: 'lo que contesten sus respuestas, por grupo',
       como_se_usa: grupos.any? ? "@buscar_predefinidas(#{grupos.first[:prefix]})" : '@buscar_predefinidas',
       ruta_sugerida: "@ruta(dudas: <frases>): #{grupos.any? ? "@buscar_predefinidas(#{grupos.first[:prefix]})" : '@buscar_predefinidas'}" }]
  end

  def canned_examples(grupos)
    grupos.first(4).to_h do |g|
      codigos = @account.canned_responses.where('short_code ILIKE ?', "#{g[:prefix]}%").limit(4).pluck(:short_code)
      [g[:prefix], codigos]
    end
  end

  # ── las que se consultan en vivo (foro, CONTPAQi) ────────────────────────────
  def external
    (of_type('discourse') + of_type('contpaq_support')).map do |fuente|
      foro = fuente.source_type == 'discourse'
      directiva = foro ? "@buscar_foro(#{fuente.name})" : "@soporte_contpaq(#{fuente.name})"
      { tipo: foro ? 'foro' : 'contpaq', nombre: fuente.name, directiva: directiva,
        que_tiene: 'se consulta en vivo (no se guarda aquí): no se puede listar su contenido',
        se_le_puede_preguntar: foro ? 'lo que se haya respondido en el foro' : 'dudas de soporte de CONTPAQi',
        como_se_usa: directiva, ruta_sugerida: "@ruta(soporte: <frases>): #{directiva}" }
    end
  end

  # ── tipos de caso (lo que pide @crear_ticket) ────────────────────────────────
  def case_types
    CaseType.where(account_id: @account.id).ordered.includes(:case_type_fields).map do |tipo|
      campos = tipo.case_type_fields.sort_by { |c| c.try(:position).to_i }
                   .map { |c| c.required ? "#{c.label} (obligatorio)" : c.label }
      { tipo: 'tipo_de_caso', nombre: tipo.name, directiva: "@crear_ticket(tipo=#{tipo.name})",
        que_tiene: campos.any? ? "pide: #{campos.join(' · ')}" : 'sin campos propios',
        se_le_puede_preguntar: 'no es una fuente: abre un caso para que lo atienda una persona',
        como_se_usa: "@crear_ticket(tipo=#{tipo.name})",
        ruta_sugerida: "@ruta(#{slug(tipo.name)}: <frases>): - -> @crear_ticket(tipo=#{tipo.name})" }
    end
  end

  def slug(texto)
    I18n.transliterate(texto.to_s).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').first(30)
  end

  def normalize(texto) = I18n.transliterate(texto.to_s).downcase.strip
end
