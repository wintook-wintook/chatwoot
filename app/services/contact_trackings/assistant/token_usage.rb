# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE GASTA UN TURNO DEL CHAT (P6c)
# ================================================================================
# Un turno del Asistente no es una llamada: la entrevista vuelve al modelo en cada
# corrección (gramática, ruteo, edición) y `last_usage` de OpenaiChat solo guarda la
# última. Esto suma TODAS las del turno, para medir antes de decidir topes y modelos
# (diagnóstico, P8 paso 0, D10).
#
# Se guarda pegado al mensaje del Asistente en la sesión (ver InterviewTurn), como los
# cambios: al modelo no le llega.
#
# EL COSTO, solo donde el precio es conocido (dólares por millón de tokens). Un modelo
# sin precio deja `costo_usd` en nil y los tokens guardados: se calcula después, cuando
# se cargue el precio oficial. Nunca se inventa un precio.
#
# Lo que NO cuenta: las clasificaciones de la prueba de ruteo usan el clasificador del
# motor, con su propia llamada HTTP. Se cuenta CUÁNTAS hubo, no sus tokens.
# ================================================================================

class ContactTrackings::Assistant::TokenUsage
  PRICES_PER_MILLION = {
    'gpt-4o' => { input: 2.5, cached: 1.25, output: 10.0 },
    'gpt-4o-mini' => { input: 0.15, cached: 0.075, output: 0.6 }
  }.freeze

  def initialize
    @models = []
    @calls = 0
    @failed = 0
    @tokens = Hash.new(0)
    @cost = 0.0
    @priced = true
    @seconds = 0.0
    @classifications = 0
  end

  # usage: el hash `usage` de OpenAI, o nil si la llamada falló.
  def add(model, usage, seconds)
    @models |= [model]
    @calls += 1
    @seconds += seconds
    return @failed += 1 if usage.blank?

    tokens = tokens_of(usage)
    tokens.each { |k, v| @tokens[k] += v }
    add_cost(model, tokens)
  end

  def add_classifications(count)
    @classifications += count.to_i
  end

  def to_h
    {
      'modelos' => @models, 'llamadas' => @calls, 'fallidas' => @failed,
      'entrada' => @tokens[:input], 'cacheados' => @tokens[:cached],
      'salida' => @tokens[:output], 'razonamiento' => @tokens[:reasoning],
      'segundos' => @seconds.round(1), 'clasificaciones' => @classifications,
      'costo_usd' => @priced && @calls.positive? ? @cost.round(6) : nil
    }
  end

  private

  # Los cacheados vienen DENTRO de prompt_tokens; el razonamiento, dentro de
  # completion_tokens. Se guardan aparte para ver cuánto ahorra la caché (P6b) y
  # cuánto piensa gpt-5.
  def tokens_of(usage)
    {
      input: usage['prompt_tokens'].to_i,
      cached: usage.dig('prompt_tokens_details', 'cached_tokens').to_i,
      output: usage['completion_tokens'].to_i,
      reasoning: usage.dig('completion_tokens_details', 'reasoning_tokens').to_i
    }
  end

  def add_cost(model, tokens)
    precio = PRICES_PER_MILLION[model]
    return @priced = false if precio.nil?

    sin_cache = tokens[:input] - tokens[:cached]
    @cost += ((sin_cache * precio[:input]) + (tokens[:cached] * precio[:cached]) + (tokens[:output] * precio[:output])) / 1_000_000.0
  end
end
