# frozen_string_literal: true

# proyecto@asistente_agentes_ia — lo que viaja pegado a cada mensaje guardado de la
# sesión y que el cliente no devuelve: los cambios de un turno y su consumo (TokenUsage).
#
# La pantalla manda el hilo solo con role y content. Se recupera de lo guardado, turno
# por turno, mientras el contenido coincida: sin esto, cada turno nuevo borraría los
# datos del anterior. Lo usan la entrevista (InterviewTurn) y el chat consultor
# (AssistantDraftingController).
module ContactTrackings::Assistant::StoredTurnData
  KEYS = %w[changes consumo].freeze

  def self.merge(guardados, turnos)
    guardados = Array(guardados)
    turnos.each_with_index.map do |turno, i|
      previo = guardados[i]
      next turno unless previo.is_a?(Hash) && previo['content'] == turno['content']

      turno.merge(previo.slice(*KEYS).compact_blank)
    end
  end
end
