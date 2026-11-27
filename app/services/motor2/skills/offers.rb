# frozen_string_literal: true

# «Ofertas escalonadas» — becas, descuentos, plazos o convenios que se dan uno a la vez cuando
# el cliente objeta el precio (plan §11.6, caso de becas de Casauranc). El modelo no ve los
# escalones: pide el siguiente y el código le da solo ese y avanza. Lo que no tiene a la vista
# no lo puede adelantar ni juntar (lecciones 2f82732f / d389a288: ofertas fuera de orden y dos
# becas en el mismo mensaje).
#
#   skills.offers = { 'on' => true, 'objection' => 'está caro, no me alcanza, ¿no hay descuento?',
#                     'steps' => [{ 'text' => 'Beca de 20%: queda en $3,360', 'file' => 'beca20' }, …] }
# 'file' es el nombre de un archivo del agente (se manda con la oferta).
class Motor2::Skills::Offers < Motor2::Skills::Base
  def self.key = 'offers'

  def on? = super && steps.any?

  def tools
    [fn('siguiente_oferta', 'El cliente objetó el precio: te da la SIGUIENTE oferta (solo esa). Dásela con tus palabras.',
        { objecion: { type: 'string', description: 'Lo que dijo el cliente' } }, %w[objecion])]
  end

  def instructions
    <<~TEXT.strip
      - OFERTAS: cuando el cliente objete el precio (#{objection}), usa siguiente_oferta y da SOLO la oferta que te regrese.
        Nunca menciones otras ofertas, descuentos o becas, ni digas que hay más. Una oferta por mensaje.
    TEXT
  end

  def memory
    step = state['offer_step'].to_i
    return '' if step.zero?

    "OFERTA QUE YA LE DISTE (#{step} de #{steps.size}): #{steps[step - 1]['text']}. Si la vuelve a preguntar, repítela."
  end

  def call(_name, _args)
    return { error: 'Ya diste una oferta en este mensaje. Escribe tu respuesta con esa.' } if @given

    step = state['offer_step'].to_i
    return last_offer(step) if step >= steps.size

    give(step)
  end

  private

  def steps
    @steps ||= Array(setting(:steps)).filter_map do |s|
      s = s.to_h.stringify_keys
      s.merge('text' => s['text'].to_s.strip.first(800)) if s['text'].present?
    end
  end

  def give(step)
    offer = steps[step]
    state['offer_step'] = step + 1
    @given = true
    @turn.seen << offer['text']
    @turn.attach(offer['file']) if offer['file'].present?
    trace.event(:oferta, "escalón #{step + 1} de #{steps.size}")
    { escalon: step + 1, de: steps.size, oferta: offer['text'] }
  end

  def objection = setting(:objection).to_s.strip.presence || 'dice que está caro o pide descuento'

  def last_offer(step)
    trace.event(:oferta, 'ya no hay más')
    { fin: true, ultima: steps[step - 1]&.dig('text'),
      nota: 'Ya no hay más ofertas. No inventes otra: si sigue sin poder, ofrécele pasarlo con una persona.' }
  end
end
