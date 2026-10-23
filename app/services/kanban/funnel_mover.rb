# frozen_string_literal: true

# ================================================================================
# Embudo de contactos — mueve la tarjeta con lo que pasa en la propia conversación
# ================================================================================
# Solo actúa en tableros con «Movimiento automático». Reglas:
#   - entrar: una conversación nueva por una bandeja del tablero entra a su columna
#     de entrada (si ya está en un tablero, p. ej. por una automatización, no se toca);
#   - avanzar: un hecho (primera respuesta, etiqueta, cita, caso creado, conversación
#     resuelta) la lleva a la PRIMERA columna más adelante que tenga ese disparador.
#     Nunca la regresa, así que mover a mano siempre gana;
#   - una tarjeta convertida ya no se mueve; una descartada solo sale si se crea su
#     caso o si el cliente vuelve a escribir (regresa a la columna de entrada);
#   - cada movimiento deja una nota de actividad en la conversación.
# La IA (Kanban::FunnelAi) y los vencimientos (Kanban::FunnelStaleJob) usan move!.
# ================================================================================

class Kanban::FunnelMover
  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def enter!
    return if @conversation.kanban_type_process_id.present?

    board = @account.kanban_type_processes.where(auto_move: true).order(:id)
                    .detect { |b| b.entry_inbox?(@conversation.inbox_id) }
    column = board&.entry_column
    return if column.nil?

    move!(board, column, source: 'rule', reason: reason(:conversation_created, inbox: @conversation.inbox&.name))
  end

  # type: uno de KanbanProcess::TRIGGER_TYPES; labels/case_class/folio según el hecho.
  def trigger!(type, labels: [], case_class: nil, folio: nil)
    board = @conversation.kanban_type_process
    return unless board&.auto_move?

    target = forward_columns(board, allow_from_discarded: type.to_s == 'case_created').detect do |column|
      column.triggered_by?(type, labels: labels, case_class: case_class)
    end
    return if target.nil?

    label = type.to_s == 'label_added' ? (Array(labels) & labels_of(target)).first || Array(labels).first : nil
    move!(board, target, source: 'rule', reason: reason(type, label: label, folio: folio))
  end

  # El cliente volvió a escribir sobre una tarjeta descartada: regresa a la entrada.
  def reopen!
    board = @conversation.kanban_type_process
    return unless board&.auto_move? && @conversation.kanban_process&.stage_discarded?

    column = board.entry_column
    move!(board, column, source: 'rule', reason: reason(:customer_returned)) if column
  end

  # NOTE: nil → nota de actividad estándar; un texto → esa nota privada; false → sin nota.
  def move!(board, column, source:, reason:, user_id: nil, note: nil)
    return false if @conversation.kanban_process_id == column.id

    @conversation.kanban_move_context = { source: source, reason: reason, user_id: user_id }
    @conversation.update!(kanban_type_process_id: board.id, kanban_process_id: column.id)
    note.is_a?(String) ? private_note!(note) : (note.nil? && activity_note!(column, reason))
    true
  end

  # Columnas más adelante que la actual, en orden; vacío si la tarjeta ya cerró su paso.
  # Desde «Descartado» (solo con un caso nuevo) cuenta cualquier columna: el descarte
  # suele ir al final y la de «Convertido» queda antes.
  def forward_columns(board, allow_from_discarded: false)
    current = @conversation.kanban_process
    return [] if current&.stage_converted?
    return [] if current&.stage_discarded? && !allow_from_discarded

    from_discarded = current&.stage_discarded?
    board.kanban_processes.by_position.order(:id).reject do |column|
      next false if current.nil?
      next true if column.id == current.id

      !from_discarded && column.position.to_i <= current.position.to_i
    end
  end

  def private_note!(content)
    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id, message_type: :outgoing,
      private: true, content: content
    )
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnel] nota privada de la conversación #{@conversation.id}: #{e.message}")
  end

  def translate(key, **params)
    I18n.with_locale(@account.locale.presence || I18n.default_locale) { I18n.t("kanban_funnel.#{key}", **params) }
  end

  private

  def labels_of(column)
    Array(column.entry_triggers).select { |t| t['type'] == 'label_added' }.flat_map { |t| Array(t['labels']) }
  end

  def reason(type, **params)
    translate("reasons.#{type}", **params.compact)
  end

  def activity_note!(column, reason)
    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id, message_type: :activity,
      content: translate('note', column: column.type_process_name, reason: reason)
    )
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnel] nota de la conversación #{@conversation.id}: #{e.message}")
  end
end
