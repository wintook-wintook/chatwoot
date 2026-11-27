# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — «SEPARAR TEMAS» (dos que se solapan)
# ================================================================================
# El otro arreglo válido de un solapamiento: no se borra ninguna, cada una se queda con
# su tema y deja de repetir lo de la otra (puede remitir a ella). Los nombres no cambian.
# Candados: lo que se quite de una tiene que seguir en la otra (datos y frases de las dos
# juntas; perder frases BLOQUEA, ver Context#checks), y la similitud entre las dos tiene
# que bajar (`pair`).
#
# La IA puede decir que no conviene separarlas (not_advised): en el banco F2, dos
# procedimientos paralelos («Actualización Microsip» monousuario y multiusuario, cuenta
# 257) quedaron sin 55 de sus 64 pasos al quitar de cada una lo que repetía la otra. Ahí
# cada una tiene que poder seguirse sola; la pantalla sugiere unirlas o descartar.
# ================================================================================

class CannedResponses::Fix::SeparateBuilder < CannedResponses::Fix::AiBuilder
  SYSTEM = <<~PROMPT
    Dos respuestas predefinidas se solapan: repiten parte de la misma información y la búsqueda del
    agente de IA trae las dos, ocupando lugar. Reescríbelas para que cada una se quede con SU tema
    (lo que dice su nombre) y deje de repetir lo de la otra.
    - Si quitas algo de una, tiene que quedar en la otra: no se pierde nada entre las dos.
    - El objetivo es que se parezcan MENOS: quita lo repetido; no agregues a las dos el mismo texto.
    - Puedes terminar una con una línea corta que remita a la otra: «Para <tema>, ver «<nombre de la otra>».»
    - Los nombres no cambian. Copia literalmente los datos de la lista de datos obligatorios.
    - Conserva el formato útil y el idioma. No inventes.
    - Si cada una tiene que poder leerse o seguirse SOLA (por ejemplo, dos procedimientos completos para
      variantes distintas, o el mismo texto adaptado a públicos distintos), NO conviene separarlas:
      contesta {"not_advised": true, "reason": "por qué, en una línea"}.
    Preguntas de prueba: 2 por respuesta, que solo esa contesta; "part" 0 = A, 1 = B.
    Contesta SOLO este JSON:
    {"reason":"una línea","a":"contenido nuevo de A","b":"contenido nuevo de B","questions":[{"text":"…","part":0}]}
  PROMPT

  private

  def system = SYSTEM

  def user
    a, b = @context.sources
    "#{response_block(a, 'A')}\n\n#{response_block(b, 'B')}\n\n## Datos obligatorios\n#{hard_data_list}"
  end

  def parse(out)
    return not_advised(out) if out.is_a?(Hash) && out['not_advised']
    return nil unless out.is_a?(Hash) && text(out['a']).present? && text(out['b']).present?

    a, b = @context.sources
    preguntas = Array(out['questions']).filter_map do |q|
      next unless q.is_a?(Hash) && text(q['text']).present? && [0, 1].include?(q['part'].to_i)

      { 'text' => text(q['text']), 'part' => q['part'].to_i }
    end
    { 'action' => 'separate', 'reason' => text(out['reason']),
      'parts' => [{ 'short_code' => a.short_code, 'content' => text(out['a']) },
                  { 'short_code' => b.short_code, 'content' => text(out['b']) }],
      'questions' => preguntas.first(6) }
  end

  # Las dos quedan igual: la propuesta solo explica por qué no separarlas.
  def not_advised(out)
    @not_advised = true
    { 'action' => 'separate', 'not_advised' => true, 'reason' => text(out['reason']), 'questions' => [],
      'parts' => @context.sources.map { |r| { 'short_code' => r.short_code, 'content' => r.content } } }
  end

  # Si la IA desaconseja separarlas no hay segunda vuelta: no hay nada que corregir.
  def problems(revisada)
    return [] if @not_advised

    out = super
    par = revisada['pair']
    if par && !par['ok']
      out << "Se siguen pareciendo igual o más (similitud #{par['before']} → #{par['after']}): quita de cada una lo que repite " \
             'la otra y no agregues texto común.'
    end
    out
  end
end
