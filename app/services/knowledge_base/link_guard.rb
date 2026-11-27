# frozen_string_literal: true

# ================================================================================
# Ninguna liga que el modelo no haya visto llega al cliente
# ================================================================================
# 11/11/2026 (cuenta 1128, Agente Escuela v2, corrida 2): dos ligas de inscripción
# inventadas. A «¿no tienes otro descuento de Administración?» mandó
# neoclase.com/cursos/lic-administracion/ (la real es ad101-fundamentos-de-administracion)
# y a «¿Cuentan con becas?» de Psicología, ps101-introduccion-a-la-psicologia (la real es
# p101-bases-biologicas-de-la-conducta). El cliente llega a una página que no existe.
#
# La regla en el prompt («copia la liga tal cual») lo reduce pero no lo garantiza. Aquí se
# revisa la respuesta contra TODO lo que el modelo tuvo enfrente en ese turno (prompt del
# agente, fuentes recuperadas, historial): una liga que no aparece ahí la escribió él, y
# se quita. Si el renglón queda vacío o colgando («Inscríbete aquí:»), se quita el renglón.
# ================================================================================

module KnowledgeBase::LinkGuard
  URL_RE = %r{https?://[^\s<>"'()\[\]]+}i
  MARKDOWN_RE = %r{\[([^\]]+)\]\((https?://[^)\s]+)\)}i
  TRAILING = /[.,;:!?»”'"]+\z/

  module_function

  # [texto sin las ligas inventadas, ligas quitadas]
  def call(reply, seen_text)
    return [reply, []] if reply.blank?

    allowed = urls_in(seen_text).to_set { |url| normalize(url) }
    removed = []
    lines = reply.split("\n", -1).filter_map do |line|
      kept = guard_line(line, allowed, removed)
      next line if kept.equal?(line)

      kept unless dangling?(kept)
    end
    return [reply, []] if removed.empty?

    [lines.join("\n").gsub(/\n{3,}/, "\n\n").strip, removed.uniq]
  end

  # La misma línea (mismo objeto) si no se tocó.
  def guard_line(line, allowed, removed)
    return line unless line.match?(URL_RE)

    before = removed.size
    text = line.gsub(MARKDOWN_RE) do
      label = Regexp.last_match(1)
      url = Regexp.last_match(2)
      allowed.include?(normalize(url)) ? Regexp.last_match(0) : (removed << url) && label
    end
    text = text.gsub(URL_RE) do |raw|
      url = raw.sub(TRAILING, '')
      next raw if allowed.include?(normalize(url))

      removed << url
      raw[url.size..]
    end
    removed.size == before ? line : text.gsub(/[ \t]{2,}/, ' ').rstrip
  end

  def dangling?(line)
    line.strip.empty? || line.strip.end_with?(':')
  end

  def urls_in(text)
    text.to_s.scan(URL_RE).map { |raw| raw.sub(TRAILING, '') }
  end

  def normalize(url)
    url.to_s.downcase.sub(%r{\Ahttps?://(www\.)?}, '').sub(%r{/+\z}, '')
  end
end
