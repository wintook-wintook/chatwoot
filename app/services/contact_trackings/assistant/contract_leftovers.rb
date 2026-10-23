# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — RESTOS DEL CONTRATO DENTRO DEL ENTRENAMIENTO
# ================================================================================
# El contrato (Assistant::Contract) le muestra al modelo la FORMA del Entrenamiento
# con rótulos `═══ ZONA 1 · … ═══` y con el contenido de cada sección entre ‹ ›
# ("‹quién es el agente›"). Son marcas de las instrucciones, no del agente.
#
# ⚠ Visto el 17/09/2026 en el agente #7512 (citas médicas): se entregó con los dos
# rótulos de zona y las siete secciones de prosa envueltas en ‹ ›. Ninguna regla lo
# veía, y el agente leía "ZONA 1 · líneas de configuración" como parte de su prompt.
#
# Solo se busca lo que el contrato escribe: un rótulo con TEXTO entre ═══ (una línea
# de ═ o de = sola es decoración, y hay Entrenamientos reales que la usan) y ‹…›,
# que no se usan en español ni en inglés (las comillas son « » o " ").
# ================================================================================

module ContactTrackings::Assistant::ContractLeftovers
  LABEL_RE = /\A[ \t]*═{3,}[ \t]*[^═\s].*?[ \t]*═{3,}[ \t]*\z/
  WRAP_RE = /‹[^›\n]*›/

  Leftover = Struct.new(:kind, :line, :wrote, keyword_init: true)

  module_function

  # Una entrada por línea, en orden: la línea es lo que la persona busca en el texto.
  def scan(text)
    text.to_s.lines.each_with_index.filter_map do |raw, index|
      line = raw.chomp
      kind = if line.match?(LABEL_RE) then :label
             elsif line.match?(WRAP_RE) then :wrap
             end
      Leftover.new(kind: kind, line: index + 1, wrote: line.strip) if kind
    end
  end

  # B10 del comprobador. Bloqueante: el agente los lee como parte de sus
  # instrucciones. Un hallazgo por clase, con las líneas, porque se corrigen distinto:
  # el rótulo se borra entero, y de ‹ › se sacan solo los signos.
  def check(text, findings:)
    scan(text).group_by(&:kind).each do |kind, restos|
      mensaje = I18n.t("tracking_assistant.findings.contract_#{kind}",
                       locale: ContactTrackings::Assistant::Language.resolve,
                       count: restos.size, lines: restos.map(&:line).first(10).join(', '))
      findings.add(:blocking, :"contract_#{kind}", mensaje, line: restos.first.line, wrote: restos.first.wrote)
    end
  end
end
