# frozen_string_literal: true

# ================================================================================
# proyecto@importar_prompt_md — F1: LA REVISIÓN DE LA IA SOBRE EL REPARTO
# ================================================================================
# Plan: docs/importar_prompt_md_plan.md (§4.2). El Distributor reparte con reglas fijas
# por título; esto le pide a la IA (gpt-4o, OpenaiChat) que revise TODAS las unidades en
# una sola llamada, con título, descripción y tres reglas de muestra de cada una.
#
# ⚠ A LA IA NO SE LE PREGUNTA "¿QUÉ DESTINO?": medido con ADAM, mostrándole el destino de
#   las reglas fijas lo confirmó en 80 de 81 unidades, incluidas las que eran trabajo del
#   consultor. Ahora responde dos preguntas concretas por unidad —QUIÉN la ejecuta
#   (el agente en el chat, una persona fuera del chat, el sistema por dentro, una llamada
#   de voz, un envío automático) y CUÁNDO aplica (siempre, en un tema, es información, es
#   un guion)— sin ver la sugerencia, y el destino lo deriva el código.
#
# QUIÉN MANDA (también medido con ADAM): dejándole todo a la IA convirtió cada servicio
# en una ruta (13) y etapas del propio agente ("Origen del lead") en temas. Así que:
#   · lo que las reglas fijas reconocieron se queda — la IA solo puede sacarlo (out);
#   · lo que las reglas fijas no reconocieron (source :default) lo decide la IA.
# ================================================================================
class ContactTrackings::PromptImport::AiReview
  WHO_OUT = %w[persona sistema voz automatico].freeze
  KIND_DESTINATION = { 'siempre' => 'section', 'tema' => 'route', 'informacion' => 'knowledge',
                       'guion' => 'script' }.freeze

  # Los nombres de sección de las reglas fijas: la IA los reutiliza para que no salgan 30.
  SECTION_NAMES = ContactTrackings::PromptImport::Distributor::FIXED
                  .filter_map { |_, destination, hint| hint if destination == 'section' }.uniq.freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    Estás revisando las secciones de un documento de comportamiento para configurar un
    agente de IA que atiende por chat (WhatsApp, Instagram, web) a clientes y prospectos.
    Cada unidad es una sección del documento: te doy su título, su descripción y algunas
    de sus reglas. Para CADA unidad responde dos preguntas.

    1. "quien": ¿quién ejecuta lo que describe la sección?
       - "agente": el agente de IA, dentro de la conversación por chat con el cliente.
       - "persona": un consultor, asesor o directivo humano fuera del chat (por ejemplo un
         diagnóstico completo que se entrega en una sesión, documentos o propuestas formales,
         reuniones presenciales). OJO: si la sección le dice al AGENTE cuándo pasarle el caso
         a una persona, es "agente": escalar es algo que hace el agente.
       - "sistema": gestión interna del propio sistema, no la conversación (versionar o
         clasificar prompts, registrar aprendizajes en una base de conocimiento, auditorías).
       - "voz": comunicación hablada o llamadas telefónicas.
       - "automatico": mensajes que el sistema envía solo después, sin que el cliente escriba
         (secuencias de seguimiento o recordatorios).
       Si es una mezcla, elige lo que describe la MAYORÍA de sus reglas.

    2. Si quien es "agente", "cuando": ¿cuándo aplica?
       - "siempre": en todos los mensajes, o es una etapa del propio proceso del agente
         (identidad, ética, tono, forma de conversar, método, apertura, diagnóstico, cómo
         clasifica al cliente). Agrega "seccion": REUTILIZA uno de estos nombres si encaja:
         #{SECTION_NAMES.join(', ')}; si ninguno encaja, uno nuevo corto en mayúsculas.
       - "tema": solo cuando el CLIENTE trae un tema concreto con lo que escribe (pregunta
         precios, pone una objeción, pide agendar, pide hablar con una persona). Las etapas
         que el agente recorre por su cuenta NO son tema. Agrega "tema": en minúsculas y sin
         tildes.
       - "informacion": datos que el agente consulta cuando hace falta (servicios, productos,
         glosario, ejemplos).
       - "guion": un caso concreto que el cliente abre (por ejemplo "quiero una página web")
         y que el agente lleva paso a paso durante varios mensajes.

    Responde SOLO JSON, con todas las unidades:
    {"units":[{"key":"u1","quien":"agente","cuando":"siempre","seccion":"ROL","motivo":"una frase en español"}]}
  PROMPT

  def initialize(units, account:)
    @units = units
    @account = account
  end

  # { status: :ok, changed: N } | { status: :no_api_key } | { status: :failed }
  def call
    chat = ContactTrackings::Assistant::OpenaiChat.new(account: @account)
    return { status: :no_api_key } if chat.api_key.blank?

    answer = chat.call(messages)
    return { status: :failed } unless answer.is_a?(Hash)

    { status: :ok, changed: apply(Array(answer['units'])) }
  end

  private

  def messages
    [{ role: 'system', content: INSTRUCTIONS },
     { role: 'user', content: { unidades: @units.map { |u| ai_unit(u) } }.to_json }]
  end

  # Sin destino_sugerido: ver el ⚠ del encabezado.
  def ai_unit(unit)
    { key: unit.key, capitulo: unit.chapter, titulo: unit.title, descripcion: unit.excerpt.truncate(240),
      reglas: unit.rule_ids.size, ejemplos: unit.samples }
  end

  # Solo se aceptan respuestas sobre unidades que existen y con valores conocidos: un JSON
  # a medias o inventado no puede mover nada.
  def apply(answers)
    index = @units.index_by(&:key)
    answers.count do |answer|
      unit = index[answer['key'].to_s]
      destination, hint = derive(answer)
      next false unless unit && destination
      next confirm(unit, answer) if unit.source == :fixed && destination != 'out'

      move(unit, destination, hint, answer)
    end
  end

  def move(unit, destination, hint, answer)
    changed = destination != unit.destination
    unit.hint = pick_hint(unit, destination, hint)
    unit.destination = destination
    unit.source = :ai if changed
    unit.reason = answer['motivo'].to_s.strip.presence || unit.reason
    changed
  end

  # La IA coincidió con la regla fija (o no puede cambiarla): solo aporta su motivo.
  def confirm(unit, answer)
    unit.reason = answer['motivo'].to_s.strip.presence || unit.reason
    false
  end

  # Quién la ejecuta manda: si no es el agente dentro del chat, va fuera, sea lo que sea.
  def derive(answer)
    return ['out', nil] if WHO_OUT.include?(answer['quien'].to_s)
    return nil unless answer['quien'].to_s == 'agente'

    destination = KIND_DESTINATION[answer['cuando'].to_s]
    destination && [destination, destination == 'route' ? answer['tema'] : answer['seccion']]
  end

  # En una ruta, el tema de las reglas fijas gana si coinciden en que es ruta: así los
  # nombres quedan parejos ("precios", no "precios" en una y "negociacion" en otra).
  def pick_hint(unit, destination, hint)
    return unit.hint if destination == unit.fixed && unit.hint.present? && destination == 'route'

    normalize_hint(destination, hint) || (unit.hint if destination == unit.fixed)
  end

  # El tema de una ruta termina siendo su nombre en @ruta(...): minúsculas, sin tildes.
  def normalize_hint(destination, hint)
    return nil if hint.blank?
    return I18n.transliterate(hint.to_s).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '') if destination == 'route'

    hint.to_s.strip.upcase.delete('[]')
  end
end
