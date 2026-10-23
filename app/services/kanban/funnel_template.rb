# frozen_string_literal: true

# Embudo de contactos — un tablero nuevo nace listo para usarse: sus columnas, qué
# mete a una conversación en cada una, el criterio para la IA y el movimiento
# automático encendido. Las bandejas que entran solas las elige la empresa.
# Los tableros que ya existían no pasan por aquí (se quedan como estaban).
class Kanban::FunnelTemplate
  COLUMNS = [
    { key: 'new', default: true, triggers: [{ 'type' => 'conversation_created' }] },
    { key: 'contacted', triggers: [{ 'type' => 'first_reply' }] },
    { key: 'interested', triggers: [{ 'type' => 'label_added', 'labels' => ['interesado'] }] },
    { key: 'appointment', triggers: [{ 'type' => 'appointment_scheduled' }] },
    { key: 'converted', kind: :converted, triggers: [{ 'type' => 'case_created', 'case_class' => 'commercial' }] },
    { key: 'discarded', kind: :discarded, triggers: [{ 'type' => 'conversation_resolved' }] }
  ].freeze

  def initialize(board)
    @board = board
  end

  def apply!
    return if @board.kanban_processes.exists?

    KanbanProcess.transaction do
      COLUMNS.each_with_index do |column, index|
        @board.kanban_processes.create!(
          account_id: @board.account_id, position: index, default: column[:default] || false,
          type_process_name: text("columns.#{column[:key]}.name"), ai_criteria: text("columns.#{column[:key]}.ai"),
          entry_triggers: column[:triggers], stage_kind: column[:kind] || :open
        )
      end
      @board.update!(auto_move: true)
    end
    ensure_labels
  end

  private

  # La etiqueta que mueve a «Interesado» queda creada en la cuenta, lista para usarse.
  def ensure_labels
    COLUMNS.flat_map { |c| c[:triggers] }.flat_map { |t| Array(t['labels']) }.uniq.each do |title|
      @board.account.labels.find_or_create_by!(title: title) { |label| label.color = '#16a34a' }
    end
  rescue StandardError => e
    Rails.logger.error("[KanbanFunnel] etiquetas de la plantilla: #{e.message}")
  end

  def text(key)
    locale = @board.account.locale.presence || I18n.default_locale
    I18n.with_locale(locale) { I18n.t("kanban_funnel.template.#{key}") }
  end
end
