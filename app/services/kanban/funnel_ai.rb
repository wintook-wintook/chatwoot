# frozen_string_literal: true

# ================================================================================
# Embudo de contactos E2 — la IA lee la conversación y avanza la tarjeta
# ================================================================================
# Corre cuando el cliente deja de escribir (Kanban::FunnelAiJob) en tableros con
# «La IA mueve tarjetas». Compara lo que dijo el cliente con el criterio en palabras
# de las columnas que están MÁS ADELANTE (nunca regresa, nunca convierte: crear la
# oportunidad lo confirma una persona o la columna «Convertir»).
#   - segura (≥ MOVE_CONFIDENCE): mueve y deja una nota privada con el porqué y el
#     siguiente paso sugerido;
#   - con duda (≥ SUGGEST_CONFIDENCE): no mueve, solo deja la nota con la sugerencia;
#   - si no: no hace nada.
# Usa la llave OpenAI de la cuenta (Cases::Ai::BaseService); sin llave no corre.
# ================================================================================

class Kanban::FunnelAi < Cases::Ai::BaseService
  MOVE_CONFIDENCE = 0.75
  SUGGEST_CONFIDENCE = 0.5
  HISTORY = 20
  MESSAGE_CHARS = 500

  SYSTEM = <<~PROMPT
    Eres el asistente de ventas de un negocio. Lees la conversación entre el negocio y un
    cliente y decides si la tarjeta del cliente en el embudo debe avanzar a una de las
    columnas candidatas. Cada columna tiene un criterio: elige una columna SOLO si lo que
    dijo el cliente cumple claramente su criterio. Si ninguna se cumple, column_id es null.
    Si varias se cumplen, elige la más avanzada. No inventes hechos que no estén en la conversación.
    Responde solo JSON: {"column_id": número o null, "confidence": número de 0 a 1,
    "reason": "una frase corta para el vendedor citando lo que dijo el cliente",
    "next_step": "acción corta sugerida para el vendedor"}.
  PROMPT

  def initialize(conversation)
    super(account: conversation.account)
    @conversation = conversation
    @board = conversation.kanban_type_process
    @mover = Kanban::FunnelMover.new(conversation)
  end

  def call
    return nil unless @board&.ai_move? && available?

    candidates = @mover.forward_columns(@board).select { |c| c.ai_criteria.present? && !c.stage_converted? }
    return nil if candidates.empty? || transcript.blank?

    decide(chat(system: SYSTEM, user: payload(candidates), json: true, max_tokens: 300), candidates)
  end

  private

  def decide(result, candidates)
    return nil unless result.is_a?(Hash)

    column = candidates.detect { |c| c.id == result['column_id'].to_i }
    confidence = result['confidence'].to_f
    return nil if column.nil? || confidence < SUGGEST_CONFIDENCE

    reason = result['reason'].to_s.strip.truncate(240)
    next_step = result['next_step'].to_s.strip.truncate(240)
    if confidence >= MOVE_CONFIDENCE
      @mover.move!(@board, column, source: 'ai', reason: reason, note: note('moved', column, reason, next_step))
      :moved
    else
      @mover.private_note!(note('suggested', column, reason, next_step))
      :suggested
    end
  end

  def note(kind, column, reason, next_step)
    text = @mover.translate("ai.#{kind}", column: column.type_process_name, reason: reason)
    next_step.present? ? "#{text}\n#{@mover.translate('ai.next_step', step: next_step)}" : text
  end

  def payload(candidates)
    current = @conversation.kanban_process
    {
      language: @account.locale.presence || 'es',
      current_column: current && { name: current.type_process_name, criterion: current.ai_criteria },
      candidates: candidates.map { |c| { column_id: c.id, name: c.type_process_name, criterion: c.ai_criteria } },
      conversation: transcript
    }.to_json
  end

  # Últimos mensajes públicos, del más viejo al más nuevo.
  def transcript
    @transcript ||= @conversation.messages.where(message_type: %i[incoming outgoing], private: false)
                                 .where.not(content: [nil, '']).reorder(created_at: :desc).limit(HISTORY)
                                 .pluck(:message_type, :content).reverse
                                 .map { |type, content| "#{type == 'incoming' ? 'Cliente' : 'Negocio'}: #{content.truncate(MESSAGE_CHARS)}" }
                                 .join("\n")
  end
end
