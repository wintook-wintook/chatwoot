# Cambia el estado de un mensaje saliente cuidando que la transición tenga sentido.
#
# Existe porque los acuses de los canales llegan por su cuenta y sin orden garantizado: un
# "entregado" puede llegar después de un "leído" y no debe hacerle retroceder.
# `external_error` se limpia salvo que el estado sea `failed`, para que un reintento que
# sale bien no deje el error viejo colgando.
class Messages::StatusUpdateService
  attr_reader :message, :status, :external_error

  def initialize(message, status, external_error = nil)
    @message = message
    @status = status.to_s
    @external_error = external_error
  end

  def perform
    return false unless valid_status_transition?

    message.update!(
      status: status,
      external_error: (status == 'failed' ? external_error : nil)
    )
  end

  private

  def valid_status_transition?
    return false unless Message.statuses.key?(status)
    # Único retroceso que se veta: el acuse de entrega que llega tarde.
    return false if message.read? && status == 'delivered'

    true
  end
end
