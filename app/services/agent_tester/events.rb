# frozen_string_literal: true

# Probador de agentes — una plática de prueba NO es de un cliente. Los despachadores preguntan aquí
# (igual que con InternalChannel::Events) y sus eventos solo llegan al tiempo real
# (ActionCableListener): nada de embudo, automatizaciones, webhooks de la cuenta o de la instalación,
# integraciones (Slack…), reportes, avisos, casos ni CSAT. Antes, cada prueba entraba al embudo
# del cliente y salía por sus webhooks como una plática más.
#
# Los motores no pasan por aquí: los dispara Message#… al crearse el mensaje del cliente.
module AgentTester::Events
  SYNC_LISTENERS = %w[ActionCableListener].freeze
  ASYNC_LISTENERS = [].freeze

  module_function

  def tester?(data)
    record = data[:conversation] || data[:message]&.conversation || data[:contact]
    record.respond_to?(:additional_attributes) && marked?(record.additional_attributes)
  end

  def marked?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes.to_h[AgentTester::Sandbox::MARK]) == true
  end
end
