# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — EL SQL DE `buscar_productos`, UNO POR ERP
# ================================================================================
# Plan: docs/erp_productos_plan.md (§2 y §3.3). Esquemas verificados en vivo (solo lectura)
# contra las conexiones de la cuenta 2 el 21/09/2026.
#
# Todos los filtros son opcionales con el patrón "(parámetro IS NULL OR condición)", así
# la misma consulta sirve con cualquier combinación. El texto llega partido en palabras
# (:texto_1…:texto_3, tipo `words` del QueryRunner, ya sin comodines) y TODAS tienen que
# aparecer. Devuelven siempre las mismas columnas: CODIGO, NOMBRE, LINEA, UNIDAD, PRECIO,
# EXISTENCIA. Los productos sin nombre (basura de captura) no salen.
#
# En Firebird CADA uso de un parámetro va con CAST (helper `fb`): Firebird deduce el tipo
# de un "?" por la columna con la que se compara, y si esa columna es NOT NULL el "?"
# tampoco admite NULL (medido: "specified column is not permitted to be null" con
# `DESCR CONTAINING ?`). La búsqueda de texto usa CONTAINING (sin comodines, sin
# distinguir mayúsculas). En SQL Server los
# parámetros son literales ya escapados por el adaptador; el `%%` es un `%` después del
# `format` que pone el sufijo de empresa de SAE.
# ================================================================================
module ExternalDb::ProductQueries
  module_function

  FB_TYPES = { text: 'VARCHAR(60)', number: 'DOUBLE PRECISION', integer: 'INTEGER' }.freeze

  # CAST(:nombre AS tipo): un parámetro de Firebird con tipo explícito y que admite NULL.
  def fb(name, type = :text)
    "CAST(:#{name} AS #{FB_TYPES.fetch(type)})"
  end

  def firebird_words(expr)
    (1..ExternalDb::QueryRunner::WORDS_MAX).map do |i|
      "AND (#{fb("texto_#{i}")} IS NULL OR #{format(expr, word: fb("texto_#{i}"))})"
    end.join("\n")
  end

  # ---------------- Aspel SAE: INVE, CLIN (líneas), PRECIO_X_PROD ----------------
  def sae
    <<~SQL.squish
      SELECT FIRST #{ExternalDb::QueryLibrary::PRODUCTS_LIMIT}
        TRIM(i.CVE_ART) AS CODIGO, TRIM(i.DESCR) AS NOMBRE, TRIM(l.DESC_LIN) AS LINEA,
        TRIM(i.UNI_MED) AS UNIDAD, p.PRECIO AS PRECIO, i.EXIST AS EXISTENCIA
      FROM INVE%<suffix>s i
      LEFT JOIN CLIN%<suffix>s l ON l.CVE_LIN = i.LIN_PROD
      LEFT JOIN PRECIO_X_PROD%<suffix>s p
        ON p.CVE_ART = i.CVE_ART AND p.CVE_PRECIO = COALESCE(#{fb('lista', :integer)}, 1)
      WHERE i.STATUS = 'A' AND TRIM(i.DESCR) <> ''
      #{firebird_words('(i.DESCR CONTAINING %<word>s OR i.CVE_ART CONTAINING %<word>s)').gsub('%', '%%')}
      AND (#{fb('codigo')} IS NULL OR i.CVE_ART = #{fb('codigo')})
      AND (#{fb('linea')} IS NULL OR i.LIN_PROD = #{fb('linea')} OR l.DESC_LIN CONTAINING #{fb('linea')})
      AND (#{fb('precio_min', :number)} IS NULL OR p.PRECIO >= #{fb('precio_min', :number)})
      AND (#{fb('precio_max', :number)} IS NULL OR p.PRECIO <= #{fb('precio_max', :number)})
      AND (COALESCE(#{fb('con_existencia', :integer)}, 0) = 0 OR i.EXIST > 0)
      ORDER BY i.DESCR
    SQL
  end

  # ---------------- Microsip: ARTICULOS, CLAVES, LINEAS, PRECIOS por POSICION, SALDOS_IN ----
  MICROSIP_STOCK = '(SELECT COALESCE(SUM(s.ENTRADAS_UNIDADES - s.SALIDAS_UNIDADES), 0) FROM SALDOS_IN s ' \
                   'WHERE s.ARTICULO_ID = a.ARTICULO_ID)'
  MICROSIP_KEY = 'EXISTS (SELECT 1 FROM CLAVES_ARTICULOS c WHERE c.ARTICULO_ID = a.ARTICULO_ID AND c.CLAVE_ARTICULO'

  def microsip
    <<~SQL.squish
      SELECT FIRST #{ExternalDb::QueryLibrary::PRODUCTS_LIMIT}
        (SELECT FIRST 1 TRIM(c.CLAVE_ARTICULO) FROM CLAVES_ARTICULOS c
          WHERE c.ARTICULO_ID = a.ARTICULO_ID ORDER BY c.ROL_CLAVE_ART_ID) AS CODIGO,
        TRIM(a.NOMBRE) AS NOMBRE, TRIM(l.NOMBRE) AS LINEA, TRIM(a.UNIDAD_VENTA) AS UNIDAD,
        pa.PRECIO AS PRECIO, #{MICROSIP_STOCK} AS EXISTENCIA
      FROM ARTICULOS a
      LEFT JOIN LINEAS_ARTICULOS l ON l.LINEA_ARTICULO_ID = a.LINEA_ARTICULO_ID
      LEFT JOIN PRECIOS_EMPRESA pe ON pe.POSICION = COALESCE(#{fb('lista', :integer)}, 1)
      LEFT JOIN PRECIOS_ARTICULOS pa ON pa.ARTICULO_ID = a.ARTICULO_ID AND pa.PRECIO_EMPRESA_ID = pe.PRECIO_EMPRESA_ID
      WHERE a.ESTATUS = 'A' AND TRIM(a.NOMBRE) <> ''
      #{firebird_words("(a.NOMBRE CONTAINING %<word>s OR #{MICROSIP_KEY} CONTAINING %<word>s))")}
      AND (#{fb('codigo')} IS NULL OR #{MICROSIP_KEY} = #{fb('codigo')}))
      AND (#{fb('linea')} IS NULL OR l.NOMBRE CONTAINING #{fb('linea')})
      AND (#{fb('precio_min', :number)} IS NULL OR pa.PRECIO >= #{fb('precio_min', :number)})
      AND (#{fb('precio_max', :number)} IS NULL OR pa.PRECIO <= #{fb('precio_max', :number)})
      AND (COALESCE(#{fb('con_existencia', :integer)}, 0) = 0 OR #{MICROSIP_STOCK} > 0)
      ORDER BY a.NOMBRE
    SQL
  end

  # ---------------- CONTPAQi Comercial: admProductos (CPRECIO1..10), clasificaciones,
  # existencia = entradas − salidas del ejercicio vigente (admExistenciaCosto por periodo).
  CONTPAQ_PRICE = "CASE COALESCE(:lista, 1) #{(1..10).map { |n| "WHEN #{n} THEN p.CPRECIO#{n}" }.join(' ')} END".freeze
  CONTPAQ_STOCK_SUM = [
    'e.CENTRADASINICIALES - e.CSALIDASINICIALES',
    (1..12).map { |n| "e.CENTRADASPERIODO#{n}" }.join(' + '),
    "- (#{(1..12).map { |n| "e.CSALIDASPERIODO#{n}" }.join(' + ')})"
  ].join(' + ').sub('+ -', '-').freeze
  CONTPAQ_WORD = "(p.CNOMBREPRODUCTO LIKE '%%%%' + %<word>s + '%%%%' OR p.CCODIGOPRODUCTO LIKE '%%%%' + %<word>s + '%%%%' " \
                 "OR p.CDESCRIPCIONPRODUCTO LIKE '%%%%' + %<word>s + '%%%%')"

  def contpaq
    words = (1..ExternalDb::QueryRunner::WORDS_MAX).map do |i|
      "AND (:texto_#{i} IS NULL OR #{format(CONTPAQ_WORD, word: ":texto_#{i}")})"
    end.join(' ')
    <<~SQL.squish
      SELECT TOP #{ExternalDb::QueryLibrary::PRODUCTS_LIMIT}
        RTRIM(p.CCODIGOPRODUCTO) AS CODIGO, RTRIM(p.CNOMBREPRODUCTO) AS NOMBRE,
        RTRIM(v.CVALORCLASIFICACION) AS LINEA, RTRIM(u.CNOMBREUNIDAD) AS UNIDAD,
        pr.PRECIO AS PRECIO, ex.EXISTENCIA AS EXISTENCIA
      FROM admProductos p
      LEFT JOIN admClasificacionesValores v ON v.CIDVALORCLASIFICACION = p.CIDVALORCLASIFICACION1
        AND p.CIDVALORCLASIFICACION1 > 0
      LEFT JOIN admUnidadesMedidaPeso u ON u.CIDUNIDAD = p.CIDUNIDADBASE
      CROSS APPLY (SELECT #{CONTPAQ_PRICE} AS PRECIO) pr
      OUTER APPLY (
        SELECT SUM(#{CONTPAQ_STOCK_SUM}) AS EXISTENCIA FROM admExistenciaCosto e
        WHERE e.CIDPRODUCTO = p.CIDPRODUCTO
          AND e.CIDEJERCICIO = (SELECT MAX(j.CIDEJERCICIO) FROM admEjercicios j WHERE j.CFECINIPERIODO1 <= GETDATE())
      ) ex
      WHERE p.CIDPRODUCTO > 0 AND p.CSTATUSPRODUCTO = 1 AND RTRIM(p.CNOMBREPRODUCTO) <> ''
      #{words}
      AND (:codigo IS NULL OR RTRIM(p.CCODIGOPRODUCTO) = :codigo)
      AND (:linea IS NULL OR EXISTS (
        SELECT 1 FROM admClasificacionesValores cv
        WHERE cv.CIDVALORCLASIFICACION > 0
          AND cv.CIDVALORCLASIFICACION IN (p.CIDVALORCLASIFICACION1, p.CIDVALORCLASIFICACION2, p.CIDVALORCLASIFICACION3,
                                           p.CIDVALORCLASIFICACION4, p.CIDVALORCLASIFICACION5, p.CIDVALORCLASIFICACION6)
          AND (RTRIM(cv.CCODIGOVALORCLASIFICACION) = :linea OR cv.CVALORCLASIFICACION LIKE '%%' + :linea + '%%')))
      AND (:precio_min IS NULL OR pr.PRECIO >= :precio_min)
      AND (:precio_max IS NULL OR pr.PRECIO <= :precio_max)
      AND (COALESCE(:con_existencia, 0) = 0 OR ex.EXISTENCIA > 0)
      ORDER BY p.CNOMBREPRODUCTO
    SQL
  end
end
