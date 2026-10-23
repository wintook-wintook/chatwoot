# frozen_string_literal: true

# Embudo de contactos E2 — soltar una tarjeta en una columna «Convertido» con tipo
# configurado crea la oportunidad (o reusa la abierta de esa clase), igual que la
# automatización «Asignar Caso». El caso queda ligado a la conversación.
class Kanban::FunnelConverter
  def initialize(conversation, column)
    @conversation = conversation
    @column = column
  end

  def call
    type = @column.convert_case_type
    return nil if type.nil? || type.retired?
    return nil if open_case_of_class?(type.case_class)

    ActionService.new(@conversation).assign_case_type([type.id])
  end

  private

  def open_case_of_class?(case_class)
    @conversation.case_tickets.where.not(status: CaseTicket::CLOSED_STATUSES).includes(:case_type)
                 .any? { |ticket| (ticket.case_type&.case_class || 'support') == case_class }
  end
end
