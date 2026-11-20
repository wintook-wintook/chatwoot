# frozen_string_literal: true

# Motor 2.0 — las etiquetas con las que la IA catalogó la plática («Atención a clientes»:
# Motor2::Skills::SupportFlow#labels) van a la conversación, para que el equipo vea qué pidió el cliente y
# qué se hizo (soporte-falla, respondida, canalizada…). Si la etiqueta no existe en la cuenta, se crea.
# No borra las que ya tenía: se van sumando.
#
#   Motor2::Labels.apply(conversation, %w[soporte-duda respondida])
module Motor2::Labels
  COLORS = { 'soporte' => '#2563eb', 'respondida' => '#16a34a', 'resuelto' => '#16a34a', 'sin-respuesta' => '#dc2626',
             'info-relacionada' => '#d97706', 'humano' => '#9333ea' }.freeze
  DEFAULT_COLOR = '#64748b'
  DESCRIPTION = 'La pone el agente de IA de Atención a clientes'

  module_function

  def apply(conversation, labels)
    list = Array(labels).compact_blank.uniq
    return if conversation.nil? || list.empty?

    list.each { |title| ensure_label(conversation.account, title) }
    conversation.update!(label_list: (conversation.label_list + list).uniq)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::Labels] conversación #{conversation&.id}: #{e.class}: #{e.message}")
  end

  def ensure_label(account, title)
    account.labels.find_or_create_by!(title: title) do |label|
      label.color = COLORS[title] || COLORS[title.split('-').first] || DEFAULT_COLOR
      label.description = DESCRIPTION
      label.show_on_sidebar = true
    end
  end
end
