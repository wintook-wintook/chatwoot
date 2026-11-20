# frozen_string_literal: true

# Motor 2.0 — «Atención a clientes» › Soporte: ¿lo que regresó buscar_en_fuentes resuelve lo que pidió
# el cliente? (del prompt del Coordinador Kontrolya v5.6: tipos de resultado del foro). Revisión corta y
# aparte (AiModels::REVIEW, temperatura 0), antes de que el agente conteste:
#   exacta       mismo sistema, módulo y proceso, y trae cómo resolverlo → se le dan los pasos tal cual
#                (el código no lo deja pasarlo ni levantar el caso: Motor2::Skills::SupportFlow)
#   relacionada  algo parecido pero de otro sistema, módulo o escenario → se dice así, sin adaptarlo
#   aclarar      falta un dato para saber cuál aplica (CONTPAQi: «¿en qué sistema?»; o varias soluciones para
#                situaciones distintas) → se le hace esa pregunta
#   ninguna      nada sirve → «no encontré documentación específica» y se escala
#
#   Motor2::ResultCheck.new(account: a).call(question:, found:, intent:, system:, asked:, pending:)
#   → { 'tipo' => 'exacta', 'usar' => [0], 'motivo' => '', 'pregunta' => '' }
# Si OpenAI falla: nil (el agente contesta como antes, con sus reglas).
class Motor2::ResultCheck < Cases::Ai::BaseService
  TYPES = %w[exacta relacionada aclarar ninguna].freeze
  MAX_RESULTS = 8
  RESULT_CHARS = 1500
  ASK = '¿Qué te aparece o qué pasa exactamente cuando lo intentas?'
  ASK_WHICH = '¿En cuál sistema o producto lo quieres hacer?'

  SYSTEM = <<~TEXT
    Revisas lo que encontró la búsqueda de un agente de soporte, antes de que conteste. Decide si los RESULTADOS
    resuelven lo que pide el CLIENTE:
    - exacta: algún resultado es del mismo equipo, producto o sistema y del mismo proceso que pide (o el cliente no
      dijo cuál y el resultado es del SISTEMA POR OMISIÓN) y trae cómo resolverlo o contestarlo.
    - relacionada: hay algo parecido pero es de otro equipo, modelo, producto, sistema u otro escenario, o solo
      resuelve una parte. No la cuentes como exacta.
    - aclarar: falta un dato del cliente para saber cuál aplica: la fuente misma lo pide («¿en cuál sistema estás
      trabajando?», «¿qué modelo es?»), lo que dijo es muy general («tengo un problema») o hay soluciones para situaciones distintas y no
      dijo cuál es la suya («no puedo enviar el pedido»: ¿no se habilita el botón o le sale un mensaje?). Entonces en
      «pregunta» escribe UNA pregunta corta para el cliente que distinga esas situaciones, con sus palabras.
      Nunca pidas algo que el cliente ya dijo: si lo que falta ya lo dijo, no es aclarar. Si lo que dijo es muy
      general (no dice qué le pasa), es aclarar aunque ningún resultado sirva. Si hay PREGUNTA ANTERIOR y su
      respuesta no la contesta (no dice lo que se le preguntó), sigue siendo aclarar: pregúntalo de otra forma.
    - ninguna: no hay nada que sirva.
    Solo es exacta si un resultado describe SU situación; si hay varias posibles y no dijo cuál, es aclarar.
    En «depende» di si la respuesta cambia según el sistema, producto o equipo (cómo dar de alta un cliente sí depende;
    el horario de la oficina no). En «dijo_cual» di si el cliente ya dijo de cuál sistema, producto o equipo habla y, si lo
    dijo, en «coincide» si los resultados de «usar» son de ESE mismo (Kontrolya CRM no es Comercial Premium).
    Primero, en «distingue», di si el cliente mencionó un detalle que solo aparece en UNO de los resultados (el
    mensaje que le sale, el botón que no se habilita, un número de error): true o false. Decir solo lo que no puede
    hacer o el sistema («no puedo enviar el pedido a Microsip») no distingue: false.
    En «usar» pon los números de los resultados que sirven (los de exacta, relacionada o aclarar), máximo 3.
    En «pregunta», si es aclarar, la pregunta para el cliente. En «motivo», en pocas palabras, por qué.
    Responde solo JSON: {"distingue": false, "depende": false, "dijo_cual": false, "coincide": true, "tipo": "exacta", "usar": [0], "pregunta": "",
    "motivo": ""}
  TEXT

  # context: intent, system (el que asume si no dice), asked (la pregunta anterior), pending (fuentes que faltan).
  def call(question:, found:, **context)
    @context = context
    list = numbered(found)
    return { 'tipo' => 'ninguna', 'usar' => [], 'motivo' => 'sin resultados' } if list.empty?

    result = chat(system: SYSTEM, user: user_text(question, list), json: true, temperature: 0, max_tokens: 240)
    clean(result, list.size)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::ResultCheck] #{e.class}: #{e.message}")
    nil
  end

  # Los resultados en una sola lista (con su fuente), en el orden en que se numeran.
  def self.flat(found)
    Array(found).flat_map { |f| Array(f[:resultados]).map { |r| r.merge(fuente: f[:fuente]) } }.first(MAX_RESULTS)
  end

  private

  def model = AiModels::REVIEW

  def numbered(found) = self.class.flat(found)

  def user_text(question, list)
    lines = ["CLIENTE: #{question.to_s.first(600)}", *context_lines, 'RESULTADOS:']
    list.each_with_index do |r, i|
      text = [r[:titulo] || r[:codigo], r[:informacion] || r[:instrucciones_internas]].compact.join(': ')
      lines << "[#{i}] (#{r[:fuente]}) #{text.to_s.first(RESULT_CHARS)}"
    end
    lines.join("\n")
  end

  def default_ask(result) = result['depende'] == true && result['dijo_cual'] != true ? ASK_WHICH : ASK

  def context_lines
    { 'LO QUE BUSCA' => @context[:intent], 'SISTEMA POR OMISIÓN (si no dice otro)' => @context[:system],
      'PREGUNTA ANTERIOR (se la hizo el agente)' => @context[:asked],
      'FUENTES QUE FALTAN (aún no consultadas)' => Array(@context[:pending]).join(' | ') }.filter_map { |k, v| "#{k}: #{v}" if v.present? }
  end

  def clean(result, size)
    return nil unless result.is_a?(Hash)

    used = Array(result['usar']).map(&:to_i).select { |i| i.between?(0, size - 1) }.uniq.first(3)
    type = verdict(result, used)
    { 'tipo' => type, 'usar' => type == 'ninguna' ? [] : used, 'motivo' => result['motivo'].to_s.first(200),
      'pregunta' => type == 'aclarar' ? result['pregunta'].to_s.first(300).presence || default_ask(result) : '' }
  end

  # Varias soluciones para situaciones distintas y no dijo cuál es la suya: primero se le pregunta. Si depende del
  # sistema o producto, no dijo cuál y faltan fuentes de otros: todavía no es exacta (la cascada sigue).
  def verdict(result, used)
    type = result['tipo'].to_s.downcase.presence_in(TYPES) || 'ninguna'
    return type unless type == 'exacta'
    return 'aclarar' if used.size > 1 && result['distingue'] != true

    unknown_system?(result) ? system_verdict(result) : type
  end

  # No se sabe de cuál habla: con varias fuentes, se le pregunta; si no, sigue buscando (relacionada).
  def system_verdict(result) = many_sources? && result['dijo_cual'] != true ? 'aclarar' : 'relacionada'

  # Resultados de varias fuentes (p. ej. las predefinidas de Kontrolya y CONTPAQi): hay que saber de cuál habla.
  def many_sources? = @context[:many_sources] == true

  # Depende del sistema y no dijo cuál (y faltan fuentes de otros), o dijo uno y lo encontrado es de otro.
  def unknown_system?(result)
    return false unless result['depende'] == true
    return result['coincide'] == false if result['dijo_cual'] == true

    Array(@context[:pending]).any? || many_sources?
  end
end
