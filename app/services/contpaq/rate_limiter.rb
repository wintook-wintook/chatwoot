# frozen_string_literal: true

# @kbase_contpaq — Cuota de llamadas al Agente de Servicio CONTPAQi.
#
# El limite es de 60 llamadas por minuto POR INTEGRADOR: el contador lo lleva el servicio
# sobre las credenciales, no sobre la IP ni el proceso. Por eso vive en Redis y no en
# memoria — con varios workers, cada uno creeria tener los 60 para el solo y entre todos
# se pasarian, cobrando 429 que ademas no conviene reintentar en caliente.
#
# Ventana por minuto de reloj, no deslizante: es la forma que cuesta una sola clave y se
# alinea con como lo cuenta el servicio. En el peor caso (rafaga a caballo de dos minutos)
# admite algo mas de 60 en 60 segundos corridos; el margen por defecto lo cubre.
class Contpaq::RateLimiter
  LIMIT = 60

  # Se reserva un poco de cuota: el contador local puede desfasarse del que lleva
  # CONTPAQi (un reintento que alla si conto y aca no, por ejemplo).
  DEFAULT_LIMIT = 55

  # El bucket vive algo mas que su minuto para tolerar relojes desfasados entre procesos.
  BUCKET_TTL = 90

  def initialize(source, limit: DEFAULT_LIMIT)
    @source = source
    @limit  = limit
  end

  # Reserva un lugar en el minuto en curso. true = se puede llamar.
  #
  # Se crea la clave con SET NX (que ademas le pone vencimiento) y recien despues se
  # incrementa: si se incrementara primero, entre el INCR y el vencimiento habria una
  # ventana en la que un reinicio dejaria el contador sin TTL y el limite bloqueado
  # para siempre.
  def allow?
    key = bucket_key
    Redis::Alfred.set(key, 0, nx: true, ex: BUCKET_TTL)
    used = Redis::Alfred.incr(key).to_i

    return true if used <= @limit

    Rails.logger.warn "[CONTPAQi] 🚦 Cuota agotada: #{used}/#{@limit} llamadas en el minuto"
    false
  rescue StandardError => e
    # Si Redis no responde, no se bloquea la conversacion: se deja pasar y que el
    # servicio conteste 429 si corresponde. Un limitador caido no debe apagar la fuente.
    Rails.logger.error "[CONTPAQi] ⚠️ Limitador no disponible (#{e.message}) → se deja pasar"
    true
  end

  private

  def bucket_key
    format(Redis::RedisKeys::CONTPAQ_RATE_BUCKET,
           source_id: @source.id, minute: Time.now.utc.strftime('%Y%m%d%H%M'))
  end
end
