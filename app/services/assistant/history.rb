# frozen_string_literal: true

# Asistente (Dali) — lo dicho antes en la plática, como texto para el modelo.
#
# - Lo que se propuso y en qué quedó va entre corchetes («[Propuse task: … — confirmed]»).
# - Las guías que se usaron en una respuesta también («[Guías: dali_telefono]»): así un «sí» o
#   «ábrela» en el siguiente turno sabe cuál leer (antes pedía read_guide con el título y fallaba).
# - Una pregunta que se quedó sin respuesta (falló o se cerró la ventana) se salta: si no, el
#   modelo la contesta días después junto con la nueva.
#
# Uso: Assistant::History.messages(thread, 12)
module Assistant::History
  module_function

  def messages(thread, limit)
    list = thread.messages.last(limit)
    list.each_with_index.filter_map do |message, index|
      next if unanswered?(message, list[index + 1])

      { role: message['role'], content: [message['content'], *notes(message)].compact_blank.join("\n") }
    end
  end

  def unanswered?(message, following)
    message['role'] == 'user' && (following.nil? || following['role'] == 'user')
  end

  def notes(message)
    proposals = Array(message['proposals']).map do |p|
      "[Propuse #{p['type']}: #{p['labels'].to_h.values.compact.join(', ')} — #{p['status']}]"
    end
    guides = Array(message['guides'])
    guides.any? ? [*proposals, "[Guías: #{guides.join(', ')}]"] : proposals
  end

  # Si el modelo copia al final los «Datos de esta plática» del prompt, o las notas de arriba
  # («[Guías: …]», «[Propuse …]»), se quitan (pasa con modelos chicos): el usuario no debe verlas.
  ECHO = /\n+[*_ ]*Datos de (?:la|esta) (?:conversaci[oó]n|pl[aá]tica)[*_ ]*:?.*\z/mi
  NOTE = /^[ \t]*\[(?:Guías|Propuse)\b[^\]\n]*\][ \t]*$\n?/
  # La firma corta de la última línea: «John, 2026-11-14, viendo: my_summary.» o
  # «John, sábado 14 de noviembre de 2026, 20:30. Estás viendo: mi resumen.»
  SIGNATURE = /\n+[^\n]{0,80}\b(?:viendo|pantalla)\s*:\s*[\p{L}_ ]{1,40}\.?[ \t]*\z/i

  def clean(text)
    text.to_s.sub(ECHO, '').gsub(NOTE, '').strip.sub(SIGNATURE, '').strip
  end
end
