# Suscribe la app a los eventos del webhook de una cuenta de Instagram.
#
# Va en un job y no en la petición del callback de OAuth por dos motivos: no hacer esperar
# al administrador a una ida y vuelta contra Meta en mitad del alta, y poder reintentar si
# Meta contesta mal en ese momento. Un canal sin suscripción queda mudo (token válido,
# cero entregas), así que merece más de un intento antes de darse por vencido.
class Channels::Instagram::SubscribeJob < ApplicationJob
  class SubscriptionError < StandardError; end

  queue_as :low

  # El canal pudo borrarse entre el encolado y la ejecución.
  discard_on ActiveJob::DeserializationError
  retry_on SubscriptionError, wait: 30.seconds, attempts: 3

  def perform(channel)
    return if channel.blank?
    # `subscribe` deja el motivo en provider_config y lo enseña `rake instagram:doctor`.
    return if channel.subscribe

    raise SubscriptionError, "channel #{channel.id}: #{channel.webhook_subscription_error}"
  end
end
