# frozen_string_literal: true

# ================================================================================
# proyecto@predefinidas_que_contestan — NINGÚN DATO QUE EL MODELO NO HAYA VISTO
# ================================================================================
# Lo mismo que KnowledgeBase::LinkGuard hace con las ligas, para los datos que no pueden
# salir mal: montos, porcentajes y códigos (cupones, claves). Medido en pruebas: sin la
# respuesta de las promociones a la vista, el agente contestó «52% de descuento, $1,546 por
# materia, cupón CE5223»; ninguno de los tres existía en ningún lado.
#
# Se compara la respuesta contra TODO lo que el modelo tuvo enfrente en el turno (sus
# instrucciones, lo recuperado, el historial y lo que escribió el cliente). Un dato que no
# aparece ahí lo escribió él. También los calculados (3 × $1,990): el motor no calcula
# precios (ver ContactTrackingResponseAnalyzerJob, regla -TB).
#
# Solo detecta: quien llama decide (KnowledgeBaseResponseService#guard_data pide una vez
# la respuesta sin esos datos y, si siguen, quita las oraciones que los traen).
# ================================================================================
module KnowledgeBase::DataGuard
  MONEY_RE = /\$\s?\d[\d,.]*\d|\$\s?\d/
  PERCENT_RE = /\d+(?:[.,]\d+)?\s?%/
  # Letras y números juntos, 5 o más: cupones y claves (CE5223, l0601202611). Sin ligas.
  # Un punto al final es el de la oración («cupón CE5223.»), no parte de un dominio.
  CODE_RE = %r{(?<![\w/.@-])(?=[a-z0-9]*\d)(?=[a-z0-9]*[a-z])[a-z0-9]{5,}(?![\w/@-]|\.\w)}i
  URL_RE = %r{https?://\S+}i

  module_function

  # Los datos de la respuesta que no aparecen en lo que el modelo vio (como están escritos).
  def invented(reply, seen_text)
    return [] if reply.blank?

    allowed = facts(seen_text.to_s)
    found(reply).reject { |_raw, key| allowed.include?(key) }.map(&:first).uniq
  end

  # Quita las oraciones (o renglones) que traen alguno de esos datos.
  def strip(reply, values)
    return reply if values.empty?

    keep = reply.split("\n", -1).map do |line|
      next line if values.none? { |v| line.include?(v) }

      line.split(/(?<=[.!?])\s+/).reject { |s| values.any? { |v| s.include?(v) } }.join(' ')
    end
    keep.join("\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # [[como está escrito, clave para comparar], …]
  def found(text)
    sin_ligas = text.to_s.gsub(URL_RE, ' ')
    sin_ligas.scan(MONEY_RE).map { |m| [m, "$#{amount(m)}"] } +
      sin_ligas.scan(PERCENT_RE).map { |p| [p, "#{amount(p)}%"] } +
      sin_ligas.scan(CODE_RE).map { |c| [c, c.downcase] }
  end

  def facts(text)
    plano = text.to_s
    datos = found(plano).to_set(&:last)
    # Un monto sin «$» en la fuente («Precio: 1,990.00») también cuenta como visto.
    plano.gsub(URL_RE, ' ').scan(/\d[\d,.]*\d|\d/).each { |n| datos << "$#{amount(n)}" }
    # Los códigos dentro de ligas también los vio.
    plano.scan(CODE_RE).each { |c| datos << c.downcase }
    datos
  end

  # «$1,990.00», «1990», «$ 1.990» → «1990»; «38 %» → «38»; «52.5%» → «52.5».
  def amount(raw)
    digits = raw.to_s.gsub(/[^\d.,]/, '')
    entero, decimales = if digits.match?(/[.,]\d{1,2}\z/)
                          [digits[0...-(digits[/[.,](\d{1,2})\z/, 1].size + 1)], digits[/(\d{1,2})\z/, 1]]
                        else
                          [digits, nil]
                        end
    entero = entero.gsub(/[.,]/, '').sub(/\A0+(?=\d)/, '')
    decimales = decimales.to_s.sub(/0+\z/, '')
    decimales.empty? ? entero : "#{entero}.#{decimales}"
  end
end
