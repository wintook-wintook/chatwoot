# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — TESTS SUGERIDOS (fase E de PROMPT STUDIO, §32)
# ================================================================================
# Una batería de mensajes de cliente, cada uno con la rama a la que DEBERÍA ir, pasada
# por el clasificador real. Lo que no se puede decidir sin conocer el negocio —un tema
# ajeno, un saludo, dos temas juntos— va sin veredicto: se muestra a dónde cayó y lo
# juzga la persona.
#
# QUIÉN ESCRIBE LOS MENSAJES:
#   Primero se sacaban de la descripción de cada rama (ProbePhrases). Sirve cuando la
#   descripción está en palabras del cliente, pero el v6.11 las escribe como criterios
#   ("quiere SABER un dato de la empresa…"), y de ahí salían pruebas que ningún cliente
#   manda. Ahora los escribe el modelo, que lee cualquiera de los dos estilos. El
#   VEREDICTO sigue siendo del clasificador real: la IA solo pone las entradas.
#   Si esa llamada falla, se vuelve a las frases de la descripción.
#
# CORREN EN SERIE (ver DraftClassifier) y avisan el avance: probar un agente de cinco
# ramas son ~13 clasificaciones de 2–3 s cada una.
# ================================================================================

class ContactTrackings::Assistant::SuggestedTests
  MAX_ROUTES = 8
  PER_ROUTE = 2
  MAX_EDGE_CASES = 4
  MAX_MESSAGE_CHARS = 200

  Case = Struct.new(:message, :expected, :chosen, :source, :tag, :kind, :note, keyword_init: true) do
    # true / false con veredicto; nil en los casos límite, que juzga la persona.
    def pass
      kind == :route ? chosen == expected : nil
    end

    def to_h = super.merge(pass: pass)
  end

  def initialize(account, draft:, inbox: nil, progress: nil)
    @account = account
    @classifier = ContactTrackings::Assistant::DraftClassifier.new(account, draft: draft, inbox: inbox)
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
    @progress = progress
  end

  def call
    rutas = @classifier.map.routes.first(MAX_ROUTES)
    return { cases: [], generated_by: nil } if rutas.empty?

    casos, origen = planned_cases(rutas)
    casos.each_with_index do |caso, i|
      @progress&.call(:testing, done: i, total: casos.size)
      classify(caso)
    end

    { cases: casos.map(&:to_h), generated_by: origen }
  end

  private

  def classify(caso)
    elegida = @classifier.classify(caso.message)
    caso.chosen = elegida&.name
    caso.source = elegida&.directive
    caso.tag = elegida&.hashtag
  end

  def planned_cases(rutas)
    generados = generated(rutas)
    return [generados, :assistant] if generados.present?

    [from_descriptions(rutas), :descriptions]
  end

  # ── los mensajes del modelo ─────────────────────────────────────────────────
  def generated(rutas)
    return nil if @chat.api_key.blank?

    reply = @chat.call([{ role: 'system', content: prompt(rutas) }])
    return nil unless reply.is_a?(Hash)

    nombres = rutas.map(&:name)
    route_cases(reply, nombres) + edge_cases(reply, nombres)
  end

  def route_cases(reply, nombres)
    Array(reply['ramas']).flat_map do |item|
      next [] unless item.is_a?(Hash) && nombres.include?(item['rama'].to_s)

      Array(item['mensajes']).first(PER_ROUTE).filter_map do |mensaje|
        texto = clean(mensaje)
        Case.new(message: texto, expected: item['rama'].to_s, kind: :route) if texto
      end
    end
  end

  # Un caso límite puede traer la rama que el modelo cree correcta; se muestra como
  # su opinión, no como veredicto.
  def edge_cases(reply, nombres)
    Array(reply['limites']).first(MAX_EDGE_CASES).filter_map do |item|
      next unless item.is_a?(Hash) && (texto = clean(item['mensaje']))

      esperada = item['rama'].to_s.presence
      Case.new(message: texto, expected: (esperada if nombres.include?(esperada)), kind: :edge,
               note: item['por_que'].to_s.squish.truncate(160).presence)
    end
  end

  def clean(value)
    value.to_s.squish.truncate(MAX_MESSAGE_CHARS).presence
  end

  def prompt(rutas)
    catalogo = rutas.map { |r| "- #{r.name}: #{r.description}" }.join("\n")
    <<~PROMPT
      Vas a escribir mensajes de prueba para un clasificador de atención al cliente. Estas son sus rutas
      y la descripción que el clasificador usa para decidir:

      #{catalogo}

      1. Por cada ruta, #{PER_ROUTE} mensajes como los escribiría un cliente real por chat: cortos, en
         primera persona, con sus palabras. NO copies la descripción ni uses sus términos técnicos: la
         prueba tiene que ser un mensaje que alguien manda de verdad.
      2. Hasta #{MAX_EDGE_CASES} casos límite que pongan a prueba el corte entre rutas: un tema ajeno a la
         empresa, un saludo sin pedido, un mensaje con dos temas, algo que podría ir a dos rutas. Para cada
         uno, la ruta que te parece correcta (o null) y en una frase por qué.

      Escribe en #{ContactTrackings::Assistant::Language.name_for}.
      Responde SOLO un JSON:
      {"ramas": [{"rama": "<nombre exacto>", "mensajes": ["...", "..."]}],
       "limites": [{"mensaje": "...", "rama": "<nombre exacto o null>", "por_que": "..."}]}
    PROMPT
  end

  # ── sin modelo: las situaciones de cada descripción ─────────────────────────
  def from_descriptions(rutas)
    rutas.flat_map do |ruta|
      ContactTrackings::Assistant::ProbePhrases.for(ruta, limit: PER_ROUTE)
                                               .map { |frase| Case.new(message: frase, expected: ruta.name, kind: :route) }
    end
  end
end
