# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONTRADICCIONES DEL ENCARGO (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Un paso aparte, al final: la lista numerada de reglas, prohibiciones y tono de la
# ficha, y una sola pregunta al modelo: ¿qué pares se contradicen?
#
# POR QUÉ APARTE: el lector también anota contradicciones, pero mientras hace todo lo
# demás. Medido el 23/09 con el encargo del gimnasio: "preguntar si es estudiante antes
# de dar el precio" y "dar el precio sin hacer preguntas antes" quedaron una debajo de
# la otra; en una lectura las marcó y en la siguiente no.
#
# EL MODELO SOLO DA NÚMEROS: contesta pares de índices, y el texto de cada lado lo pone
# el código desde la ficha. Así una contradicción siempre cita reglas que existen.
# ================================================================================

class ContactTrackings::Assistant::BriefContradictions
  FIELDS = %w[reglas prohibiciones tono].freeze
  # Más puntos que esto no es una lista que se lea de una vez (ADAM sin apretar trae
  # más de mil): se saltea y queda lo que haya anotado el lector.
  MAX_POINTS = 200

  PROMPT = <<~PROMPT
    Te paso las reglas de un agente de IA de atención por chat, numeradas. Decime qué
    pares se CONTRADICEN: no se pueden cumplir las dos a la vez en la misma situación
    (una pide hacer algo y otra prohíbe eso mismo; dos límites distintos para lo mismo;
    un orden de pasos y el contrario).

    No es contradicción: una regla general y una excepción explícita ("salvo que…"),
    ni dos reglas que hablan de cosas distintas.

    Contestá SOLO este JSON:
    {"contradicciones": [{"sobre": "de qué se trata, en pocas palabras", "a": 3, "b": 7}]}
    Sin contradicciones: {"contradicciones": []}
  PROMPT

  def initialize(account, ficha:)
    @account = account
    @ficha = ficha
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account)
  end

  # La ficha con las contradicciones encontradas agregadas (sin repetir las que ya
  # tenía) y los tokens usados.
  def call
    puntos = numbered
    return { ficha: @ficha, usage: {} } if puntos.size < 2 || puntos.size > MAX_POINTS

    raw = @chat.call(messages(puntos))
    nuevas = raw ? pairs(raw, puntos) : []
    { ficha: @ficha.merge('contradicciones' => merged(nuevas)), usage: @chat.last_usage.to_h }
  end

  private

  def numbered
    FIELDS.flat_map { |campo| Array(@ficha[campo]) }.select { |p| p['texto'].present? }
  end

  def messages(puntos)
    lista = puntos.each_with_index.map { |p, i| "#{i + 1}. #{p['texto']}" }.join("\n")
    [{ role: 'system', content: PROMPT }, { role: 'user', content: lista }]
  end

  def pairs(raw, puntos)
    Array(raw['contradicciones']).filter_map do |par|
      a = point_at(puntos, par['a'])
      b = point_at(puntos, par['b'])
      next if a.nil? || b.nil? || a.equal?(b)

      { 'sobre' => par['sobre'].to_s.squish.truncate(120), 'a' => a['texto'], 'b' => b['texto'],
        'origen' => (Array(a['origen']) + Array(b['origen'])).uniq.sort }
    end
  end

  def point_at(puntos, numero)
    indice = Integer(numero, exception: false)
    indice&.positive? ? puntos[indice - 1] : nil
  end

  # Las del lector más las nuevas, sin el mismo par dos veces (en cualquier orden).
  def merged(nuevas)
    vistas = Set.new
    (Array(@ficha['contradicciones']) + nuevas).select do |c|
      clave = [c['a'], c['b']].map { |t| t.to_s.squish.downcase }.sort
      vistas.add?(clave)
    end
  end
end
